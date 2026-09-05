import CorbieCore
import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    var profile = ProfileDraft()
    var weddingDate: Date?
    var displayCurrency = "USD"
    var currencies: [String] = []
    var exportURL: URL?
    var isWorking = false
    var isLeaving = false
    var isDeleting = false

    private var environment: AppEnvironment?
    private var savedProfile = ProfileDraft()
    private var savedWedding: Date?

    var member: MemberDTO? { environment?.currentMember }
    var partner: MemberDTO? { environment?.partner }
    var space: SpaceDTO? { environment?.space }
    var isPaired: Bool { environment?.isPaired ?? false }

    var isProfileDirty: Bool { profile != savedProfile || weddingDate != savedWedding }

    var canSaveProfile: Bool { isProfileDirty && profile.isComplete && isWorking == false }

    var partnerName: String {
        partner?.displayName ?? String(localized: "member.name.partner")
    }

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
        currencies = environment.fx.supportedCurrencies()
        reloadFromSession()
    }

    func reloadFromSession() {
        guard let environment else { return }
        profile = ProfileDraft.from(
            member: environment.currentMember,
            space: environment.space,
            appleName: nil
        )
        weddingDate = environment.space?.weddingDate
        displayCurrency = environment.space?.displayCurrency ?? "USD"
        if currencies.contains(displayCurrency) == false {
            currencies.insert(displayCurrency, at: 0)
        }
        savedProfile = profile
        savedWedding = weddingDate
    }

    func saveProfile() async {
        guard let environment, let member = environment.currentMember, canSaveProfile else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let updated = try await environment.repositories.members.update(profile.applied(to: member))
            environment.apply(member: updated)
            if let space = environment.space {
                var changed = profile.applied(to: space)
                changed.weddingDate = weddingDate
                environment.apply(space: try await environment.repositories.spaces.update(changed))
            }
            savedProfile = profile
            savedWedding = weddingDate
        } catch {
            environment.report(error)
        }
    }

    func setCurrency(_ code: String) async {
        guard let environment, var space = environment.space, space.displayCurrency != code else { return }
        displayCurrency = code
        space.displayCurrency = code
        do {
            environment.apply(space: try await environment.repositories.spaces.update(space))
        } catch {
            displayCurrency = environment.space?.displayCurrency ?? code
            environment.report(error)
        }
    }

    func restorePurchases() async {
        guard let environment else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await environment.store.restore()
            await environment.refreshEntitlement()
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
        guard let environment, let space = environment.space else { return }
        isLeaving = true
        defer { isLeaving = false }
        do {
            try await environment.sharing.leave(space: space.id)
            await environment.notifications.cancelEverything()
            await environment.reloadSession()
        } catch {
            environment.report(error)
        }
    }

    func deleteAccount() async {
        guard let environment, let space = environment.space else { return }
        isDeleting = true
        defer { isDeleting = false }
        let plan = SettingsAccountPlan.decide(space: space, memberId: environment.currentMember?.id)
        do {
            switch plan {
            case .deleteSpace:
                try await environment.sharing.deleteSpace(space: space.id)
            case .leaveSpace:
                try await environment.sharing.leave(space: space.id)
            }
        } catch {
            environment.report(error)
        }
        await revokeApple(environment)
        await environment.wipeLocalState()
    }

    private func revokeApple(_ environment: AppEnvironment) async {
        let secret = environment.appleRevocationSecret()
        guard secret.authorizationCode != nil || secret.refreshToken != nil else { return }
        do {
            try await environment.apiClient.revokeAppleAccount(
                authorizationCode: secret.authorizationCode,
                refreshToken: secret.refreshToken
            )
        } catch {
            environment.report(error)
        }
    }
}
