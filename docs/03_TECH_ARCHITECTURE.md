# CORBIE — Техническая архитектура v1

> ⚠️ **Читать вместе с `01b_SPEC_AMENDMENT_01_REVISION.md`** - пересмотр поправки №1 оставляет состав сущностей базовой спеки (`ChecklistList`, `ListItem`, `Plan`, `PlanExpense`), добавляет `PlanStep` и `BusyInterval`, удаляет `TaskFolder`, добавляет `TodayFeedProvider`, `FreeSlotEngine`, `BusyPublisher`, `RecapBuilder` и требование не публиковать в CloudKit ничего, кроме анонимных интервалов занятости.

## 1. Обзор

```
┌──────────────────────── iPhone A ────────────────────────┐   ┌──── iPhone B ────┐
│ SwiftUI App ──┐                                          │   │   (same stack)   │
│ Widgets ──────┼── App Group ── Core Data (SQLite) ───────┼───┤                  │
│ Share Ext ────┘         │                                │   │                  │
│                NSPersistentCloudKitContainer             │   │                  │
└─────────────────────────┼────────────────────────────────┘   └────────┬─────────┘
                          │  CloudKit (private DB, custom zone, CKShare)│
                          └──────────────── iCloud ──────────────────────┘
                                             ▲
   StoreKit 2 ── App Store ── Server Notifications V2 ──┐
                                                         ▼
                    ┌──────── Microservice (Supabase) ────────┐
                    │ Edge Functions: invite, link-parse,     │
                    │ fx-rates, entitlement, events           │
                    │ Postgres: invites, entitlements, events │
                    └─────────────────────────────────────────┘
```

**Принцип:** данные пары никогда не проходят через наш сервер. Сервер знает только коды приглашений, статус подписки по spaceId, анонимные события и курсы валют.

## 2. Стек

| Слой | Выбор | Версия/примечание |
|---|---|---|
| Язык | Swift | 5.10+, strict concurrency где возможно |
| UI | SwiftUI | iOS 17.0+ deployment target |
| Хранение | Core Data | SQLite store в App Group |
| Синк | CloudKit via `NSPersistentCloudKitContainer` | private + shared DB, `CKShare` |
| Виджеты | WidgetKit + App Intents | interactive widgets требуют iOS 17 |
| Покупки | StoreKit 2 | auto-renewable subscriptions |
| Карты | MapKit + `MKLocalSearch` | без ключей |
| Календарь iOS | EventKit | импорт/экспорт |
| Уведомления | UserNotifications + CloudKit subscriptions | без своего push-сервера |
| Локализация | String Catalogs (.xcstrings) | 5 языков |
| Сервер | Supabase (Postgres + Edge Functions, Deno/TS) | один проект, free → Pro $25 |
| CI | Xcode Cloud | бесплатные часы достаточны |
| Крэши | Xcode Organizer (Apple) | без сторонних SDK |

**Почему не SwiftData.** SwiftData + CloudKit не поддерживает шаринг записей между пользователями (CKShare). Для «одно пространство на двоих» нужен `NSPersistentCloudKitContainer` с `share(_:to:)` — только Core Data. Это самый важный технический подводный камень проекта.

**Почему не свой бэкенд для данных.** CloudKit бесплатен в квотах (по 1 PB общего хранилища на приложение, растёт с числом пользователей), даёт push при изменениях, шифрование и хранение в iCloud пользователя. Себестоимость данных — ноль.

## 3. Данные и синхронизация

### 3.1 Контейнер
- iCloud container: `iCloud.app.corbie`
- App Group: `group.app.corbie` (общий SQLite для app / widgets / share extension)
- Один `NSPersistentCloudKitContainer` с двумя store descriptions: **private** (`databaseScope = .private`) и **shared** (`databaseScope = .shared`). Обе указывают на один и тот же managed object model.

### 3.2 Зоны и шаринг
- Создатель пространства: все объекты Space живут в **его private DB** в кастомной зоне (контейнер создаёт `com.apple.coredata.cloudkit.zone`; шаринг переносит объекты в отдельную shared-зону).
- Приглашение: `container.share([spaceObject], to: nil)` → `CKShare` с `publicPermission = .none`, участник добавляется по URL. Все дочерние объекты (Task, Event…) связаны с Space relationship'ами → попадают в ту же share.
- Партнёр: принимает `CKShare.Metadata` через `container.acceptShareInvitations` → объекты появляются в его **shared DB**.
- Обе стороны пишут в один набор записей; CloudKit разруливает права по share.

