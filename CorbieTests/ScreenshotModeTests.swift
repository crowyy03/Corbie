#if DEBUG
import CoreData
import CorbieCore
import XCTest
@testable import Corbie

final class ScreenshotModeDebugBuildTests: XCTestCase {
    func testTheModeIsCompiledIntoDebug() {
        XCTAssertEqual(String(describing: ScreenshotModeSwitch.self), "ScreenshotModeSwitch")
        XCTAssertEqual(String(describing: ScreenshotModeSection.self), "ScreenshotModeSection")
        XCTAssertEqual(String(describing: ScreenshotModeRoot.self), "ScreenshotModeRoot")
        XCTAssertEqual(String(describing: ScreenshotModeLifecycle.self), "ScreenshotModeLifecycle")
        XCTAssertEqual(ScreenshotModeFlag.launchArgument, "-corbie-screenshot-mode")
    }

    func testTheDebugAppBinariesCarryTheMarkersTheReleaseCheckSearchesFor() throws {
        let app = Bundle.main.bundleURL
        let appBinaries = try machOFiles(in: app).filter { $0.path.contains(".appex/") == false }
        XCTAssertFalse(appBinaries.isEmpty)
        XCTAssertTrue(try contains("ScreenshotModeSwitch", in: appBinaries))
        XCTAssertTrue(try contains(ScreenshotModeFlag.launchArgument, in: appBinaries))
        XCTAssertTrue(try contains("Noise-cancelling headphones", in: appBinaries))

        let widgets = try XCTUnwrap(Bundle.main.builtInPlugInsURL).appendingPathComponent("CorbieWidgets.appex")
        let widgetBinaries = try machOFiles(in: widgets)
        XCTAssertFalse(widgetBinaries.isEmpty)
        XCTAssertTrue(try contains("ScreenshotMode", in: widgetBinaries))
    }

    private func machOFiles(in directory: URL) throws -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey]
        guard let walker = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: keys) else {
            return []
        }
        var found: [URL] = []
        for case let url as URL in walker where url.path.contains(".xctest") == false {
            guard try url.resourceValues(forKeys: Set(keys)).isRegularFile == true,
                  let handle = try? FileHandle(forReadingFrom: url)
            else { continue }
            let magic = try handle.read(upToCount: 4) ?? Data()
            try handle.close()
            if ScreenshotModeDebugBuildTests.machOMagics.contains(magic) {
                found.append(url)
            }
        }
        return found
    }

    private func contains(_ marker: String, in files: [URL]) throws -> Bool {
        let needle = Data(marker.utf8)
        for file in files where try Data(contentsOf: file, options: .mappedIfSafe).range(of: needle) != nil {
            return true
        }
        return false
    }

    private static let machOMagics: Set<Data> = [
        Data([0xCF, 0xFA, 0xED, 0xFE]),
        Data([0xCE, 0xFA, 0xED, 0xFE]),
        Data([0xCA, 0xFE, 0xBA, 0xBE])
    ]
}

@MainActor
final class ScreenshotModeSwitchTests: XCTestCase {
    private var sandbox: ScreenshotModeSandbox!

    override func setUp() async throws {
        sandbox = try ScreenshotModeSandbox()
    }

    override func tearDown() async throws {
        sandbox.clean()
        sandbox = nil
    }

