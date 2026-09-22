import CloudKit
import CorbieCore
import XCTest
@testable import Corbie

final class PairingInviteTests: XCTestCase {
    func testSanitizeUppercasesAndDropsCharactersOutsideTheAlphabet() {
        XCTAssertEqual(InviteCodeFormat.sanitize("k7m2qx"), "K7M2QX")
        XCTAssertEqual(InviteCodeFormat.sanitize("k7-m2 qx"), "K7M2QX")
        XCTAssertEqual(InviteCodeFormat.sanitize("IL01O"), "")
    }

    func testSanitizeStopsAtSixCharacters() {
        XCTAssertEqual(InviteCodeFormat.sanitize("K7M2QXABC"), "K7M2QX")
        XCTAssertEqual(InviteCodeFormat.sanitize("K7M2QX").count, InviteCodeFormat.length)
    }

    func testCompletenessNeedsSixUsableCharacters() {
        XCTAssertTrue(InviteCodeFormat.isComplete("k7m2qx"))
        XCTAssertFalse(InviteCodeFormat.isComplete("K7M2Q"))
        XCTAssertFalse(InviteCodeFormat.isComplete("K7M2QI"))
        XCTAssertFalse(InviteCodeFormat.isComplete(""))
    }

    func testAlphabetLeavesOutTheAmbiguousLettersAndDigits() {
        for character in "IL10O" {
            XCTAssertFalse(InviteCodeFormat.alphabet.contains(character))
        }
    }

    func testSpelledOutSeparatesCharactersForVoiceOver() {
        XCTAssertEqual(InviteCodeFormat.spelledOut("K7M2QX"), "K 7 M 2 Q X")
    }

    func testSharedLinkParsesBackIntoAJoinRoute() throws {
        let url = try XCTUnwrap(InviteLink.url(code: "K7M2QX"))
        XCTAssertEqual(url.absoluteString, "https://yourcorbie.app/join/K7M2QX")
        XCTAssertEqual(Router.route(for: url), .join("K7M2QX"))
    }

    func testSharedLinkNeedsACode() {
        XCTAssertNil(InviteLink.url(code: ""))
        XCTAssertEqual(InviteLink.message(code: ""), "")
    }

    func testCountdownCountsDownToZero() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let expiresAt = now.addingTimeInterval(15 * 60)