### 3.3 Правила модели для CloudKit
- Все атрибуты optional или с default value (требование CloudKit).
- Без unique constraints. Без ordered relationships.
- Relationships двусторонние.
- UUID как `id` (indexed).
- Большие бинарники (фото хотелок) — `allowsExternalBinaryDataStorage = true`, лимит 1 МБ после ресайза. Файлы (v1.1) — отдельно через R2.

### 3.4 Конфликты
- Merge policy: `NSMergeByPropertyObjectTrumpMergePolicy` (последний писатель по полю).
- Для чеклистов и задач конфликтов мало: операции атомарны по объекту.
- `PlanExpense` — append-only, суммы считаются из расходов, не хранятся.
- `Vote.responses` — словарь по memberId, каждый пишет только свой ключ.

### 3.5 Офлайн
- Core Data — источник правды для UI. Синк — фоновый. Индикатор «syncing» только в настройках.
- Обработка `NSPersistentCloudKitContainer.eventChangedNotification` для статуса.

### 3.6 Local-first виджеты
- Виджеты читают тот же SQLite через App Group. После любого сохранения в app → `WidgetCenter.shared.reloadAllTimelines()`.
- Интерактивные виджеты выполняют `AppIntent`, который пишет в Core Data и вызывает reload.
- Тихий push CloudKit (`CKDatabaseSubscription`) → app в фоне подтягивает изменения → reload виджетов.

## 4. Pairing flow

```
A: tap "Invite" ──► POST /invite {shareURL, spaceId}  ──► {code:"K7M2QX", expiresAt}
A: system share sheet with code (and deep link corbie://join/K7M2QX)
B: enter code ──► GET /invite/K7M2QX ──► {shareURL} ──► CKContainer.accept(share metadata)
B: shared DB syncs Space ──► app detects Space with 2 members ──► trialEndsAt = max(trialEndsAt, now+7d)
Server: mark invite redeemed; delete after 15 min TTL regardless
```

- Код: 6 символов, алфавит без похожих (`ABCDEFGHJKMNPQRSTUVWXYZ23456789`).
- Один активный код на space; повторный запрос инвалидирует предыдущий.
- Deep link + Universal Link (`https://corbie.app/join/CODE`) — открывает приложение или App Store.

## 5. Микросервис (Supabase)

### Таблицы
- `invites(code pk, space_id, share_url, created_at, expires_at, redeemed_at)`
- `entitlements(space_id pk, original_transaction_id, product_id, status, expires_at, payer_hash, updated_at)`
- `events(id, anon_id, name, props jsonb, ts, app_version, locale)` — партиции по месяцу, retention 30 дней сырых
- `fx_rates(base, date, rates jsonb)` — кэш ЕЦБ

### Edge Functions
- `POST /invite` — создать код (auth: Apple identity token, проверяется через Apple JWKS)
- `GET /invite-redeem/:code` — получить shareURL, пометить redeemed
- `POST /parse` — {url} → {title, price, currency, imageURL, source}. OG + JSON-LD + адаптеры (amazon, target, etsy, sephora, nordstrom, zara, ikea) + oEmbed для instagram/tiktok. Таймаут 8 с, кэш 24 ч по URL.
- `GET /fx?base=USD` — курсы с кэшем 12 ч (источник: Frankfurter/ECB)
- `POST /appstore-notifications` — App Store Server Notifications V2: верифицируем JWS, обновляем `entitlements` по `appAccountToken` = spaceId
- `GET /entitlement/:spaceId` — статус для клиента
- `POST /events` — батч анонимных событий

### Безопасность
- RLS включён; Edge Functions работают через service role, клиент напрямую в таблицы не ходит.
- Apple identity token обязателен на `/invite` и `/entitlement`. `/parse`, `/fx` — с rate-limit по IP и app attest (v1.1).
- Секреты: только в Supabase secrets.

## 6. Подписки и entitlement на двоих

1. Продукты: `app.corbie.monthly` ($4,99), `app.corbie.yearly` ($29,99). Subscription group одна.
2. При покупке передаём `appAccountToken = Space.id` (UUID) в `Product.purchase(options:)`.
3. App Store Server Notifications V2 → микросервис → `entitlements[spaceId]`.
4. Клиент: при старте и раз в час — `GET /entitlement/:spaceId`; результат кэшируется в `Space.subscriptionStatus/ExpiresAt` в CloudKit (виден партнёру даже офлайн).
5. Локально на устройстве покупателя — ещё и `Transaction.currentEntitlements` (StoreKit 2) как быстрый путь.
6. Гейт: `isPremium = space.trialActive || entitlement.active`.
7. Restore: `AppStore.sync()` + запрос entitlement.

