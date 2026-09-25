import CorbieCore
import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    var profile = ProfileDraft()
    var weddingDate: Date?
    var displayCurrency = SupportedCurrencies.defaultCode
    let currencies = SupportedCurrencies.codes
    var exportURL: URL?
    var isWorking = false
    private(set) var isSavingName = false
    private(set) var isLeaving = false
    private(set) var isDeleting = false

    private var environment: AppEnvironment?
    private var savedName = ""
    @ObservationIgnored private var commits: Task<Void, Never>?
    @ObservationIgnored private var pendingCommits = 0

    var member: MemberDTO? { environment?.currentMember }
    var partner: MemberDTO? { environment?.partner }
    var space: SpaceDTO? { environment?.space }
    var offersLeaving: Bool { SettingsAccountPlan.offersLeaving(space: space, memberId: member?.id) }

    var isNameDirty: Bool { profile.trimmedName != savedName }

    var canSaveName: Bool { isNameDirty && profile.isComplete && isSavingName == false }

    var subscriptionStatus: SettingsSubscriptionStatus {
        SettingsSubscriptionStatus(state: environment?.premiumGate.state ?? .readOnly)
    }

    var versionLine: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return String.localizedStringWithFormat(String(localized: "settings.about.version"), version, build)
    }

    func attach(_ environment: AppEnvironment) {
        self.environment = environment
        reloadFromSession()
    }

    func reloadFromSession() {
        guard let environment else { return }
        let stored = ProfileDraft.from(member: environment.currentMember, space: environment.space, appleName: nil)
        let pendingName = isNameDirty ? profile.displayName : nil
        savedName = stored.trimmedName
        if pendingCommits == 0 {
            profile = stored
            weddingDate = environment.space?.weddingDate
            displayCurrency = environment.space?.displayCurrency ?? SupportedCurrencies.defaultCode
        }
        profile.displayName = pendingName ?? stored.displayName
    }

    func saveName() async {
        guard let environment, let member = environment.currentMember, canSaveName else { return }
        isSavingName = true
        defer { isSavingName = false }
        let name = profile.trimmedName
        do {
            let saved = try await environment.repositories.members.setDisplayName(memberId: member.id, name)
            savedName = name
            environment.apply(member: saved)
        } catch {
            environment.report(error)
        }
    }

    func setColor(_ slot: MemberColorSlot) {
        guard slot != profile.colorSlot else { return }
        profile.colorSlot = slot
        commit { environment in
            guard let member = environment.currentMember else { return }
            let saved = try await environment.repositories.members.setColor(
                memberId: member.id,
                colorKey: slot.rawValue,
                theme: environment.theme.activeTheme
            )
            environment.apply(member: saved.member)
            environment.showColorShift(saved)
        }
    }

    func setBirthday(from edited: ProfileDraft) {
        let month = edited.birthdayMonth
        let day = edited.birthdayDay
        guard month != profile.birthdayMonth || day != profile.birthdayDay else { return }
        profile.birthdayMonth = month
        profile.birthdayDay = day
        commit { environment in
            guard let member = environment.currentMember else { return }
            let saved = try await environment.repositories.members.setBirthday(memberId: member.id, month: month, day: day)
            environment.apply(member: saved)
        }
    }

    func setTogetherSince(_ date: Date?) {
        guard date != profile.togetherSince else { return }
        profile.togetherSince = date
        commit { environment in
            guard let space = environment.space else { return }
            environment.apply(space: try await environment.repositories.spaces.setTogetherSince(spaceId: space.id, date))
        }
    }

    func setWeddingDate(_ date: Date?) {
        guard date != weddingDate else { return }
        weddingDate = date
        commit { environment in
            guard let space = environment.space else { return }
            environment.apply(space: try await environment.repositories.spaces.setWeddingDate(spaceId: space.id, date))
        }
    }

    func setCurrency(_ code: String) {
        guard code != displayCurrency else { return }
        displayCurrency = code
        commit { environment in
            guard let space = environment.space else { return }
            environment.apply(space: try await environment.repositories.spaces.setDisplayCurrency(spaceId: space.id, code))
        }
    }

    var isRestoring: Bool {
        environment?.premiumGate.isRestoring ?? false
    }

    func restorePurchases() async {
        guard let environment else { return }
        let store = environment.store
        do {
            let outcome = try await environment.premiumGate.restore(spaceId: environment.space?.id) {
                try await store.restore()
            }
            guard let outcome else { return }
            environment.toasts.show(message: PaywallCopy.restoreText(outcome))
        } catch {
            environment.report(error)
        }
    }

    func exportData() async {
        guard let environment, let space = environment.space else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            exportURL = try await DataExport(controller: environment.persistence).write(spaceId: space.id)
        } catch {
            environment.report(error)
        }
    }

    func leaveSpace() async {
        guard let environment, let space = environment.space, let member = environment.currentMember else { return }
        guard mayChangeTheAccount(in: environment) else { return }
        isLeaving = true
        defer { isLeaving = false }
        await environment.withPartnerChecksPaused {
            do {
                try await environment.sharing.leave(space: space.id, memberId: member.id)
                await environment.notifications.cancelEverything()
                await environment.reloadSession()
            } catch {
                environment.report(error)
            }
        }
    }

    func deleteAccount() async {
        guard let environment, let space = environment.space, let member = environment.currentMember else { return }
        guard mayChangeTheAccount(in: environment) else { return }
        isDeleting = true
        defer { isDeleting = false }
        let accountPlan = SettingsAccountPlan.decide(space: space, memberId: member.id)
        await environment.withPartnerChecksPaused {
            if let failure = await deleteCloudKitData(
                accountPlan,
                spaceId: space.id,
                memberId: member.id,
                sharing: environment.sharing
            ) {
                environment.report(failure)
                return
            }
            await revokeApple(environment)
            await environment.wipeLocalState()
        }
    }

    private func mayChangeTheAccount(in environment: AppEnvironment) -> Bool {
        #if DEBUG
        if environment.isScreenshotMode {
            environment.report(ScreenshotModeRefusal.accountChange)
            return false
        }
        #endif
        return true
    }

    private func deleteCloudKitData(
        _ accountPlan: SettingsAccountPlan,
        spaceId: UUID,
        memberId: UUID,
        sharing: CloudKitSharing
    ) async -> (any Error)? {
        guard await sharing.isICloudAccountMissing() == false else { return nil }
        do {
            if accountPlan == .leaveSpace {
                try await sharing.leave(space: spaceId, memberId: memberId)
            }
            try await sharing.purgePrivateZones()
            return nil
        } catch {
            return error
        }
    }

    private func commit(_ write: @escaping @MainActor (AppEnvironment) async throws -> Void) {
        guard let environment else { return }
        pendingCommits += 1
        let previous = commits
        commits = Task { [weak self] in
            await previous?.value
            do {
                try await write(environment)
            } catch {
                environment.report(error)
            }
            self?.finishCommit()
        }
    }

    private func finishCommit() {
        pendingCommits -= 1
        guard pendingCommits == 0 else { return }
        reloadFromSession()
    }

    private func revokeApple(_ environment: AppEnvironment) async {
        guard let refreshToken = environment.appleRefreshToken() else { return }
        do {
            try await environment.apiClient.revokeAppleAccount(refreshToken: refreshToken)
        } catch {
            environment.report(error)
        }
    }
}
