import CorbieCore
import Foundation
import Observation
import os

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

    enum Step: Equatable, CaseIterable {
        case checkingCode
        case findingInvite
        case accepting
        case waitingForSpace
        case savingYou
        case waitingForUpload

        var title: String {
            switch self {
            case .checkingCode: return String(localized: "pairing.join.step.code")
            case .findingInvite: return String(localized: "pairing.join.step.invite")
            case .accepting: return String(localized: "pairing.join.step.accept")
            case .waitingForSpace: return String(localized: "pairing.join.step.space")
            case .savingYou: return String(localized: "pairing.join.step.member")
            case .waitingForUpload: return String(localized: "pairing.join.step.upload")
            }
        }

        var logName: String {
            switch self {
            case .checkingCode: return "join: redeem the code"
            case .findingInvite: return "join: fetch share metadata"
            case .accepting: return "join: accept share"
            case .waitingForSpace: return "join: wait for the space"
            case .savingYou: return "join: save the member"
            case .waitingForUpload: return "join: wait for the member upload"
            }
        }
    }

    static let spaceArrivalAttempts = 30
    static let spaceArrivalDelay = Duration.milliseconds(500)
    static let memberUploadTimeout = Duration.seconds(20)

    private nonisolated static let log = Logger(subsystem: CorbieIdentifiers.bundleID, category: "pairing")

    var code = ""
    private(set) var phase: Phase = .editing
    private(set) var failure: String?
    private(set) var block: Block?
    private(set) var step: Step?

    @ObservationIgnored private let environment: AppEnvironment
    @ObservationIgnored private let appState: AppState
    @ObservationIgnored private let localSpace: SpaceDTO?
    @ObservationIgnored private let profile: ProfileDraft
    @ObservationIgnored private let redemption: InviteRedemption

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
        redemption = InviteRedemption { code in
            let origin = await environment.sharing.inviteOrigin()
            return try await environment.apiClient.redeemInvite(code: code, origin: origin)
        }
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
            step = nil
            phase = .joined
        } catch {
            step = nil
            phase = .editing
            guard block == nil else { return }
            let kind = PairingFailure.kind(for: error, side: .joining)
            failure = PairingFailure.message(for: error, side: .joining)
            JoinViewModel.log.error(
                """
                join failed as \(kind.rawValue, privacy: .public): \
                \((error as? LocalizedError)?.failureReason ?? error.localizedDescription, privacy: .public)
                """
            )
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
        try await requireICloud()
        let share = try await run(.checkingCode) {
            try await redemption.share(for: code)
        }
        guard let url = share.shareLink else {
            throw PairingFailure.shareMissing
        }
        JoinViewModel.log.notice("join: redeemed a link to space \(share.spaceId, privacy: .public)")
        let metadata = try await run(.findingInvite) {
            try await environment.sharing.fetchShareMetadata(from: url)
        }
        let isOwnShare = await PairingStepLog.measure("join: check the share owner") {
            await environment.sharing.isOwnShare(metadata)
        }
        guard isOwnShare == false else {
            throw PairingFailure.ownAccount
        }
        try await run(.accepting) {
            try await environment.sharing.acceptShare(metadata: metadata)
        }
        let joined = try await run(.waitingForSpace) {
            try await waitForJoinedSpace(id: share.spaceId)
        }
        try await PairingStepLog.measure("join: drop the local space") {
            try await dropLocalSpace(joinedId: joined.id)
        }
        let upload = environment.persistence.stack.watchUpload(of: .sharedStore)
        try await run(.savingYou) {
            try await adoptMember(appleUserID: appleUserID, in: joined)
            try await carryTogetherSince(into: joined)
        }
        environment.analytics.record(.inviteRedeemed)
        appState.selectedTab = .today
        await PairingStepLog.measure("join: reload the session") {
            await environment.reloadSession()
        }
        let uploaded = await run(.waitingForUpload) {
            await upload.finished(within: JoinViewModel.memberUploadTimeout)
        }
        JoinViewModel.log.notice("join: member upload \(uploaded ? "finished" : "not confirmed", privacy: .public)")
        environment.toasts.show(
            message: uploaded
                ? String(localized: "pairing.join.connected")
                : String(localized: "pairing.join.connected.pending")
        )
    }

    private func requireICloud() async throws {
        switch await environment.sharing.iCloudAccount() {
        case .available, .unknown: return
        case .missing: throw PairingFailure.signedOutOfICloud
        case .busy: throw PairingFailure.iCloudBusy
        }
    }

    private func run<T>(_ step: Step, _ work: () async throws -> T) async rethrows -> T {
        self.step = step
        return try await PairingStepLog.measure(step.logName, work)
    }

    private func blockingReason() async -> Block? {
        guard let localSpace else { return nil }
        if localSpace.memberCount >= 2 { return .paired }
        let probe = SpaceContentProbe(repositories: environment.repositories)
        return await probe.holdsContent(spaceId: localSpace.id) ? .content : nil
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
        throw PairingFailure.spaceLate
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
            theme: environment.theme.activeTheme
        )
        environment.showColorShift(saved)
    }

    private func carryTogetherSince(into space: SpaceDTO) async throws {
        guard let togetherSince = profile.togetherSince, space.togetherSince == nil else { return }
        _ = try await environment.repositories.spaces.setTogetherSinceIfUnset(spaceId: space.id, togetherSince)
    }
}

@MainActor
final class InviteRedemption {
    private let redeem: (String) async throws -> InviteShare
    private var redeemed: (code: String, share: InviteShare)?

    init(redeem: @escaping (String) async throws -> InviteShare) {
        self.redeem = redeem
    }

    func share(for code: String) async throws -> InviteShare {
        if let redeemed, redeemed.code == code { return redeemed.share }
        let share = try await redeem(code)
        redeemed = (code, share)
        return share
    }
}
