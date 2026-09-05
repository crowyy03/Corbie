import Foundation
import Testing
@testable import CorbieCore

@Suite struct NetAnalyticsEventTests {
    private let everyEvent: [AnalyticsEvent] = [
        .appOpen,
        .onboardingStep(2),
        .spaceCreated,
        .inviteCreated,
        .inviteRedeemed,
        .taskCreated(assignee: .partner),
        .taskTaken,
        .taskDone,
        .taskHandedBack,
        .eventCreated(kind: .birthday),
        .wishCreated(source: .amazon),
        .wishFulfilled,
        .planCreated(type: .trip),
        .expenseAdded,
        .listCreated(template: .shopping),
        .listItemChecked,
        .listMapOpened,
        .capsuleCreated,
        .capsuleOpened,
        .voteCreated,
        .voteAnswered,
        .voteRevealed,
        .widgetAdded(kind: "DaysTogether"),
        .paywallShown(reason: .trialEnded),
        .trialStarted,
        .purchase(product: "app.corbie.yearly"),
        .restore,
        .readonlyHit(action: .create)
    ]

    @Test func everyNameIsOnTheServerAllowlist() {
        #expect(everyEvent.count == AnalyticsEvent.allowedNames.count)
        for event in everyEvent {
            #expect(AnalyticsEvent.allowedNames.contains(event.name))
        }
        #expect(Set(everyEvent.map(\.name)) == AnalyticsEvent.allowedNames)
    }

    @Test func propsCarryNoPersonalKeysAndStayScalar() {
        for event in everyEvent {
            #expect(event.props.count <= 10)
            for key in event.props.keys {
                #expect(AnalyticsEvent.droppedPropKeys.contains(key.lowercased()) == false)
                #expect(key.count <= 40)
            }
            for value in event.props.values {
                if case let .string(text) = value {
                    #expect(text.count <= 200)
                }
            }
        }
    }

    @Test func freeFormPropsAreReducedToASlug() throws {
        #expect(AnalyticsEvent.widgetAdded(kind: "Days Together").props["kind"] == .string("days_together"))
        #expect(AnalyticsEvent.purchase(product: "app.corbie.yearly").props["product"] == .string("app.corbie.yearly"))
        let leak = AnalyticsEvent.widgetAdded(kind: "sofia@example.com wants a widget with a really long name")
        let kind = try #require(leak.props["kind"])
        guard case let .string(value) = kind else {
            Issue.record("expected a string prop")
            return
        }
        #expect(value.count <= 40)
        #expect(value.contains("@") == false)
        #expect(value.contains(" ") == false)
    }

    @Test func propsMatchTheSpecForTheEventsThatCarryThem() {
        #expect(AnalyticsEvent.taskCreated(assignee: .partner).props == ["assignee": .string("partner")])
        #expect(AnalyticsEvent.wishCreated(source: .etsy).props == ["source": .string("etsy")])
        #expect(AnalyticsEvent.listCreated(template: .cities).props == ["template": .string("cities")])
        #expect(AnalyticsEvent.paywallShown(reason: .trialEnded).props == ["reason": .string("trial_ended")])
        #expect(AnalyticsEvent.onboardingStep(3).props == ["step": .number(3)])
        #expect(AnalyticsEvent.appOpen.props.isEmpty)
    }
}

@Suite struct NetAnalyticsQueueTests {
    private func analytics(
        transport: FakeTransport,
        storage: any AnalyticsStorage,
        threshold: Int = Analytics.flushThreshold
    ) -> Analytics {
        Analytics(
            client: NetTestSupport.client(transport: transport, retry: .noRetries),
            storage: storage,
            identity: AnonymousIdentity.inMemory(value: "6f1e4a1e-0d5f-4e0e-9a54-1a5c1a2b3c4d"),
            appVersion: "1.0 (12)",
            locale: Locale(identifier: "en_US"),
            threshold: threshold,
            now: { NetTestSupport.date("2026-09-05T10:00:00Z") }
        )
    }

