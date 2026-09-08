import CorbieCore
import Foundation
import Observation

enum OnboardingStepIndex {
    static let introPageCount = 3
    static let profile = 3
    static let invite = 4
}

private enum OnboardingFallback {
    static let currency = "USD"
}

@MainActor
@Observable
final class OnboardingViewModel {
    enum Step: Equatable {
        case intro
        case profile
        case invite
        case join
    }

    var page = 0
    var profile = ProfileDraft()
    private(set) var step: Step = .intro
    private(set) var isWorking = false
    private(set) var space: SpaceDTO?
    private(set) var member: MemberDTO?
    private(set) var joinCode: String?

    @ObservationIgnored private let environment: AppEnvironment
    @ObservationIgnored private let appState: AppState
    @ObservationIgnored private var recordedSteps: Set<Int> = []

    init(environment: AppEnvironment, appState: AppState) {
        self.environment = environment
        self.appState = appState
    }

    var partnerSlot: MemberColorSlot? { environment.partner?.colorSlot }

    var partnerName: String { environment.partnerName }

    func adopt(joinCode raw: String?) {
        guard let raw, InviteCodeFormat.isComplete(raw) else { return }
        joinCode = InviteCodeFormat.sanitize(raw)
        if step == .invite {
            step = .join
        }
    }

    func recordStep(_ index: Int) {
        guard recordedSteps.insert(index).inserted else { return }
        environment.analytics.record(.onboardingStep(index))
    }

    func signIn(credential: AppleSignInCredential) async {
        guard isWorking == false else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try environment.storeAppleCredential(
                userIdentifier: credential.userIdentifier,
                identityToken: credential.identityToken,
                authorizationCode: credential.authorizationCode
            )
        } catch {
            environment.report(error)
            return
        }
        await exchangeSessionToken()
        do {
            try await loadProfile(appleName: credential.displayName)
            if joinCode == nil {
                try await ensureSpaceAndMember()
            }
        } catch {
            environment.report(error)
            return
        }
        recordStep(OnboardingStepIndex.profile)
        step = .profile
    }

    #if DEBUG
    func debugSignIn() async {
        guard isWorking == false else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try environment.storeAppleCredential(userIdentifier: "debug.simulator.user", identityToken: nil)
            try await loadProfile(appleName: "Debug")
            if joinCode == nil {
                try await ensureSpaceAndMember()
            }
        } catch {
            environment.report(error)
            return
        }
        recordStep(OnboardingStepIndex.profile)
        step = .profile
    }
    #endif

    func signInFailed(_ error: any Error) {
        guard AppleSignInCredential.isCancellation(error) == false else { return }
        environment.report(error)
    }

    func continueFromProfile() async {
        guard profile.isComplete, isWorking == false else { return }
        isWorking = true
        defer { isWorking = false }
        guard joinCode == nil else {
            step = .join
            return
        }
        do {
            try await saveProfile()
        } catch {
            environment.report(error)
            return
        }
        recordStep(OnboardingStepIndex.invite)
        step = .invite
    }

    func cancelJoin() async {
        guard isWorking == false else { return }
        isWorking = true
        defer { isWorking = false }
        joinCode = nil
        do {
            try await saveProfile()
        } catch {
            environment.report(error)
            return
        }
        recordStep(OnboardingStepIndex.invite)
        step = .invite
    }

    func openJoin() {
        step = .join
    }

    func finish() async {
        guard isWorking == false else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await saveProfile()
        } catch {
            environment.report(error)
        }
        appState.selectedTab = .today
        await environment.reloadSession()
    }

    private func exchangeSessionToken() async {
        guard environment.sessionService.isConfigured else { return }
        do {
            try await environment.exchangeSessionToken()
        } catch {
            environment.report(error)
        }
    }

    private func loadProfile(appleName: String?) async throws {
        let existingSpace = try await environment.repositories.spaces.currentSpace(memberId: nil)
        var existingMember: MemberDTO?
        if let appleUserID = environment.identity.currentAppleUserID {
            existingMember = try await environment.repositories.members.member(appleUserId: appleUserID)
        }
        space = existingSpace
        member = existingMember
        profile = ProfileDraft.from(member: existingMember, space: existingSpace, appleName: appleName)
    }

    private func ensureSpaceAndMember() async throws {
        guard space == nil || member == nil else { return }
        guard let appleUserID = environment.identity.currentAppleUserID else {
            throw CorbieError.auth("no apple user id is stored")
        }
        var known = space
        if known == nil {
            known = try await environment.repositories.spaces.currentSpace(memberId: nil)
        }
        let base: SpaceDTO
        if let known {
            base = known
        } else {
            base = try await makeSpace()
        }
        let saved = try await environment.repositories.members.upsertCurrentMember(
            appleUserId: appleUserID,
            spaceId: base.id,
            draft: profile.memberDraft,
            theme: environment.theme.activeTheme
        )
        environment.showColorShift(saved)
        let created = saved.member
        member = created
        profile.colorSlot = created.colorSlot
        if base.creatorMemberId == nil {
            var updated = base
            updated.creatorMemberId = created.id
            space = try await environment.repositories.spaces.update(updated)
        } else {
            space = base
        }
    }

    private func saveProfile() async throws {
        try await ensureSpaceAndMember()
        guard let member, let space else { return }
        let saved = try await environment.repositories.members.update(
            profile.applied(to: member),
            theme: environment.theme.activeTheme
        )
        environment.showColorShift(saved)
        self.member = saved.member
        profile.colorSlot = saved.member.colorSlot
        self.space = try await environment.repositories.spaces.update(profile.applied(to: space))
    }

    private func makeSpace() async throws -> SpaceDTO {
        let currency = Locale.current.currency?.identifier ?? OnboardingFallback.currency
        let created = try await environment.repositories.spaces.create(
            displayCurrency: currency,
            creatorMemberId: nil,
            now: Date()
        )
        environment.analytics.record(.spaceCreated)
        return created
    }
}