    func testEnteringAndLeavingKeepsTheRealStoreAndBringsTheRealEnvironmentBack() async throws {
        let real = try await sandbox.startedRealEnvironment()
        let realSpace = try XCTUnwrap(real.space)
        let realInvite = LiveInvite(
            code: "REAL42",
            expiresAt: Date().addingTimeInterval(3600),
            spaceId: realSpace.id,
            existingPartnerId: nil
        )
        LiveInviteStore(defaults: sandbox.appGroupDefaults).save(realInvite)
        let switcher = sandbox.makeSwitch(real: real)
        _ = try real.persistence.stack.processHistory()
        let before = try ScreenshotModeStoreSnapshot(real.persistence)
        let appGroupBefore = sandbox.appGroupDomain

        await switcher.enter()
        XCTAssertEqual(switcher.phase, .on)
        let demo = try XCTUnwrap(switcher.active)
        XCTAssertFalse(demo === real)
        XCTAssertTrue(demo.isScreenshotMode)
        XCTAssertFalse(real.isScreenshotMode)
        XCTAssertTrue(real.isParkedForScreenshotMode)
        XCTAssertFalse(demo.persistence === real.persistence)
        XCTAssertNil(demo.persistence.stack.cloudKitContainer)
        XCTAssertTrue(demo.secrets is ScreenshotModeSecretStore)
        XCTAssertFalse(demo.store === StoreService.shared)
        XCTAssertTrue(demo.theme === real.theme)
        XCTAssertEqual(sandbox.flag.session, switcher.sessionId)
        var appGroupInTheMode = sandbox.appGroupDomain
        XCTAssertEqual(appGroupInTheMode[ScreenshotModeFlag.sessionKey] as? String, switcher.sessionId)
        appGroupInTheMode[ScreenshotModeFlag.sessionKey] = nil
        XCTAssertEqual(appGroupInTheMode as NSDictionary, appGroupBefore as NSDictionary)

        await switcher.bootstrap(demo)
        XCTAssertEqual(demo.currentMember?.displayName, ScreenshotModeDemo.meName)
        XCTAssertEqual(demo.partner?.displayName, ScreenshotModeDemo.partnerName)
        XCTAssertEqual(demo.space?.displayCurrency, "USD")
        XCTAssertTrue(sandbox.intents.controller() === demo.persistence)

        let space = try XCTUnwrap(demo.space)
        do {
            _ = try await demo.sharing.share(space: space.id)
            XCTFail("a screenshot-mode space must never be shared")
        } catch {
            XCTAssertEqual(error as? CorbieError, CorbieError.cloudKit("CloudKit container is not configured"))
        }

        let invite = InviteViewModel(
            environment: demo,
            appState: AppState(),
            spaceId: space.id,
            minter: ScreenshotModeFixedMinter(code: "DEMO42"),
            leave: {}
        )
        await invite.makeNewCode()
        XCTAssertEqual(invite.code, "DEMO42")
        XCTAssertEqual(LiveInviteStore(defaults: demo.defaults).live(for: space.id, at: Date())?.code, "DEMO42")
        XCTAssertEqual(LiveInviteStore(defaults: sandbox.appGroupDefaults).live(for: realSpace.id, at: Date()), realInvite)

        let settings = SettingsViewModel()
        settings.attach(demo)
        await settings.deleteAccount()
        await settings.leaveSpace()
        XCTAssertTrue(demo.isSignedIn)
        XCTAssertEqual(demo.space?.id, space.id)
        XCTAssertEqual(demo.toasts.current?.text, ScreenshotModeRefusal.accountChange.errorDescription)

        await real.publishBusyTimes(force: true)

        await switcher.leave()
        XCTAssertEqual(switcher.phase, .real)
        XCTAssertTrue(switcher.active === real)
        XCTAssertNil(switcher.demo)
        XCTAssertFalse(real.isParkedForScreenshotMode)
        XCTAssertFalse(sandbox.flag.isOn)
        XCTAssertTrue(sandbox.intents.controller() === real.persistence)
        XCTAssertEqual(real.currentMember?.displayName, "Real me")

        XCTAssertEqual(try ScreenshotModeStoreSnapshot(real.persistence), before)
        XCTAssertEqual(sandbox.appGroupDomain as NSDictionary, appGroupBefore as NSDictionary)
        let realTasks = try await real.repositories.tasks.tasks(TaskQuery(spaceId: realSpace.id))
        XCTAssertEqual(realTasks.map(\.title), ["Real task"])
        let demoAlex = try await real.repositories.members.member(appleUserId: ScreenshotModeDemo.meAppleUserId)
        XCTAssertNil(demoAlex)
        XCTAssertFalse(sandbox.transport.paths.contains { $0.contains(APIClient.Path.invite) })

        await real.publishBusyTimes(force: true)
        let horizon = Date().addingTimeInterval(TimeInterval(BusyWindow.horizonDays) * 86_400)
        let published = try await real.repositories.busyIntervals.intervals(spaceId: realSpace.id, from: Date(), to: horizon)
        XCTAssertEqual(Set(published.map(\.source)), [.corbie, .device])
    }

    func testTheLaunchArgumentEntersFreshARelaunchResumesAndOffLeaves() async throws {
        let real = try await sandbox.startedRealEnvironment()
        let launched = sandbox.makeSwitch(real: real)
        launched.start(arguments: ["Corbie", ScreenshotModeFlag.launchArgument, "on"])
        XCTAssertEqual(launched.phase, .preparing)
        XCTAssertNil(launched.active)
        try await waitUntilSettled(launched)
        XCTAssertEqual(launched.phase, .on)
        let session = try XCTUnwrap(launched.sessionId)

        let relaunched = sandbox.makeSwitch(real: real)
        relaunched.start(arguments: ["Corbie"])
        try await waitUntilSettled(relaunched)
        XCTAssertEqual(relaunched.phase, .on)
        XCTAssertEqual(relaunched.sessionId, session)

        let switchedOff = sandbox.makeSwitch(real: real)
        switchedOff.start(arguments: ["Corbie", ScreenshotModeFlag.launchArgument, "off"])
        XCTAssertEqual(switchedOff.phase, .real)
        XCTAssertFalse(sandbox.flag.isOn)
        XCTAssertTrue(sandbox.intents.controller() === real.persistence)
    }

    private func waitUntilSettled(_ switcher: ScreenshotModeSwitch) async throws {
        for _ in 0 ..< 200 where switcher.phase == .preparing {
            try await Task.sleep(for: .milliseconds(25))
        }
        XCTAssertNotEqual(switcher.phase, .preparing)
    }
}

