import CorbieCore
import Foundation
import Observation

@MainActor
@Observable
final class JoinViewModel {
    enum Phase: Equatable {
        case editing
        case working
        case joined
    }

    enum Block: Equatable {
        case paired
        case content

        var message: String {
            switch self {
            case .paired: return String(localized: "pairing.join.blocked.paired")
            case .content: return String(localized: "pairing.join.blocked.content")
            }
        }
    }

    static let spaceArrivalAttempts = 30
    static let spaceArrivalDelay = Duration.milliseconds(500)

    var code = ""
    private(set) var phase: Phase = .editing
    private(set) var failure: String?
    private(set) var block: Block?

    @ObservationIgnored private let environment: AppEnvironment
    @ObservationIgnored private let appState: AppState
    @ObservationIgnored private let localSpace: SpaceDTO?
    @ObservationIgnored private let profile: ProfileDraft
    @ObservationIgnored private var redeemed: InviteShare?

    init(
        environment: AppEnvironment,
        appState: AppState,
        localSpace: SpaceDTO?,
        profile: ProfileDraft,
        code: String?
    ) {
        self.environment = environment
        self.appState = appState
        self.localSpace = localSpace
        self.profile = profile
        self.code = InviteCodeFormat.sanitize(code ?? "")
    }

    var isWorking: Bool { phase == .working }

    var canSubmit: Bool { InviteCodeFormat.isComplete(code) && phase == .editing && block == nil }

    func normalizeCode() {
        let sanitized = InviteCodeFormat.sanitize(code)
        if sanitized != code {
            code = sanitized
        }
        failure = nil
    }

    func submit() async {
        guard canSubmit else { return }
        phase = .working
        failure = nil
        do {
            try await join()
            phase = .joined
        } catch {
            phase = .editing
            guard block == nil else { return }
            failure = JoinFailure.kind(for: error).message
        }
    }

    private func join() async throws {
        guard let appleUserID = environment.identity.currentAppleUserID else {
            throw CorbieError.auth("no apple user id is stored")
        }
        if let reason = await blockingReason() {
            block = reason
            throw CorbieError.invalidInput("local space cannot be replaced")
        }
        let share = try await redeemedShare()
        guard let url = share.shareLink else {
            throw CorbieError.cloudKit("the invite has no share link")
        }
        let metadata = try await environment.sharing.fetchShareMetadata(from: url)
        try await environment.sharing.acceptShare(metadata: metadata)
        let joined = try await waitForJoinedSpace(id: share.spaceId)
        try await dropLocalSpace(joinedId: joined.id)
        try await adoptMember(appleUserID: appleUserID, in: joined)
        try await carryTogetherSince(into: joined)
        environment.analytics.record(.inviteRedeemed)
        appState.selectedTab = .today
        await environment.reloadSession()
        environment.toasts.show(message: String(localized: "pairing.join.connected"))
    }

    private func blockingReason() async -> Block? {
        guard let localSpace else { return nil }
        if localSpace.memberCount >= 2 { return .paired }
        let probe = SpaceContentProbe(repositories: environment.repositories)
        return await probe.holdsContent(spaceId: localSpace.id) ? .content : nil
    }

    private func redeemedShare() async throws -> InviteShare {
        if let redeemed { return redeemed }
        let share = try await environment.apiClient.redeemInvite(code: code)
        redeemed = share
        return share
    }

    private func waitForJoinedSpace(id: UUID) async throws -> SpaceDTO {
        for attempt in 0 ..< JoinViewModel.spaceArrivalAttempts {
            if let space = try? await environment.repositories.spaces.space(id: id) {
                return space
            }
            if attempt + 1 < JoinViewModel.spaceArrivalAttempts {
                try await Task.sleep(for: JoinViewModel.spaceArrivalDelay)
            }
        }
        throw CorbieError.cloudKit("the shared space did not arrive in time")
    }

    private func dropLocalSpace(joinedId: UUID) async throws {
        guard let localSpace, localSpace.id != joinedId else { return }
        do {
            try await environment.sharing.deleteSpace(space: localSpace.id)
        } catch {
            try await environment.repositories.spaces.delete(id: localSpace.id)
        }
    }

    private func adoptMember(appleUserID: String, in space: SpaceDTO) async throws {
        if let existing = try await environment.repositories.members.member(appleUserId: appleUserID),
           existing.spaceId != space.id {
            try await environment.repositories.members.delete(id: existing.id)
        }
        let saved = try await environment.repositories.members.upsertCurrentMember(
            appleUserId: appleUserID,
            spaceId: space.id,
            draft: profile.memberDraft,
            theme: environment.theme.settings.theme
        )
        if let shifted = saved.shiftedColorFrom {
            environment.toasts.show(
                message: String(
                    format: String(localized: "settings.you.color.shifted"),
                    String(localized: String.LocalizationValue(shifted.displayNameKey)),
                    String(localized: String.LocalizationValue(saved.member.colorSlot.displayNameKey))
                )
            )
        }
    }

    private func carryTogetherSince(into space: SpaceDTO) async throws {
        guard let togetherSince = profile.togetherSince, space.togetherSince == nil else { return }
        var updated = space
        updated.togetherSince = togetherSince
        _ = try await environment.repositories.spaces.update(updated)
    }
}
