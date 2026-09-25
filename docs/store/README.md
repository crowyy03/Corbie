# App Store metadata

One file per language: `en.md`, `es.md`, `fr.md`, `de.md`, `it.md`. English is the primary
localization; the other four are the launch markets from spec section 14.

## Where each field goes in App Store Connect

App Store Connect keeps these fields in two different places. The ones that change per version
sit under the version you are preparing; the ones that describe the app itself sit under the app.

| Field in our files | Where in App Store Connect | Limit | Editable without review |
|---|---|---|---|
| Name | App Store tab, version page, "Name" | 30 characters | No, ships with a version |
| Subtitle | App Store tab, version page, "Subtitle" | 30 characters | No, ships with a version |
| Keywords | App Store tab, version page, "Keywords" under App Information for that localization | 100 characters | No, ships with a version |
| Promotional text | App Store tab, version page, "Promotional Text" | 170 characters | Yes, any time |
| Description | App Store tab, version page, "Description" | 4000 characters | No, ships with a version |
| What's new | App Store tab, version page, "What's New in This Version" | 4000 characters | No, ships with a version |
| Screenshot captions | Burned into the screenshot images, not a field | - | No, ships with a version |

Every one of these fields is per language. Add the four extra localizations under the version
page ("Add Language"), then paste each file into its own language.

## Rules the copy already follows

- Keywords are comma separated with no spaces after the commas. A space costs a character.
- No keyword repeats a word from the name or the subtitle. App Store search already indexes
  those two fields, so repeating them wastes the 100 characters.
- No competitor names anywhere. Apple rejects them and it is a trademark risk.
- No exclamation marks, no emoji, no "love" or "couple" in a name, subtitle or headline.
  Brand book section 3 and 5.
- The first three lines of the description carry the value. On the store page everything after
  about three lines is behind "more", and most people never tap it.
- No amount of money appears in any listing. The base prices are set once in App Store Connect
  in US dollars and every other storefront gets Apple's automatic equivalent in its own currency,
  so a number printed here would be wrong somewhere. The app shows the real price from StoreKit.
- The subscription block states the terms only: one subscription for both, monthly or yearly, a
  14-day free trial for new subscribers, automatic renewal every month or every year, cancel
  anytime in Settings, and what keeps working without a subscription.
- Every description ends with these two lines, in English in all five files, word for word:
  `Terms: https://yourcorbie.app/terms` and `Privacy: https://yourcorbie.app/privacy`.

## What still has to be checked by hand

- The trial length in the listings (14 days) has to match the introductory offer set on both
  subscriptions in App Store Connect. If the offer changes, all five files change with it.
- Screenshot captions are the copy for six screens: widgets on the home screen, Today, tasks,
  wishes, a plan with its prep list, and the subscription. The image work is separate; the
  captions here are what goes on the art. Shared free time and the Sunday recap are described
  in the text but have no screenshot of their own yet.
- Without a subscription the calendar, Today (view only) and the weekly recap keep working.
  Every listing says so in the subscription block; if that changes, all five files change with it.
- The Terms of Use link also goes into App Store Connect: App Information, License Agreement
  (keep Apple's standard EULA or paste a custom one), and the description line above. Apple asks
  for the Terms of Use and the Privacy Policy links in the metadata of every app with
  subscriptions.
- Age rating 4+, categories Lifestyle (primary) and Productivity (secondary), per spec 12.
