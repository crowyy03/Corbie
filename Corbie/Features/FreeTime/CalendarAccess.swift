import EventKit
import Foundation

enum CalendarAccess: Equatable {
    case notDetermined
    case granted
    case denied

    static var current: CalendarAccess {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            return .granted
        case .notDetermined:
            return .notDetermined
        default:
            return .denied
        }
    }
}