**Подводный камень:** партнёр, который не платил, не имеет транзакций в своём Apple ID — поэтому источник правды именно сервер по spaceId, а не StoreKit на устройстве.

## 7. Виджеты

- Отдельный target `CorbieWidgets`. Общий модуль `CorbieCore` (SPM local package) с моделью, репозиториями и форматтерами.
- Timeline: одна entry на «сейчас» + entry на полночь; reload по событиям.
- Интерактивные: `Button(intent: ToggleTaskIntent(taskID:))`, `Button(intent: TakeTaskIntent)`, `Button(intent: ToggleShoppingItemIntent)`.
- Конфигурируемые (`AppIntentConfiguration`): `Countdown` (выбор даты), `PlanProgress` (выбор плана), `accessoryCircular` (режим).
- Lock screen: `.accessoryCircular`, `.accessoryRectangular`, `.accessoryInline`; монохром, `widgetAccentable()`.
- Пейволл в виджете: если не premium и виджет платный — показываем placeholder «Unlock in Corbie» с deep link.

## 8. Уведомления

- Запрос разрешения — после первого совместного действия, не на онбординге.
- Локальные: даты, радар подарков (за 14 дней), капсулы (в день открытия), задачи со сроком.
- Удалённые (тихие): `CKDatabaseSubscription` на shared и private DB → `didReceiveRemoteNotification` → fetch → локальное уведомление по типу изменения (по `notificationPrefs`).
- Категории с действиями: Task → «Take» / «Done»; Vote → «Vote».

## 9. Парсинг ссылок

- Клиент: при вставке URL → `POST /parse` → заполняем поля; при ошибке — ручной ввод + «Choose photo».
- Share Extension: принимает URL/текст из любого приложения → тот же вызов → сохраняет Wish в общий SQLite → reload виджетов.
- Instagram/TikTok: oEmbed даёт превью и автора; название/цена — ручной ввод. Ссылку сохраняем как есть.
- Amazon: агрессивная антибот-защита; адаптер через `og:` + fallback на `<span id="productTitle">`; при провале — ручной ввод. Не обещаем 100%.

## 10. Валюты

- Валюта пространства (display) в Space. Суммы храним в исходной валюте + `fxRateToPlanCurrency` + `amountInPlanCurrency` на момент добавления.
- Курсы: `/fx` (ECB через Frankfurter), кэш на клиенте 24 ч. Топ-валюты: USD, EUR, GBP, CHF, CAD (+ локальная по локали).
- Форматирование — `NumberFormatter` с локалью.

## 11. Карты

- `MKLocalSearch` для поиска места из ListItem. Сохраняем name, address, lat, lon.
- `Map` (SwiftUI, iOS 17 API) с `Annotation` цветом автора. Тап → sheet с заметкой и «Open in Maps».
- Без своего геокодера, без ключей.

## 12. Локализация

- `Localizable.xcstrings`; ключи семантические (`tasks.empty.title`), не английские фразы.
- Даты/числа/валюты — только через `Locale.current`. Первый день недели — `Calendar.current.firstWeekday`.
- Стор-метаданные — через App Store Connect на 5 языках.

## 13. Аналитика (своя)

- События: `app_open`, `onboarding_step`, `space_created`, `invite_created`, `invite_redeemed`, `task_created(assignee)`, `task_taken`, `task_done`, `task_handed_back`, `event_created`, `wish_created(source)`, `wish_fulfilled`, `plan_created(type)`, `plan_completed`, `plan_step_created(has_due)`, `plan_step_done`, `expense_added`, `list_created(template)`, `list_item_checked`, `list_map_opened`, `capsule_created`, `capsule_opened`, `vote_created`, `vote_answered`, `vote_revealed`, `widget_added(kind)`, `paywall_shown(reason)`, `trial_started`, `purchase(product)`, `restore`, `readonly_hit`, `today_opened`, `today_block_tapped(block)`, `today_quick_action(kind)`, `recap_shown`, `recap_notification_sent`, `recap_opened`, `freetime_opened`, `freetime_sharing_enabled`, `freetime_sharing_disabled`, `freetime_slot_tapped`, `freetime_empty(reason)`, `question_shown`, `question_answered`, `question_revealed`, `question_nudge_sent`, `question_history_opened`, `chore_flow_started`, `chore_list_built(item_count)`, `chore_rating_done`, `chore_revealed(trade_count)`, `chore_applied(task_count)`, `chore_resplit`.
- `anonId` — UUID на устройстве, не связан с Apple ID. Никаких PII.
- Батч раз в 60 с или 20 событий; офлайн-очередь.
- Дашборд — SQL-вьюхи в Supabase: воронка онбординга, доля пар, D1/D7/D30, trial→paid.

