import CorbieCore
import EventKit
import EventKitUI
import SwiftUI
import UIKit

struct SystemCalendarEventEditor: UIViewControllerRepresentable {
    static let fallbackDurationMinutes = 60

    let event: EventDTO
    let store: EKEventStore
    let onFinish: () -> Void

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let controller = EKEventEditViewController()
        controller.eventStore = store
        controller.event = systemEvent()
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    private func systemEvent() -> EKEvent {
        let systemEvent = EKEvent(eventStore: store)
        systemEvent.title = event.title
        systemEvent.isAllDay = event.isAllDay
        let start = event.startAt ?? Date()
        systemEvent.startDate = start
        systemEvent.endDate = event.endAt ?? Calendar.current.date(
            byAdding: .minute,
            value: Self.fallbackDurationMinutes,
            to: start
        ) ?? start
        systemEvent.notes = event.note
        systemEvent.location = event.locationName
        systemEvent.calendar = store.defaultCalendarForNewEvents
        return systemEvent
    }

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        private let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        func eventEditViewController(
            _ controller: EKEventEditViewController,
            didCompleteWith action: EKEventEditViewAction
        ) {
            onFinish()
        }
    }
}