        XCTAssertEqual(InviteCountdown(expiresAt: expiresAt, now: now).text(locale: .posix), "15:00")
        XCTAssertEqual(
            InviteCountdown(expiresAt: expiresAt, now: now.addingTimeInterval(1)).text(locale: .posix),
            "14:59"
        )
        XCTAssertEqual(
            InviteCountdown(expiresAt: expiresAt, now: now.addingTimeInterval(15 * 60 - 61)).text(locale: .posix),
            "1:01"
        )
    }

    func testCountdownClampsAtZeroOnceItExpired() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let countdown = InviteCountdown(expiresAt: now.addingTimeInterval(-30), now: now)

        XCTAssertTrue(countdown.isExpired)
        XCTAssertEqual(countdown.remaining, 0)
        XCTAssertEqual(countdown.text(locale: .posix), "0:00")
    }

    func testCountdownIsNotExpiredWithASecondLeft() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let countdown = InviteCountdown(expiresAt: now.addingTimeInterval(1), now: now)

        XCTAssertFalse(countdown.isExpired)
        XCTAssertEqual(countdown.text(locale: .posix), "0:01")
    }

    func testPairingFailureNamesWhatTheServerSaid() {
        XCTAssertEqual(PairingFailure.kind(for: serverError(status: 404, code: "not_found")), .notFound)
        XCTAssertEqual(PairingFailure.kind(for: serverError(status: 410, code: "expired")), .expired)
        XCTAssertEqual(PairingFailure.kind(for: serverError(status: 409, code: "redeemed")), .redeemed)
        XCTAssertEqual(PairingFailure.kind(for: serverError(status: 410, code: "redeemed")), .redeemed)
        XCTAssertEqual(PairingFailure.kind(for: serverError(status: 410, code: "superseded")), .superseded)
        XCTAssertEqual(PairingFailure.kind(for: serverError(status: 429, code: "rate_limited")), .throttled)
        XCTAssertEqual(PairingFailure.kind(for: serverError(status: 401, code: "unauthorized")), .signInAgain)
        XCTAssertEqual(PairingFailure.kind(for: CorbieError.cloudKit("no account")), .iCloud)
        XCTAssertEqual(PairingFailure.kind(for: CorbieError.network("offline")), .network)
        XCTAssertEqual(PairingFailure.kind(for: APIError(kind: .notConfigured, detail: "no url")), .serverMissing)
    }

    func testPairingFailureNamesWhatCloudKitSaid() {
        let cases: [(CKError.Code, PairingFailure)] = [
            (.notAuthenticated, .signedOutOfICloud),
            (.managedAccountRestricted, .signedOutOfICloud),
            (.accountTemporarilyUnavailable, .iCloudBusy),
            (.requestRateLimited, .iCloudBusy),
            (.networkUnavailable, .network),
            (.networkFailure, .network),
            (.unknownItem, .shareMissing),
            (.zoneNotFound, .shareMissing),
            (.internalError, .iCloud)
        ]
        for (code, expected) in cases {
            let failure = CloudKitFailure(step: "accept share", error: CKError(code))
            XCTAssertEqual(PairingFailure.kind(for: failure), expected, "\(code)")
        }
    }

    func testEveryPairingFailureCarriesItsOwnSentence() {
        var seen: Set<String> = []
        for failure in PairingFailure.allCases {
            let message = failure.message
            XCTAssertFalse(message.isEmpty, failure.rawValue)
            XCTAssertFalse(message.hasPrefix("pairing."), "\(failure.rawValue) shows a raw key")
            XCTAssertFalse(message.hasPrefix("error."), "\(failure.rawValue) shows a raw key")
            XCTAssertEqual(failure.errorDescription, message)
            seen.insert(message)
        }
        XCTAssertGreaterThanOrEqual(seen.count, PairingFailure.allCases.count - 1)
    }

    func testASupersededCodeSaysANewerCodeReplacedIt() {
        let superseded = PairingFailure.superseded.message
        XCTAssertNotEqual(superseded, PairingFailure.expired.message)
        XCTAssertNotEqual(superseded, PairingFailure.redeemed.message)
        XCTAssertFalse(superseded.hasPrefix("pairing."))
    }

    @MainActor
    func testReopeningTheInviteShowsTheLiveCodeInsteadOfMintingAnother() async {
        let now = Date()
        let spaceId = UUID()
        let store = LiveInviteStore(suiteName: suiteName)
        let minter = ScriptedMinter(codes: ["FYDW7C", "JHQ6FU", "XAQ5Y9"], expiresAt: now.addingTimeInterval(15 * 60))
        let environment = AppEnvironment.preview()

        let first = inviteModel(environment: environment, spaceId: spaceId, store: store, minter: minter, now: { now })
        await first.appear(partner: nil, reduceMotion: true)
        for minutesLater in [1.0, 5.0, 14.0] {
            let reopened = inviteModel(
                environment: environment,
                spaceId: spaceId,
                store: store,
                minter: minter,
                now: { now.addingTimeInterval(minutesLater * 60) }
            )
            await reopened.appear(partner: nil, reduceMotion: true)
            XCTAssertEqual(reopened.phase, .ready)
            XCTAssertEqual(reopened.code, "FYDW7C")
            XCTAssertEqual(reopened.expiresAt, first.expiresAt)
        }
        XCTAssertEqual(minter.minted, ["FYDW7C"])
    }

    @MainActor
    func testNewCodeReplacesTheLiveCode() async {
        let now = Date()
        let spaceId = UUID()
        let store = LiveInviteStore(suiteName: suiteName)
        let minter = ScriptedMinter(codes: ["FYDW7C", "JHQ6FU"], expiresAt: now.addingTimeInterval(15 * 60))
        let environment = AppEnvironment.preview()

        let model = inviteModel(environment: environment, spaceId: spaceId, store: store, minter: minter, now: { now })
        await model.appear(partner: nil, reduceMotion: true)
        await model.makeNewCode()

        XCTAssertEqual(minter.minted, ["FYDW7C", "JHQ6FU"])
        XCTAssertEqual(model.code, "JHQ6FU")
        XCTAssertEqual(store.live(for: spaceId, at: now)?.code, "JHQ6FU")

        let reopened = inviteModel(environment: environment, spaceId: spaceId, store: store, minter: minter, now: { now })
        await reopened.appear(partner: nil, reduceMotion: true)
        XCTAssertEqual(reopened.code, "JHQ6FU")
        XCTAssertEqual(minter.minted.count, 2)
    }

    @MainActor
    func testAnExpiredCodeOrOneForAnotherSpaceIsReplacedOnOpen() async {
        let now = Date()
        let spaceId = UUID()
        let store = LiveInviteStore(suiteName: suiteName)
        let minter = ScriptedMinter(codes: ["JHQ6FU", "XAQ5Y9"], expiresAt: now.addingTimeInterval(15 * 60))
        let environment = AppEnvironment.preview()

        store.save(LiveInvite(code: "FYDW7C", expiresAt: now, spaceId: spaceId, existingPartnerId: nil))
        let afterExpiry = inviteModel(environment: environment, spaceId: spaceId, store: store, minter: minter, now: { now })
        await afterExpiry.appear(partner: nil, reduceMotion: true)
        XCTAssertEqual(afterExpiry.code, "JHQ6FU")

        let otherSpace = UUID()
        let elsewhere = inviteModel(environment: environment, spaceId: otherSpace, store: store, minter: minter, now: { now })
        await elsewhere.appear(partner: nil, reduceMotion: true)
        XCTAssertEqual(elsewhere.code, "XAQ5Y9")
        XCTAssertNil(store.live(for: spaceId, at: now))
        XCTAssertEqual(minter.minted, ["JHQ6FU", "XAQ5Y9"])
    }

    @MainActor
    func testANewCodeThatFailsDoesNotBringTheOldCodeBack() async {
        let now = Date()
        let spaceId = UUID()
        let store = LiveInviteStore(suiteName: suiteName)
        let minter = ScriptedMinter(codes: ["FYDW7C"], expiresAt: now.addingTimeInterval(15 * 60))
        let environment = AppEnvironment.preview()

        let model = inviteModel(environment: environment, spaceId: spaceId, store: store, minter: minter, now: { now })
        await model.appear(partner: nil, reduceMotion: true)
        await model.makeNewCode()

        XCTAssertEqual(model.phase, .failed)
        XCTAssertNil(model.code)
        XCTAssertNil(store.live(for: spaceId, at: now))
    }

    func testTheLiveCodeSurvivesInTheSharedDefaults() throws {
        let now = Date()
        let spaceId = UUID()
        let invite = LiveInvite(code: "K7M2QX", expiresAt: now.addingTimeInterval(60), spaceId: spaceId, existingPartnerId: UUID())
        LiveInviteStore(suiteName: suiteName).save(invite)

        let reread = LiveInviteStore(suiteName: suiteName)
        XCTAssertEqual(reread.live(for: spaceId, at: now), invite)
        XCTAssertNil(reread.live(for: spaceId, at: now.addingTimeInterval(60)))
        XCTAssertNil(reread.live(for: UUID(), at: now))
        reread.forget()
        XCTAssertNil(reread.live(for: spaceId, at: now))
    }

    func testACodeStoredBeforeThePartnerFieldStillReads() throws {
        let now = Date()
        let spaceId = UUID()
        let stored: [String: Any] = [
            "code": "K7M2QX",
            "expiresAt": now.addingTimeInterval(60).timeIntervalSinceReferenceDate,
            "spaceId": spaceId.uuidString
        ]
        UserDefaults(suiteName: suiteName)?.set(
            try JSONSerialization.data(withJSONObject: stored),
            forKey: LiveInviteStore.storageKey
        )

        let live = try XCTUnwrap(LiveInviteStore(suiteName: suiteName).live(for: spaceId, at: now))
        XCTAssertEqual(live.code, "K7M2QX")
        XCTAssertNil(live.existingPartnerId)
    }

    @MainActor
    func testThePartnerArrivingSwitchesTheInviteToJoinedAndMovesToToday() async {
        let now = Date()
        let spaceId = UUID()
        let store = LiveInviteStore(suiteName: suiteName)
        let minter = ScriptedMinter(codes: ["FYDW7C", "JHQ6FU"], expiresAt: now.addingTimeInterval(15 * 60))
        let appState = awayFromToday()
        var leaves = 0
        let model = inviteModel(
            environment: AppEnvironment.preview(),
            spaceId: spaceId,
            store: store,
            minter: minter,
            now: { now },
            appState: appState,
            leave: { leaves += 1 }
        )

        await model.appear(partner: nil, reduceMotion: true)
        XCTAssertEqual(model.phase, .ready)
        XCTAssertEqual(leaves, 0)

        await model.apply(partner: partner(named: "Anna", in: spaceId), reduceMotion: true)

        XCTAssertEqual(model.phase, .joined)
        XCTAssertEqual(model.joinedLine, InviteViewModel.joinedLine(name: "Anna"))
        XCTAssertNil(model.code)
        XCTAssertNil(model.countdown(at: now))
        XCTAssertFalse(model.isShareable(at: now))
        XCTAssertNil(store.live(for: spaceId, at: now))
        XCTAssertEqual(appState.selectedTab, .today)
        XCTAssertFalse(appState.isUsHubPresented)
        XCTAssertEqual(leaves, 1)

        await model.makeNewCode()
        await model.apply(partner: partner(named: "Anna", in: spaceId), reduceMotion: true)
        XCTAssertEqual(model.phase, .joined)
        XCTAssertEqual(minter.minted, ["FYDW7C"])
        XCTAssertEqual(leaves, 1)
    }

    @MainActor
    func testOpeningTheInviteAfterThePartnerJoinedGoesStraightToJoined() async {
        let now = Date()
        let spaceId = UUID()
        let store = LiveInviteStore(suiteName: suiteName)
        let minter = ScriptedMinter(codes: ["JHQ6FU"], expiresAt: now.addingTimeInterval(15 * 60))
        let appState = awayFromToday()
        var leaves = 0
        store.save(
            LiveInvite(code: "FYDW7C", expiresAt: now.addingTimeInterval(10 * 60), spaceId: spaceId, existingPartnerId: nil)
        )
        let model = inviteModel(
            environment: AppEnvironment.preview(),
            spaceId: spaceId,
            store: store,
            minter: minter,
            now: { now },
            appState: appState,
            leave: { leaves += 1 }
        )

        await model.appear(partner: partner(named: "Anna", in: spaceId), reduceMotion: true)

        XCTAssertEqual(model.phase, .joined)
        XCTAssertNil(model.code)
        XCTAssertNil(model.countdown(at: now))
        XCTAssertTrue(minter.minted.isEmpty)
        XCTAssertNil(store.live(for: spaceId, at: now))
        XCTAssertEqual(appState.selectedTab, .today)
        XCTAssertEqual(leaves, 1)
    }

    @MainActor
    func testAPartnerWhoWasThereBeforeTheCodeDoesNotCountAsJoined() async {
        let now = Date()
        let spaceId = UUID()
        let store = LiveInviteStore(suiteName: suiteName)
        let minter = ScriptedMinter(codes: ["FYDW7C"], expiresAt: now.addingTimeInterval(15 * 60))
        let environment = AppEnvironment.preview()
        let appState = awayFromToday()
        var leaves = 0
        let anna = partner(named: "Anna", in: spaceId)

        let model = inviteModel(
            environment: environment,
            spaceId: spaceId,
            store: store,
            minter: minter,
            now: { now },
            appState: appState,
            leave: { leaves += 1 }
        )
        await model.appear(partner: anna, reduceMotion: true)
        await model.apply(partner: anna, reduceMotion: true)
        XCTAssertEqual(model.phase, .ready)
        XCTAssertEqual(model.code, "FYDW7C")

        let reopened = inviteModel(
            environment: environment,
            spaceId: spaceId,
            store: store,
            minter: minter,
            now: { now },
            appState: appState,
            leave: { leaves += 1 }
        )
        await reopened.appear(partner: anna, reduceMotion: true)
        XCTAssertEqual(reopened.phase, .ready)
        XCTAssertEqual(reopened.code, "FYDW7C")
        XCTAssertEqual(minter.minted, ["FYDW7C"])
        XCTAssertEqual(appState.selectedTab, .plans)
        XCTAssertEqual(leaves, 0)

        await reopened.apply(partner: partner(named: "Bo", in: spaceId), reduceMotion: true)
        XCTAssertEqual(reopened.phase, .joined)
        XCTAssertEqual(leaves, 1)
    }

    @MainActor
    func testAPartnerOfAnotherSpaceLeavesTheInviteAlone() async {
        let now = Date()
        let spaceId = UUID()
        let store = LiveInviteStore(suiteName: suiteName)
        let minter = ScriptedMinter(codes: ["FYDW7C"], expiresAt: now.addingTimeInterval(15 * 60))
        let appState = awayFromToday()
        var leaves = 0
        let model = inviteModel(
            environment: AppEnvironment.preview(),
            spaceId: spaceId,
            store: store,
            minter: minter,
            now: { now },
            appState: appState,
            leave: { leaves += 1 }
        )

        await model.appear(partner: nil, reduceMotion: true)
        await model.apply(partner: partner(named: "Anna", in: UUID()), reduceMotion: true)

        XCTAssertEqual(model.phase, .ready)
        XCTAssertEqual(model.code, "FYDW7C")
        XCTAssertEqual(store.live(for: spaceId, at: now)?.code, "FYDW7C")
        XCTAssertEqual(appState.selectedTab, .plans)
        XCTAssertEqual(leaves, 0)
    }

    @MainActor
    func testACodeStillBeingMadeIsDroppedWhenThePartnerJoins() async {
        let now = Date()
        let spaceId = UUID()
        let store = LiveInviteStore(suiteName: suiteName)
        let minter = HeldMinter(code: "FYDW7C", expiresAt: now.addingTimeInterval(15 * 60))
        var leaves = 0
        let model = inviteModel(
            environment: AppEnvironment.preview(),
            spaceId: spaceId,
            store: store,
            minter: minter,
            now: { now },
            leave: { leaves += 1 }
        )

        let appearing = Task { await model.appear(partner: nil, reduceMotion: true) }
        for _ in 0 ..< 100 where minter.isHolding == false {
            await Task.yield()
        }
        XCTAssertEqual(model.phase, .working)

        await model.apply(partner: partner(named: "Anna", in: spaceId), reduceMotion: true)
        minter.release()
        await appearing.value

        XCTAssertEqual(model.phase, .joined)
        XCTAssertNil(model.code)
        XCTAssertNil(store.live(for: spaceId, at: now))
        XCTAssertEqual(leaves, 1)
    }

    @MainActor
    func testTheJoinedLineNamesThePartnerOrFallsBack() {
        let named = InviteViewModel.joinedLine(name: "Anna")
        XCTAssertTrue(named.contains("Anna"))
        XCTAssertFalse(named.hasPrefix("pairing."))

        let fallback = InviteViewModel.joinedLine(name: nil)
        XCTAssertFalse(fallback.isEmpty)
        XCTAssertFalse(fallback.hasPrefix("pairing."))
        XCTAssertFalse(fallback.contains("%@"))
        XCTAssertEqual(InviteViewModel.joinedLine(name: ""), fallback)
        XCTAssertEqual(InviteViewModel.joinedLine(name: "  "), fallback)
    }

    func testEveryJoinStepHasItsOwnLineAndLogName() {
        let steps = JoinViewModel.Step.allCases
        XCTAssertEqual(steps.count, 6)
        XCTAssertEqual(Set(steps.map(\.title)).count, steps.count)
        XCTAssertEqual(Set(steps.map(\.logName)).count, steps.count)
        for step in steps {
            XCTAssertFalse(step.title.hasPrefix("pairing."), "\(step) shows a raw key")
            XCTAssertTrue(step.logName.hasPrefix("join: "))
        }
    }

    func testStepDurationsAreLoggedInWholeMilliseconds() {
        XCTAssertEqual(PairingStepLog.milliseconds(.milliseconds(1234)), 1234)
        XCTAssertEqual(PairingStepLog.milliseconds(.seconds(40) + .microseconds(999)), 40000)
        XCTAssertEqual(PairingStepLog.milliseconds(.zero), 0)
    }

    func testSessionExchangeSeparatesAuthFromNetworkFailures() {
        XCTAssertEqual(SessionService.failure(status: 401, body: Data()), .auth("status 401"))
        XCTAssertEqual(SessionService.failure(status: 500, body: Data()), .network("status 500"))

        let envelope = Data(#"{"error":"unauthorized","message":"token expired"}"#.utf8)
        XCTAssertEqual(SessionService.failure(status: 403, body: envelope), .auth("token expired"))
    }

    func testSessionRequestCarriesTheAuthorizationCodeOnlyWhenThereIsOne() throws {
        let withCode = try SessionService.body(authorizationCode: "code-1")
        XCTAssertEqual(try JSONSerialization.jsonObject(with: withCode) as? [String: String], ["authorizationCode": "code-1"])
        for missing in [nil, ""] {
            let body = try SessionService.body(authorizationCode: missing)
            XCTAssertEqual(String(data: body, encoding: .utf8), "{}")
        }
    }

    func testSessionResponseMayCarryTheAppleRefreshToken() throws {
        let decoder = CorbieJSON.decoder
        let withToken = Data(#"{"token":"jwt","expiresAt":"2027-03-04T10:00:00Z","appleRefreshToken":"refresh-1"}"#.utf8)
        XCTAssertEqual(try decoder.decode(SessionService.Token.self, from: withToken).appleRefreshToken, "refresh-1")
        let without = Data(#"{"token":"jwt","expiresAt":"2027-03-04T10:00:00Z"}"#.utf8)
        let token = try decoder.decode(SessionService.Token.self, from: without)
        XCTAssertEqual(token.token, "jwt")
        XCTAssertNil(token.appleRefreshToken)
    }

    override func tearDown() {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private let suiteName = "app.corbie.tests.pairing"

    private func serverError(status: Int, code: String) -> APIError {
        APIError(
            kind: .server,
            status: status,
            envelope: ServerErrorEnvelope(error: code, message: "server said \(code)"),
            detail: code
        )
    }

    @MainActor
    private func inviteModel(
        environment: AppEnvironment,
        spaceId: UUID,
        store: LiveInviteStore,
        minter: any InviteMinting,
        now: @escaping () -> Date,
        appState: AppState? = nil,
        leave: @escaping () -> Void = {}
    ) -> InviteViewModel {
        InviteViewModel(
            environment: environment,
            appState: appState ?? AppState(),
            spaceId: spaceId,
            store: store,
            minter: minter,
            now: now,
            leave: leave
        )
    }

    @MainActor
    private func awayFromToday() -> AppState {
        let appState = AppState()
        appState.selectedTab = .plans
        appState.isUsHubPresented = true
        return appState
    }

    private func partner(named name: String?, in spaceId: UUID) -> MemberDTO {
        MemberDTO(id: UUID(), spaceId: spaceId, displayName: name)
    }
}

private extension Locale {
    static let posix = Locale(identifier: "en_US_POSIX")
}

@MainActor
private final class ScriptedMinter: InviteMinting {
    private var codes: [String]
    private let expiresAt: Date
    private(set) var minted: [String] = []

    init(codes: [String], expiresAt: Date) {
        self.codes = codes
        self.expiresAt = expiresAt
    }

    func mint(spaceId: UUID) async throws -> InviteCode {
        guard codes.isEmpty == false else {
            throw CorbieError.network("no answer")
        }
        let code = codes.removeFirst()
        minted.append(code)
        return InviteCode(code: code, expiresAt: expiresAt)
    }
}

@MainActor
private final class HeldMinter: InviteMinting {
    private let invite: InviteCode
    private var held: CheckedContinuation<Void, Never>?

    init(code: String, expiresAt: Date) {
        invite = InviteCode(code: code, expiresAt: expiresAt)
    }

    var isHolding: Bool { held != nil }

    func mint(spaceId: UUID) async throws -> InviteCode {
        await withCheckedContinuation { held = $0 }
        return invite
    }

    func release() {
        held?.resume()
        held = nil
    }
}