## 14. Безопасность

- Keychain для anonId и кэша entitlement.
- ATS strict, только HTTPS.
- Apple identity token → микросервис, проверка подписи и `aud`.
- Никаких секретов в бинарнике.
- Face ID на разделы — v1.1 (`LAContext`).

## 15. Структура проекта

```
Corbie/
  Corbie.xcodeproj
  Packages/CorbieCore/          # SPM local: model, persistence, repositories, formatters, entitlement
    Sources/CorbieCore/
      Persistence/  (CoreDataStack, CloudKitSharing, Migrations)
      Model/        (Corbie.xcdatamodeld + NSManagedObject subclasses + DTOs)
      Repositories/ (TaskRepo, EventRepo, WishRepo, PlanRepo, ListRepo, CapsuleRepo, VoteRepo, PeopleRepo)
      Services/     (APIClient, LinkParser, FXService, EntitlementService, Analytics, Notifications)
      Design/       (Colors, Typography, Components)
  Corbie/                        # app target
    App/ (CorbieApp, AppState, Router)
    Features/ (Onboarding, Pairing, Tasks, Calendar, Wishes, Plans, Lists, Us, Capsules, Votes, People, Settings, Paywall)
    Resources/ (Assets, Localizable.xcstrings)
  CorbieWidgets/                 # widget extension
  CorbieShare/                   # share extension
  CorbieTests/  CorbieUITests/
  server/                        # Supabase project: supabase/functions/*, migrations/*
  docs/                          # 01, 02, 03 из пакета
  CLAUDE.md
```

## 16. Тестирование

- Unit: репозитории (in-memory store), форматтеры, FX-конверсия, recurrence, entitlement-гейт.
- Integration: CloudKit sharing — **обязательно на двух физических устройствах с разными Apple ID** (симулятор CloudKit sharing поддерживает частично). Чеклист: создать → пригласить → принять → изменение видно обеим сторонам → leave → delete.
- UI: смоук по каждому табу, пейволл, read-only.
- Виджеты: превью через `#Preview`, реальные — на устройстве.
- App Review чеклист: цена и условия на пейволле, restore, privacy labels, Sign in with Apple работает без сети на второй запуск, read-only не блокирует данные, нет пустых экранов при отклонённых разрешениях.

## 17. CI/CD

- Xcode Cloud: сборка на PR, тесты, TestFlight на main.
- Версионирование: `MARKETING_VERSION` semver, build auto.
- Supabase: `supabase db push` + `supabase functions deploy` через GitHub Actions.

## 18. Подводные камни (обязательно к прочтению перед кодом)

1. **SwiftData не умеет CKShare.** Только Core Data + NSPersistentCloudKitContainer.
2. **CloudKit требует optional/default у всех атрибутов** и не поддерживает unique constraints и ordered relationships.
3. **Sharing работает только с записями в кастомной зоне.** Контейнер делает это сам, но объекты, созданные до первой синхронизации, могут попасть в default zone — создавать Space только после инициализации контейнера и первого `initializeCloudKitSchema` в dev.
4. **Схема CloudKit в production деплоится вручную** из CloudKit Dashboard (dev → prod). Забыл — у пользователей ничего не синкается.
5. **Share extension и виджеты** должны использовать тот же App Group и тот же model; обновление модели → миграция везде.
6. **Интерактивные виджеты** требуют `AppIntent` в общем модуле, доступном и app, и widget target.
7. **Entitlement партнёра** — только через сервер по spaceId; StoreKit на его устройстве ничего не знает.
8. **`appAccountToken`** передаём при покупке всегда, иначе сервер не сопоставит транзакцию с пространством.
9. **App Store Server Notifications** нужны в sandbox и production отдельными URL.
10. **Amazon-парсинг** нестабилен — всегда путь ручного ввода.
11. **Первый день недели и форматы** — только через Locale; никаких хардкодов.
12. **Разрешения** (уведомления, календарь, фото) — запрашивать в контексте, не на старте.
13. **Sign in with Apple** — обязательно обрабатывать `credentialRevoked`; хранить user identifier в Keychain.
14. **Удаление аккаунта** — обязательное требование Apple; должно удалять share/участие и данные.
15. **Read-only режим** — календарь должен остаться полностью рабочим, иначе риск на ревью.