@MainActor
private final class ScreenshotModeSandbox {
    let appGroup: URL
    let transport = ScreenshotModeRecordingTransport()
    private let appGroupSuite = "corbie-screenshot-app-group-" + UUID().uuidString
    private let demoSuite = "corbie-screenshot-demo-" + UUID().uuidString
    private(set) lazy var intents = IntentPersistence(screenshotModeFlag: flag, screenshotModeStore: store)

    init() throws {
        appGroup = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("corbie-app-group-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: appGroup, withIntermediateDirectories: true)
    }

    var flag: ScreenshotModeFlag {
        ScreenshotModeFlag(defaults: appGroupDefaults)
    }

    var store: ScreenshotModeStore {
        ScreenshotModeStore(
            root: appGroup.appendingPathComponent(ScreenshotModeStore.directoryName, isDirectory: true),
            defaultsSuiteName: demoSuite
        )
    }

    var appGroupDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupSuite) ?? UserDefaults()
    }

    var appGroupDomain: [String: Any] {
        appGroupDefaults.persistentDomain(forName: appGroupSuite) ?? [:]
    }

    func startedRealEnvironment() async throws -> AppEnvironment {
        let stack = CoreDataStack(storesIn: appGroup, author: .app, historyDefaults: appGroupDefaults)
        let persistence = PersistenceController(stack: stack)
        let space = try await persistence.repositories.spaces.create(displayCurrency: "EUR")
        let me = try await persistence.repositories.members.upsertCurrentMember(
            appleUserId: "real.me",
            spaceId: space.id,
            draft: MemberDraft(displayName: "Real me", colorKey: MemberColorSlot.blue.rawValue),
            theme: .sand
        ).member
        _ = try await persistence.repositories.members.setSharesBusyTimes(memberId: me.id, shares: true)
        _ = try await persistence.repositories.tasks.create(TaskDraft(spaceId: space.id, title: "Real task"))
        let dinner = Date().addingTimeInterval(86_400)
        _ = try await persistence.repositories.events.create(
            EventDraft(spaceId: space.id, title: "Real dinner", startAt: dinner, endAt: dinner.addingTimeInterval(7200))
        )
        let environment = AppEnvironment(
            persistence: persistence,
            secrets: InMemorySecretStore(),
            anonymousIdentity: .inMemory(),
            notificationClient: PreviewNotificationClient(),
            store: StoreService(),
            transport: transport,
            defaults: appGroupDefaults,
            analyticsDelivery: .discarded,
            analyticsStorage: InMemoryAnalyticsStorage(),
            intents: intents,
            storageProbe: { nil },
            deviceCalendar: ScreenshotModeBusyCalendar(busy: DateInterval(start: dinner.addingTimeInterval(86_400), duration: 3600))
        )
        try environment.identity.setAppleUserID("real.me")
        await environment.processReady()
        return environment
    }

    func makeSwitch(real: AppEnvironment) -> ScreenshotModeSwitch {
        let calendar = Calendar.current
        let today = Date()
        return ScreenshotModeSwitch(
            real: real,
            appState: AppState(),
            lifecycle: ScreenshotModeLifecycle(
                flag: flag,
                store: store,
                intents: intents,
                calendar: calendar,
                now: { today },
                reloadWidgets: {}
            ),
            transport: transport
        )
    }

    func clean() {
        try? FileManager.default.removeItem(at: appGroup)
        for suite in [appGroupSuite, demoSuite] {
            UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        }
        IntentPersistence.shared.reset()
    }
}

private struct ScreenshotModeStoreSnapshot: Equatable {
    let counts: [String: Int]
    let transactions: Int
    let lastTransaction: Date?

    init(_ controller: PersistenceController) throws {
        let context = controller.stack.newBackgroundContext()
        let read = try context.performAndWait {
            var counts: [String: Int] = [:]
            for name in CorbieModel.shared.entities.compactMap(\.name) {
                counts[name] = try context.count(for: NSFetchRequest<NSFetchRequestResult>(entityName: name))
            }
            let request = NSPersistentHistoryChangeRequest.fetchHistory(after: Date.distantPast)
            let result = try context.execute(request) as? NSPersistentHistoryResult
            let history = result?.result as? [NSPersistentHistoryTransaction] ?? []
            return (counts, history.count, history.last?.timestamp)
        }
        counts = read.0
        transactions = read.1
        lastTransaction = read.2
    }
}

private struct ScreenshotModeFixedMinter: InviteMinting {
    let code: String

    func mint(spaceId: UUID) async throws -> InviteCode {
        InviteCode(code: code, expiresAt: Date().addingTimeInterval(3600))
    }
}

private struct ScreenshotModeBusyCalendar: DeviceCalendarSource {
    let busy: DateInterval

    func requestAccess() async throws -> Bool { true }

    func busyRanges(from: Date, to: Date) async throws -> [DateInterval] { [busy] }
}

private final class ScreenshotModeRecordingTransport: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [String] = []

    var paths: [String] {
        lock.withLock { recorded }
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        lock.withLock { recorded.append(request.url.path) }
        throw URLError(.notConnectedToInternet)
    }
}
#endif
