import CorbieCore
import Foundation

enum SettingsNotificationToggle: String, CaseIterable, Identifiable {
    case taskAssigned
    case taskHandover
    case taskDueToday
    case eventSoon
    case dateRadar
    case partnerWish
    case planUpdates
    case capsuleUpdates
    case voteUpdates
    case weeklyRecap
    case questionOfDay
    case choreSplit

    var id: String { rawValue }

    var titleKey: String { "settings.notifications." + rawValue.lowercased() }

    var keyPath: WritableKeyPath<NotificationPrefs, Bool> {
        switch self {
        case .taskAssigned: return \.taskAssigned
        case .taskHandover: return \.taskTakenOrHandedBack
        case .taskDueToday: return \.taskDueToday
        case .eventSoon: return \.eventSoon
        case .dateRadar: return \.dateRadar
        case .partnerWish: return \.partnerAddedWish
        case .planUpdates: return \.planUpdates
        case .capsuleUpdates: return \.capsuleUpdates
        case .voteUpdates: return \.voteUpdates
        case .weeklyRecap: return \.weeklyRecap
        case .questionOfDay: return \.questionOfTheDay
        case .choreSplit: return \.choreSplitReady
        }
    }

    var scheduledKinds: [NotificationKind] {
        switch self {
        case .taskDueToday: return [.taskDueToday]
        case .eventSoon: return [.eventReminder, .eventDigest]
        case .dateRadar: return [.dateRadar]
        case .capsuleUpdates: return [.capsuleOpens]
        case .weeklyRecap: return [.weeklyRecap]
        case .questionOfDay: return [.questionOfTheDay]
        case .choreSplit: return [.choreSplitReady]
        case .taskAssigned, .taskHandover, .partnerWish, .planUpdates, .voteUpdates: return []
        }
    }

    func isOn(in prefs: NotificationPrefs) -> Bool { prefs[keyPath: keyPath] }

    func set(_ isOn: Bool, in prefs: NotificationPrefs) -> NotificationPrefs {
        var updated = prefs
        updated[keyPath: keyPath] = isOn
        return updated
    }
}
