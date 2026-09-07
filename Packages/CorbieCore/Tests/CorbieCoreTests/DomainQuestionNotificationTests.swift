import Foundation
import Testing
@testable import CorbieCore

@Suite struct DomainQuestionNotificationTests {
    private let calendar = DomainClock.calendar(locale: "en_US", timeZone: "Europe/Berlin")

    private func scheduler(_ center: FakeNotificationCenter) -> NotificationScheduler {
        NotificationScheduler(client: center, calendar: calendar)
    }

    private func day(_ value: String) -> Date { DomainClock.date(value, in: calendar) }

    @Test func theMorningReminderWaitsUntilTheOtherOneHasAnswered() async throws {
        let center = FakeNotificationCenter()
        let request = try await scheduler(center).scheduleQuestionReminder(
            dayKey: "2026-09-07",
            on: day("2026-09-07 00:00"),
            partnerName: "Sofia",
            partnerAnswered: true,
            viewerAnswered: false,
            prefs: .allEnabled,
            now: day("2026-09-07 07:30")
        )
        let scheduled = try #require(request)
        #expect(scheduled.id == NotificationIdentifier.questionOfTheDay(dayKey: "2026-09-07"))
        #expect(DomainClock.text(scheduled.fireDate, in: calendar) == "2026-09-07 10:00")
        #expect(scheduled.content.bodyKey == NotificationStrings.questionBodyPartner)
        #expect(scheduled.content.arguments == ["Sofia"])
        #expect(await center.pendingIdentifiers().count == 1)
    }

    @Test func whenNeitherHasAnsweredThereIsOneEveningReminder() async throws {
        let center = FakeNotificationCenter()
        let request = try await scheduler(center).scheduleQuestionReminder(
            dayKey: "2026-09-07",
            on: day("2026-09-07 00:00"),
            partnerName: "Sofia",
            partnerAnswered: false,
            viewerAnswered: false,
            prefs: .allEnabled,
            now: day("2026-09-07 07:30")
        )
        let scheduled = try #require(request)
        #expect(DomainClock.text(scheduled.fireDate, in: calendar) == "2026-09-07 20:00")
        #expect(scheduled.content.bodyKey == NotificationStrings.questionBodyNeither)
    }

    @Test func onlyOneQuestionReminderIsEverPending() async throws {
        let center = FakeNotificationCenter()
        let engine = scheduler(center)
        _ = try await engine.scheduleQuestionReminder(
            dayKey: "2026-09-07",
            on: day("2026-09-07 00:00"),
            partnerName: "Sofia",
            partnerAnswered: false,
            viewerAnswered: false,
            prefs: .allEnabled,
            now: day("2026-09-07 07:30")
        )
        _ = try await engine.scheduleQuestionReminder(
            dayKey: "2026-09-07",
            on: day("2026-09-07 00:00"),
            partnerName: "Sofia",
            partnerAnswered: true,
            viewerAnswered: false,
            prefs: .allEnabled,
            now: day("2026-09-07 09:00")
        )
        let pending = await center.pendingIdentifiers()
        #expect(pending == [NotificationIdentifier.questionOfTheDay(dayKey: "2026-09-07")])
        let request = await center.request(id: NotificationIdentifier.questionOfTheDay(dayKey: "2026-09-07"))
        #expect(DomainClock.text(request?.fireDate ?? Date(), in: calendar) == "2026-09-07 10:00")
    }

    @Test func onceYouHaveAnsweredNothingIsScheduled() async throws {
        let center = FakeNotificationCenter()
        let request = try await scheduler(center).scheduleQuestionReminder(
            dayKey: "2026-09-07",
            on: day("2026-09-07 00:00"),
            partnerName: "Sofia",
            partnerAnswered: true,
            viewerAnswered: true,
            prefs: .allEnabled,
            now: day("2026-09-07 07:30")
        )
        #expect(request == nil)
        #expect(await center.pendingIdentifiers().isEmpty)
    }

    @Test func aSlotThatHasAlreadyPassedIsNotScheduled() async throws {
        let center = FakeNotificationCenter()
        let request = try await scheduler(center).scheduleQuestionReminder(
            dayKey: "2026-09-07",
            on: day("2026-09-07 00:00"),
            partnerName: "Sofia",
            partnerAnswered: true,
            viewerAnswered: false,
            prefs: .allEnabled,
            now: day("2026-09-07 11:00")
        )
        #expect(request == nil)
    }

    @Test func theReminderFollowsTheNotificationPreference() async throws {
        let center = FakeNotificationCenter()
        var prefs = NotificationPrefs.allEnabled
        prefs.questionOfTheDay = false
        let request = try await scheduler(center).scheduleQuestionReminder(
            dayKey: "2026-09-07",
            on: day("2026-09-07 00:00"),
            partnerName: "Sofia",
            partnerAnswered: true,
            viewerAnswered: false,
            prefs: prefs,
            now: day("2026-09-07 07:30")
        )
        #expect(request == nil)
    }

    @Test func theChoreAlertGoesOutAsSoonAsTheOtherOneCanRate() async throws {
        let center = FakeNotificationCenter()
        let setId = UUID()
        let request = try await scheduler(center).scheduleChoreSplitReady(
            setId: setId,
            partnerName: "Sofia",
            prefs: .allEnabled,
            now: day("2026-09-07 18:00")
        )
        let scheduled = try #require(request)
        #expect(scheduled.id == NotificationIdentifier.choreSplitReady(setId: setId))
        #expect(scheduled.isImmediate)
        #expect(scheduled.content.titleKey == NotificationStrings.choreReadyTitle)
        #expect(scheduled.content.arguments == ["Sofia"])
        #expect(scheduled.content.userInfo[NotificationPayload.routeKey] == CorbieRoute.us.urlString)

        await scheduler(center).cancelChoreSplitReady(setId: setId)
        #expect(await center.pendingIdentifiers().isEmpty)
    }

    @Test func theChoreAlertFollowsItsPreference() async throws {
        let center = FakeNotificationCenter()
        var prefs = NotificationPrefs.allEnabled
        prefs.choreSplitReady = false
        let request = try await scheduler(center).scheduleChoreSplitReady(
            setId: UUID(),
            partnerName: "Sofia",
            prefs: prefs,
            now: day("2026-09-07 18:00")
        )
        #expect(request == nil)
    }
}