    @Test func eventsQueueUpUntilTheThreshold() async throws {
        let transport = FakeTransport([.empty(202)])
        let storage = InMemoryAnalyticsStorage()
        let service = analytics(transport: transport, storage: storage, threshold: 20)

        for _ in 0 ..< 19 {
            await service.track(.appOpen)
        }
        #expect(await service.pendingCount == 19)
        #expect(transport.requestCount == 0)
        #expect(storage.load().count == 19)

        await service.track(.taskDone)
        #expect(await service.pendingCount == 0)
        #expect(transport.requestCount == 1)
        #expect(storage.load().isEmpty)

        let sent = NetTestSupport.decodeBatch(transport.lastRequest)
        #expect(sent.count == 20)
        #expect(sent.last?.name == "task_done")
        #expect(sent.first?.appVersion == "1.0 (12)")
        #expect(sent.first?.locale == "en_US")
        #expect(sent.first?.ts == NetTestSupport.date("2026-09-05T10:00:00Z"))
    }

    @Test func aBacklogGoesOutInBatchesOfFifty() async throws {
        let payload = AnalyticsEventPayload(
            name: "app_open",
            props: [:],
            ts: NetTestSupport.date("2026-09-05T10:00:00Z"),
            appVersion: "1.0 (12)",
            locale: "en_US"
        )
        let storage = InMemoryAnalyticsStorage(events: Array(repeating: payload, count: 120))
        let transport = FakeTransport([.empty(202)])
        let service = analytics(transport: transport, storage: storage)

        await service.flush()
        #expect(transport.requestCount == 3)
        #expect(transport.requests.map { NetTestSupport.decodeBatch($0).count } == [50, 50, 20])
        #expect(await service.pendingCount == 0)
        #expect(storage.load().isEmpty)
    }

    @Test func anOfflineFlushKeepsTheQueue() async throws {
        let transport = FakeTransport([.urlFailure(.notConnectedToInternet)])
        let storage = InMemoryAnalyticsStorage()
        let service = analytics(transport: transport, storage: storage, threshold: 2)

        await service.track(.appOpen)
        await service.track(.spaceCreated)
        #expect(await service.pendingCount == 2)
        #expect(storage.load().count == 2)

        let online = FakeTransport([.empty(202)])
        let resumed = analytics(transport: online, storage: storage)
        await resumed.flush()
        #expect(await resumed.pendingCount == 0)
        #expect(NetTestSupport.decodeBatch(online.lastRequest).map(\.name) == ["app_open", "space_created"])
    }

    @Test func aBatchTheServerRefusesIsDropped() async throws {
        let transport = FakeTransport([.json(#"{"error":"invalid_request","message":"nope"}"#, status: 400)])
        let storage = InMemoryAnalyticsStorage()
        let service = analytics(transport: transport, storage: storage, threshold: 1)
        await service.track(.appOpen)
        #expect(await service.pendingCount == 0)
        #expect(storage.load().isEmpty)
    }

    @Test func theQueueNeverGrowsPastItsLimit() async throws {
        let transport = FakeTransport([.urlFailure(.notConnectedToInternet)])
        let storage = InMemoryAnalyticsStorage()
        let service = analytics(transport: transport, storage: storage, threshold: 10_000)
        for _ in 0 ..< (Analytics.queueLimit + 25) {
            await service.track(.appOpen)
        }
        #expect(await service.pendingCount == Analytics.queueLimit)
    }

    @Test func theFileQueueSurvivesARestart() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("corbie-analytics-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let storage = FileAnalyticsStorage(directory: directory)
        #expect(storage.load().isEmpty)

        let payload = AnalyticsEventPayload(
            name: "wish_created",
            props: ["source": .string("amazon")],
            ts: NetTestSupport.date("2026-09-05T10:00:00Z"),
            appVersion: "1.0 (12)",
            locale: "en_US"
        )
        storage.save([payload])

        let reopened = FileAnalyticsStorage(directory: directory)
        #expect(reopened.load() == [payload])

        reopened.save([])
        #expect(FileAnalyticsStorage(directory: directory).load().isEmpty)
    }

    @Test func theAnonIdIsStableAndComesFromTheSecretStore() {
        let store = InMemorySecretStore()
        let identity = AnonymousIdentity(store: store)
        let first = identity.current
        #expect(UUID(uuidString: first) != nil)
        #expect(first == first.lowercased())
        #expect(identity.current == first)
        #expect(AnonymousIdentity(store: store).current == first)

        identity.reset()
        #expect(identity.current != first)

        let volatile = AnonymousIdentity.inMemory()
        let generated = volatile.current
        #expect(volatile.current == generated)
        #expect(AnonymousIdentity.inMemory().current != generated)
    }
}
