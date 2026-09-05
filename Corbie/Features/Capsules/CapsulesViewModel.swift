import CorbieCore
import Foundation
import Observation

enum CapsuleEditorTarget: Identifiable, Equatable {
    case new
    case existing(CapsuleDTO)

    var id: String {
        switch self {
        case .new: return "new"
        case let .existing(capsule): return capsule.id.uuidString
        }
    }
}

enum CapsuleSheet: Identifiable, Equatable {
    case editor(CapsuleEditorTarget)
    case reading(CapsuleDTO)

    var id: String {
        switch self {
        case let .editor(target): return "editor." + target.id
        case let .reading(capsule): return "reading." + capsule.id.uuidString
        }
    }
}

@MainActor
@Observable
final class CapsulesViewModel {
    private(set) var capsules: [CapsuleDTO] = []
    private(set) var isLoading = true
    var sheet: CapsuleSheet?

    @ObservationIgnored private var environment: AppEnvironment?

    func load(_ environment: AppEnvironment) async {
        self.environment = environment
        defer { isLoading = false }
        guard let space = environment.space else {
            capsules = []
            return
        }
        do {
            capsules = try await environment.repositories.capsules.capsules(spaceId: space.id)
            await scheduleOpenings(environment)
        } catch {
            environment.report(error)
        }
    }

    func sections(now: Date = Date()) -> [(section: CapsuleSection, capsules: [CapsuleDTO])] {
        let viewerMemberId = environment?.currentMember?.id
        var grouped: [CapsuleSection: [CapsuleDTO]] = [:]
        for capsule in capsules {
            let section = CapsuleRowState.make(capsule: capsule, viewerMemberId: viewerMemberId, now: now).section
            grouped[section, default: []].append(capsule)
        }
        return CapsuleSection.allCases.compactMap { section in
            guard let items = grouped[section], items.isEmpty == false else { return nil }
            let sorted = section == .opened
                ? items.sorted { ($0.openedAt ?? .distantPast) > ($1.openedAt ?? .distantPast) }
                : items.sorted { ($0.opensAt ?? .distantFuture) < ($1.opensAt ?? .distantFuture) }
            return (section, sorted)
        }
    }

    func state(for capsule: CapsuleDTO, now: Date = Date()) -> CapsuleRowState {
        CapsuleRowState.make(capsule: capsule, viewerMemberId: environment?.currentMember?.id, now: now)
    }

    func startNew() {
        guard let environment, environment.premiumGate.require(.capsules) else { return }
        sheet = .editor(.new)
    }

    func select(_ capsule: CapsuleDTO, now: Date = Date()) {
        switch state(for: capsule, now: now) {
        case .sealed:
            guard let environment, environment.premiumGate.require(.capsules) else { return }
            sheet = .editor(.existing(capsule))
        case .ready, .opened:
            sheet = .reading(capsule)
        case .waiting:
            break
        }
    }

    func replace(_ capsule: CapsuleDTO) {
        guard let index = capsules.firstIndex(where: { $0.id == capsule.id }) else { return }
        capsules[index] = capsule
    }

    private func scheduleOpenings(_ environment: AppEnvironment, now: Date = Date()) async {
        guard let member = environment.currentMember else { return }
        for capsule in capsules where capsule.openedAt == nil {
            _ = try? await environment.notifications.scheduleCapsuleOpen(
                for: capsule,
                viewerMemberId: member.id,
                partnerName: environment.partnerName,
                prefs: member.notificationPrefs,
                now: now
            )
        }
    }
}
