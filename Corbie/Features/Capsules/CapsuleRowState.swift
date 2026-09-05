import CorbieCore
import Foundation

enum CapsuleRowState: Equatable, CaseIterable {
    case waiting
    case ready
    case sealed
    case opened

    static func make(capsule: CapsuleDTO, viewerMemberId: UUID?, now: Date) -> CapsuleRowState {
        guard capsule.isUnlocked(at: now) else {
            if let viewerMemberId, capsule.authorMemberId == viewerMemberId { return .sealed }
            return .waiting
        }
        if let viewerMemberId, capsule.openedByMemberIds.contains(viewerMemberId) { return .opened }
        return .ready
    }

    var systemImage: String {
        switch self {
        case .waiting: return "envelope.badge"
        case .ready: return "envelope.open"
        case .sealed: return "lock"
        case .opened: return "envelope.open"
        }
    }

    var isHighlighted: Bool {
        self == .waiting || self == .ready
    }

    var isEditable: Bool {
        self == .sealed
    }

    var isReadable: Bool {
        self == .ready || self == .opened
    }

    var section: CapsuleSection {
        switch self {
        case .ready: return .toOpen
        case .waiting, .sealed: return .coming
        case .opened: return .opened
        }
    }
}

enum CapsuleSection: Int, Equatable, CaseIterable, Identifiable {
    case toOpen
    case coming
    case opened

    var id: Int { rawValue }

    var titleKey: String.LocalizationValue {
        switch self {
        case .toOpen: return "capsules.section.toopen"
        case .coming: return "capsules.section.coming"
        case .opened: return "capsules.section.opened"
        }
    }
}
