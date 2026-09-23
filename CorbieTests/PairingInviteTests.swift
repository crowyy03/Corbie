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
    func testOnboardingSkipsTheInviteStepWhenTheSpaceAlreadyHasTwoMembers() async throws {
        let persistence = PersistenceController.inMemory()
        let space = try await makeSpace(in: persistence)
        let me = try await addMember(appleUserId: "tests.me", named: "Ilya", slot: .teal, to: space, in: persistence)
        let partner = try await addMember(
            appleUserId: "tests.partner",
            named: "Anna",
            slot: .rose,
            to: space,
            in: persistence
        )
        let environment = AppEnvironment.preview(persistence: persistence, transport: OfflineTransport())
        let appState = awayFromToday()
        let model = OnboardingViewModel(environment: environment, appState: appState)

        await model.signIn(credential: appleCredential(userIdentifier: "tests.me"))
        XCTAssertEqual(model.step, .profile)

        await model.continueFromProfile()

        XCTAssertNotEqual(model.step, .invite)
        XCTAssertEqual(model.storedPartner?.id, partner.id)
        XCTAssertNil(LiveInviteStore().live(for: space.id, at: Date()))
        XCTAssertEqual(appState.selectedTab, .today)
        XCTAssertTrue(environment.isSignedIn)
        XCTAssertEqual(environment.currentMember?.id, me.id)
        XCTAssertEqual(environment.partner?.id, partner.id)
    }

    @MainActor
    func testOnboardingStillShowsTheInviteStepForASpaceOfOne() async throws {
        let persistence = PersistenceController.inMemory()
        let space = try await makeSpace(in: persistence)
        let me = try await addMember(appleUserId: "tests.me", named: "Ilya", slot: .teal, to: space, in: persistence)
        let environment = AppEnvironment.preview(persistence: persistence, transport: OfflineTransport())
        let appState = awayFromToday()
        let model = OnboardingViewModel(environment: environment, appState: appState)

        await model.signIn(credential: appleCredential(userIdentifier: "tests.me"))
        await model.continueFromProfile()

        XCTAssertEqual(model.step, .invite)
        XCTAssertNil(model.storedPartner)
        XCTAssertEqual(model.space?.id, space.id)
        XCTAssertEqual(model.member?.id, me.id)
        XCTAssertEqual(appState.selectedTab, .plans)
        XCTAssertFalse(environment.isSignedIn)
    }

    @MainActor
    func testBackingOutOfACodeAlsoSkipsTheInviteStepInAPairedSpace() async throws {
        let persistence = PersistenceController.inMemory()
        let space = try await makeSpace(in: persistence)
        _ = try await addMember(appleUserId: "tests.me", named: "Ilya", slot: .teal, to: space, in: persistence)
        let partner = try await addMember(
            appleUserId: "tests.partner",
            named: "Anna",
            slot: .rose,
            to: space,
            in: persistence
        )
        let environment = AppEnvironment.preview(persistence: persistence, transport: OfflineTransport())
        let appState = awayFromToday()
        let model = OnboardingViewModel(environment: environment, appState: appState)

        model.adopt(joinCode: "K7M2QX")
        await model.signIn(credential: appleCredential(userIdentifier: "tests.me"))
        await model.continueFromProfile()
        XCTAssertEqual(model.step, .join)

        await model.cancelJoin()

        XCTAssertNotEqual(model.step, .invite)
        XCTAssertNil(model.joinCode)
        XCTAssertEqual(model.storedPartner?.id, partner.id)
        XCTAssertNil(LiveInviteStore().live(for: space.id, at: Date()))
        XCTAssertEqual(appState.selectedTab, .today)
        XCTAssertTrue(environment.isSignedIn)
    }

    @MainActor
    func testThePartnerArrivingWhileOnboardingWaitsForICloudSkipsTheInviteStep() async throws {
        let persistence = PersistenceController.inMemory()
        let space = try await makeSpace(in: persistence)
        _ = try await addMember(appleUserId: "tests.me", named: "Ilya", slot: .teal, to: space, in: persistence)
        let onboarding = await signedInOnboarding(persistence: persistence)

        let continuing = Task { await onboarding.model.continueFromProfile() }
        try await until("the wait for iCloud") { onboarding.isWaitingForICloud }
        onboarding.clock.advance(by: .seconds(1))
        let partner = try await addMember(
            appleUserId: "tests.partner",
            named: "Anna",
            slot: .rose,
            to: space,
            in: persistence
        )
        persistence.stack.changes.post(StoreChange(origin: .elsewhere, entityNames: ["Member"]))
        await continuing.value

        XCTAssertEqual(onboarding.imports.watchedSpaceIds, [space.id])
        XCTAssertNotEqual(onboarding.model.step, .invite)
        XCTAssertEqual(onboarding.model.storedPartner?.id, partner.id)
        XCTAssertNil(LiveInviteStore().live(for: space.id, at: Date()))
        XCTAssertEqual(onboarding.appState.selectedTab, .today)
        XCTAssertTrue(onboarding.environment.isSignedIn)
        XCTAssertEqual(onboarding.environment.partner?.id, partner.id)
        XCTAssertEqual(onboarding.clock.sleeperCount, 0)
    }

    @MainActor
    func testOnboardingShowsTheInviteStepWhenNothingArrivesBeforeTheCeiling() async throws {
        let persistence = PersistenceController.inMemory()
        let space = try await makeSpace(in: persistence)
        _ = try await addMember(appleUserId: "tests.me", named: "Ilya", slot: .teal, to: space, in: persistence)
        let onboarding = await signedInOnboarding(persistence: persistence)

        let continuing = Task { await onboarding.model.continueFromProfile() }
        try await until("the wait for iCloud") { onboarding.isWaitingForICloud }
        onboarding.clock.advance(by: ICloudPartnerWait.ceiling - .milliseconds(1))
        try await until("the progress") { onboarding.model.step == .checkingICloud }
        onboarding.clock.advance(by: .milliseconds(1))
        await continuing.value

        XCTAssertEqual(onboarding.model.step, .invite)
        XCTAssertNil(onboarding.model.storedPartner)
        XCTAssertEqual(onboarding.clock.elapsed, ICloudPartnerWait.ceiling)
        XCTAssertEqual(onboarding.appState.selectedTab, .plans)
        XCTAssertFalse(onboarding.environment.isSignedIn)
    }

    @MainActor
    func testAFinishedImportWithoutThePartnerShowsTheInviteStepBeforeTheCeiling() async throws {
        let persistence = PersistenceController.inMemory()
        let space = try await makeSpace(in: persistence)
        _ = try await addMember(appleUserId: "tests.me", named: "Ilya", slot: .teal, to: space, in: persistence)
        let onboarding = await signedInOnboarding(persistence: persistence)

        let continuing = Task { await onboarding.model.continueFromProfile() }
        try await until("the wait for iCloud") { onboarding.isWaitingForICloud }
        onboarding.clock.advance(by: .milliseconds(200))
        XCTAssertEqual(onboarding.model.step, .profile)
        onboarding.imports.watch.finish(.finished)
        await continuing.value

        XCTAssertEqual(onboarding.model.step, .invite)
        XCTAssertNil(onboarding.model.storedPartner)
        XCTAssertEqual(onboarding.clock.elapsed, .milliseconds(200))
        XCTAssertEqual(onboarding.clock.sleeperCount, 0)
        onboarding.clock.advance(by: ICloudPartnerWait.ceiling)
        XCTAssertEqual(onboarding.model.step, .invite)
    }

    @MainActor
    func testASpaceMadeOnThisPhoneDuringOnboardingNeverWaitsForICloud() async throws {
        let persistence = PersistenceController.inMemory()
        let onboarding = await signedInOnboarding(persistence: persistence)
        XCTAssertNotNil(onboarding.model.space)
        onboarding.model.profile.displayName = "Ilya"

        let continuing = Task { await onboarding.model.continueFromProfile() }
        try await until("the invite step") { onboarding.model.step == .invite }
        await continuing.value

        XCTAssertTrue(onboarding.imports.watchedSpaceIds.isEmpty)
        XCTAssertEqual(onboarding.imports.accountChecks, 0)
        XCTAssertEqual(onboarding.clock.elapsed, .zero)
        XCTAssertEqual(onboarding.clock.sleeperCount, 0)
    }

    @MainActor
    func testOnboardingDoesNotWaitWithoutMirroringOrAnICloudAccount() async throws {
        for account in [CloudKitSharing.ICloudAccount.missing, .busy] {
            let persistence = PersistenceController.inMemory()
            let space = try await makeSpace(in: persistence)
            _ = try await addMember(appleUserId: "tests.me", named: "Ilya", slot: .teal, to: space, in: persistence)
            let onboarding = await signedInOnboarding(persistence: persistence)
            onboarding.imports.account = account

            let continuing = Task { await onboarding.model.continueFromProfile() }
            try await until("the invite step") { onboarding.model.step == .invite }
            await continuing.value

            XCTAssertEqual(onboarding.imports.accountChecks, 1, "\(account)")
            XCTAssertEqual(onboarding.clock.elapsed, .zero, "\(account)")
            XCTAssertEqual(onboarding.clock.sleeperCount, 0, "\(account)")
        }

        let persistence = PersistenceController.inMemory()
        let space = try await makeSpace(in: persistence)
        _ = try await addMember(appleUserId: "tests.me", named: "Ilya", slot: .teal, to: space, in: persistence)
        let onboarding = await signedInOnboarding(persistence: persistence)
        onboarding.imports.isMirrored = false
        await onboarding.model.continueFromProfile()

        XCTAssertEqual(onboarding.model.step, .invite)
        XCTAssertTrue(onboarding.imports.watchedSpaceIds.isEmpty)
        XCTAssertEqual(onboarding.imports.accountChecks, 0)
    }

    @MainActor
    func testTheICloudProgressShowsOnlyWhileTheWaitRunsPastItsDelay() async throws {
        let persistence = PersistenceController.inMemory()
        let space = try await makeSpace(in: persistence)
        _ = try await addMember(appleUserId: "tests.me", named: "Ilya", slot: .teal, to: space, in: persistence)
        let onboarding = await signedInOnboarding(persistence: persistence)
        XCTAssertEqual(onboarding.model.step, .profile)

        let continuing = Task { await onboarding.model.continueFromProfile() }
        try await until("the wait for iCloud") { onboarding.isWaitingForICloud }
        onboarding.clock.advance(by: ICloudPartnerWait.progressDelay - .milliseconds(1))
        XCTAssertEqual(onboarding.model.step, .profile)

        onboarding.clock.advance(by: .milliseconds(1))
        try await until("the progress") { onboarding.model.step == .checkingICloud }

        onboarding.imports.watch.finish(.finished)
        await continuing.value
        XCTAssertEqual(onboarding.model.step, .invite)
        onboarding.clock.advance(by: ICloudPartnerWait.ceiling)
        XCTAssertEqual(onboarding.model.step, .invite)
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

    private func makeSpace(in persistence: PersistenceController) async throws -> SpaceDTO {
        try await persistence.repositories.spaces.create(
            displayCurrency: SupportedCurrencies.defaultCode,
            creatorMemberId: nil,
            now: Date()
        )
    }

    private func addMember(
        appleUserId: String,
        named name: String,
        slot: MemberColorSlot,
        to space: SpaceDTO,
        in persistence: PersistenceController
    ) async throws -> MemberDTO {
        try await persistence.repositories.members.upsertCurrentMember(
            appleUserId: appleUserId,
            spaceId: space.id,
            draft: MemberDraft(displayName: name, colorKey: slot.rawValue),
            theme: .sand
        ).member
    }

    @MainActor
    private func signedInOnboarding(persistence: PersistenceController) async -> WaitingOnboarding {
        let environment = AppEnvironment.preview(persistence: persistence, transport: OfflineTransport())
        let appState = awayFromToday()
        let imports = ScriptedImports()
        let clock = ManualClock()
        let model = OnboardingViewModel(
            environment: environment,
            appState: appState,
            partnerWait: ICloudPartnerWait(imports: imports, clock: clock)
        )
        await model.signIn(credential: appleCredential(userIdentifier: "tests.me"))
        return WaitingOnboarding(model: model, environment: environment, appState: appState, imports: imports, clock: clock)
    }

    @MainActor
    private func until(_ what: String, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(5)
        while condition() == false {
            guard Date() < deadline else {
                XCTFail("gave up waiting for \(what)")
                throw CancellationError()
            }
            try await Task.sleep(for: .milliseconds(5))
        }
    }

    private func appleCredential(userIdentifier: String) -> AppleSignInCredential {
        AppleSignInCredential(
            userIdentifier: userIdentifier,
            identityToken: nil,
            authorizationCode: nil,
            displayName: nil
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

private struct OfflineTransport: HTTPTransport {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        throw URLError(.notConnectedToInternet)
    }
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

@MainActor
private struct WaitingOnboarding {
    let model: OnboardingViewModel
    let environment: AppEnvironment
    let appState: AppState
    let imports: ScriptedImports
    let clock: ManualClock

    var isWaitingForICloud: Bool {
        imports.watch.isWaiting && clock.sleeperCount == 2
    }
}

@MainActor
private final class ScriptedImports: SpaceImportWatching {
    var isMirrored = true
    var account: CloudKitSharing.ICloudAccount = .available
    let watch = HeldImport()
    private(set) var watchedSpaceIds: [UUID] = []
    private(set) var accountChecks = 0

    func iCloudAccount() async -> CloudKitSharing.ICloudAccount {
        accountChecks += 1
        return account
    }

    func watchImport(intoStoreHolding spaceId: UUID) async -> (any SpaceImportWatch)? {
        watchedSpaceIds.append(spaceId)
        return watch
    }
}

private final class HeldImport: SpaceImportWatch, @unchecked Sendable {
    private let lock = NSLock()
    private var result: CloudKitSyncOutcome?
    private var waiter: CheckedContinuation<CloudKitSyncOutcome, Never>?

    var isWaiting: Bool { lock.withLock { waiter != nil } }

    func outcome(within timeout: Duration) async -> CloudKitSyncOutcome {
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                let settled: CloudKitSyncOutcome? = lock.withLock {
                    if let result { return result }
                    if Task.isCancelled { return .timedOut }
                    waiter = continuation
                    return nil
                }
                if let settled {
                    continuation.resume(returning: settled)
                }
            }
        } onCancel: {
            finish(.timedOut)
        }
    }

    func finish(_ outcome: CloudKitSyncOutcome) {
        let waiting: CheckedContinuation<CloudKitSyncOutcome, Never>? = lock.withLock {
            guard result == nil else { return nil }
            result = outcome
            defer { waiter = nil }
            return waiter
        }
        waiting?.resume(returning: outcome)
    }
}

private final class ManualClock: Clock, @unchecked Sendable {
    struct Instant: InstantProtocol {
        var offset: Duration

        func advanced(by duration: Duration) -> Instant {
            Instant(offset: offset + duration)
        }

        func duration(to other: Instant) -> Duration {
            other.offset - offset
        }

        static func < (lhs: Instant, rhs: Instant) -> Bool {
            lhs.offset < rhs.offset
        }
    }

    private struct Sleeper {
        let deadline: Instant
        let continuation: CheckedContinuation<Void, any Error>
    }

    private let lock = NSLock()
    private var current = Instant(offset: .zero)
    private var sleepers: [UUID: Sleeper] = [:]

    var now: Instant { lock.withLock { current } }

    var minimumResolution: Duration { .zero }

    var elapsed: Duration { now.offset }

    var sleeperCount: Int { lock.withLock { sleepers.count } }

    func sleep(until deadline: Instant, tolerance: Duration?) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                let early: Result<Void, any Error>? = lock.withLock {
                    if Task.isCancelled { return .failure(CancellationError()) }
                    if deadline <= current { return .success(()) }
                    sleepers[id] = Sleeper(deadline: deadline, continuation: continuation)
                    return nil
                }
                if let early {
                    continuation.resume(with: early)
                }
            }
        } onCancel: {
            let cancelled = lock.withLock { sleepers.removeValue(forKey: id) }
            cancelled?.continuation.resume(throwing: CancellationError())
        }
    }

    func advance(by duration: Duration) {
        let due: [Sleeper] = lock.withLock {
            current = current.advanced(by: duration)
            let due = sleepers.filter { $0.value.deadline <= current }
            for id in due.keys {
                sleepers[id] = nil
            }
            return Array(due.values)
        }
        for sleeper in due {
            sleeper.continuation.resume()
        }
    }
}
