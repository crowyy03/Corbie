import CorbieCore
import Foundation
import Observation

@MainActor
@Observable
final class CapsuleEditorViewModel {
    var title: String
    var letter: String
    var opensAt: Date
    private(set) var isSaving = false
    private(set) var didFinish = false

    let target: CapsuleEditorTarget

    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let now: Date
    @ObservationIgnored private var environment: AppEnvironment?

    init(target: CapsuleEditorTarget, now: Date = Date(), calendar: Calendar = .current) {
        self.target = target
        self.now = now
        self.calendar = calendar
        switch target {
        case .new:
            title = ""
            letter = ""
            opensAt = CapsuleEditorViewModel.earliestOpening(now: now, calendar: calendar)
        case let .existing(capsule):
            title = capsule.title
            letter = capsule.body
            opensAt = capsule.opensAt ?? CapsuleEditorViewModel.earliestOpening(now: now, calendar: calendar)
        }
    }

    var isExisting: Bool {
        if case .existing = target { return true }
        return false
    }

    var earliestOpening: Date {
        CapsuleEditorViewModel.earliestOpening(now: now, calendar: calendar)
    }

    var remainingCharacters: Int {
        CapsuleItem.maxBodyLength - letter.count
    }

    var canSave: Bool {
        isSaving == false
            && title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && remainingCharacters >= 0
    }

    func attach(_ environment: AppEnvironment) {
        self.environment = environment
    }

    func save() async {
        guard let environment, let space = environment.space, let member = environment.currentMember else { return }
        guard canSave else { return }
        isSaving = true
        defer { isSaving = false }
        let opening = openingDate()
        do {
            let saved: CapsuleDTO
            switch target {
            case .new:
                saved = try await environment.repositories.capsules.create(
                    CapsuleDraft(
                        spaceId: space.id,
                        authorMemberId: member.id,
                        recipientMemberId: environment.partner?.id,
                        title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                        body: letter,
                        opensAt: opening
                    )
                )
                environment.analytics.record(.capsuleCreated)
            case let .existing(capsule):
                var updated = capsule
                updated.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                updated.body = letter
                updated.opensAt = opening
                saved = try await environment.repositories.capsules.update(updated)
            }
            await schedule(saved, environment: environment, member: member)
            didFinish = true
        } catch {
            environment.report(error)
        }
    }

    func delete() async {
        guard let environment, case let .existing(capsule) = target else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await environment.repositories.capsules.delete(id: capsule.id)
            await environment.notifications.cancelCapsuleOpen(capsuleId: capsule.id)
            didFinish = true
        } catch {
            environment.report(error)
        }
    }

    private func openingDate() -> Date {
        let day = calendar.startOfDay(for: opensAt)
        let opening = calendar.date(
            bySettingHour: NotificationScheduler.capsuleOpenHour,
            minute: 0,
            second: 0,
            of: day
        ) ?? day
        return max(opening, earliestOpening)
    }

    private func schedule(_ capsule: CapsuleDTO, environment: AppEnvironment, member: MemberDTO) async {
        _ = try? await environment.notifications.requestAuthorizationIfNeeded()
        _ = try? await environment.notifications.scheduleCapsuleOpen(
            for: capsule,
            viewerMemberId: member.id,
            partnerName: environment.partnerName,
            prefs: member.notificationPrefs,
            now: now
        )
    }

    private static func earliestOpening(now: Date, calendar: Calendar) -> Date {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        return calendar.date(
            bySettingHour: NotificationScheduler.capsuleOpenHour,
            minute: 0,
            second: 0,
            of: tomorrow
        ) ?? tomorrow
    }
}
