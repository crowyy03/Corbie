import Foundation
import Testing
@testable import CorbieCore

@Suite struct DomainFreeSlotEngineTests {
    private let utc = DomainClock.calendar()
    private let berlin = DomainClock.calendar(timeZone: "Europe/Berlin")
    private let english = Locale(identifier: "en_US")
    private let viewerId = UUID()
    private let partnerId = UUID()

    private var viewer: FreeSlotParticipant {
        FreeSlotParticipant(memberId: viewerId, sharesBusyTimes: true)
    }

    private var partner: FreeSlotParticipant {
        FreeSlotParticipant(memberId: partnerId, sharesBusyTimes: true)
    }

    private func busy(_ memberId: UUID, _ start: String, _ end: String, in calendar: Calendar) -> BusyRange {
        BusyRange(
            memberId: memberId,
            start: DomainClock.date(start, in: calendar),
            end: DomainClock.date(end, in: calendar)
        )
    }

    private func engine(
        calendar: Calendar,
        partnerTimeZone: String = "UTC",
        workingHours: WorkingHours = .standard
    ) -> FreeSlotEngine {
        FreeSlotEngine(
            calendar: calendar,
            workingHours: workingHours,
            partnerTimeZone: TimeZone(identifier: partnerTimeZone) ?? .gmt,
            locale: english
        )
    }

    private func slots(_ result: FreeSlotResult) -> [FreeSlot] {
        guard case let .slots(slots) = result else { return [] }
        return slots
    }

    @Test func adjacentBusyRangesLeaveNoGapBetweenThem() {
        let result = engine(calendar: utc).result(
            viewer: viewer,
            partner: partner,
            busyRanges: [
                busy(viewerId, "2026-09-10 14:00", "2026-09-10 15:00", in: utc),
                busy(partnerId, "2026-09-10 15:00", "2026-09-10 16:00", in: utc)
            ],
            from: DomainClock.date("2026-09-10", in: utc),
            to: DomainClock.date("2026-09-11", in: utc)
        )
        let free = slots(result)
        #expect(free.count == 2)
        #expect(DomainClock.text(free[0].start, in: utc) == "2026-09-10 08:00")
        #expect(DomainClock.text(free[0].end, in: utc) == "2026-09-10 14:00")
        #expect(DomainClock.text(free[1].start, in: utc) == "2026-09-10 16:00")
        #expect(DomainClock.text(free[1].end, in: utc) == "2026-09-10 23:00")
        #expect(free.allSatisfy { $0.isAllDay == false })
    }

    @Test func overlappingRangesOfBothMembersCollapseIntoOneBlock() {
        let result = engine(calendar: utc).result(
            viewer: viewer,
            partner: partner,
            busyRanges: [
                busy(viewerId, "2026-09-10 10:00", "2026-09-10 12:00", in: utc),
                busy(viewerId, "2026-09-10 11:00", "2026-09-10 13:00", in: utc),
                busy(partnerId, "2026-09-10 12:30", "2026-09-10 14:00", in: utc)
            ],
            from: DomainClock.date("2026-09-10", in: utc),
            to: DomainClock.date("2026-09-11", in: utc)
        )
        let free = slots(result)
        #expect(free.count == 2)
        #expect(DomainClock.text(free[0].end, in: utc) == "2026-09-10 10:00")
        #expect(DomainClock.text(free[1].start, in: utc) == "2026-09-10 14:00")
        #expect(free[1].duration == 9 * 60 * 60)
    }

    @Test func aRangeCoveringTheWholeDayRemovesThatDay() {
        let result = engine(calendar: utc).result(
            viewer: viewer,
            partner: partner,
            busyRanges: [busy(partnerId, "2026-09-12", "2026-09-13", in: utc)],
            from: DomainClock.date("2026-09-12", in: utc),
            to: DomainClock.date("2026-09-14", in: utc)
        )
        let free = slots(result)
        #expect(free.count == 1)
        #expect(DomainClock.text(free[0].start, in: utc) == "2026-09-13 08:00")
        #expect(free[0].isAllDay)
    }

    @Test func rangesOfOtherMembersAreIgnored() {
        let result = engine(calendar: utc).result(
            viewer: viewer,
            partner: partner,
            busyRanges: [busy(UUID(), "2026-09-10 08:00", "2026-09-10 23:00", in: utc)],
            from: DomainClock.date("2026-09-10", in: utc),
            to: DomainClock.date("2026-09-11", in: utc)
        )
        #expect(slots(result).count == 1)
    }

    @Test func everyDayKeepsItsLocalWorkingHoursAcrossADaylightSavingChange() {
        let result = engine(calendar: berlin).result(
            viewer: viewer,
            partner: partner,
            busyRanges: [],
            from: DomainClock.date("2026-03-28", in: berlin),
            to: DomainClock.date("2026-03-31", in: berlin)
        )
        let free = slots(result)
        #expect(free.count == 3)
        #expect(DomainClock.text(free[0].start, in: berlin) == "2026-03-28 08:00")
        #expect(DomainClock.text(free[1].start, in: berlin) == "2026-03-29 08:00")
        #expect(DomainClock.text(free[2].start, in: berlin) == "2026-03-30 08:00")
        #expect(free.allSatisfy { $0.duration == 15 * 60 * 60 })
        #expect(free.allSatisfy { $0.isAllDay })
        #expect(free[1].start.timeIntervalSince(free[0].start) == 23 * 60 * 60)
        #expect(free[2].start.timeIntervalSince(free[1].start) == 24 * 60 * 60)
    }

    @Test func theNightTheClocksGoBackDoesNotRepeatOrSkipADay() {
        let result = engine(calendar: berlin).result(
            viewer: viewer,
            partner: partner,
            busyRanges: [],
            from: DomainClock.date("2026-10-24", in: berlin),
            to: DomainClock.date("2026-10-27", in: berlin)
        )
        let free = slots(result)
        #expect(free.count == 3)
        #expect(DomainClock.text(free[0].start, in: berlin) == "2026-10-24 08:00")
        #expect(DomainClock.text(free[1].start, in: berlin) == "2026-10-25 08:00")
        #expect(DomainClock.text(free[2].start, in: berlin) == "2026-10-26 08:00")
        #expect(free[1].start.timeIntervalSince(free[0].start) == 25 * 60 * 60)
        #expect(free.allSatisfy { $0.duration == 15 * 60 * 60 })
    }

    @Test func aBusyRangeSpanningTheDaylightSavingNightCutsBothDays() {
        let result = engine(calendar: berlin).result(
            viewer: viewer,
            partner: partner,
            busyRanges: [busy(viewerId, "2026-03-28 22:00", "2026-03-29 09:00", in: berlin)],
            from: DomainClock.date("2026-03-28", in: berlin),
            to: DomainClock.date("2026-03-30", in: berlin)
        )
        let free = slots(result)
        #expect(free.count == 2)
        #expect(DomainClock.text(free[0].end, in: berlin) == "2026-03-28 22:00")
        #expect(DomainClock.text(free[1].start, in: berlin) == "2026-03-29 09:00")
        #expect(free.allSatisfy { $0.isAllDay == false })
    }

    @Test func aPartnerWhoDoesNotShareIsReportedInsteadOfAnEmptyList() {
        let result = engine(calendar: utc).result(
            viewer: viewer,
            partner: FreeSlotParticipant(memberId: partnerId, sharesBusyTimes: false),
            busyRanges: [],
            from: DomainClock.date("2026-09-10", in: utc),
            to: DomainClock.date("2026-09-11", in: utc)
        )
        #expect(result == FreeSlotResult.partnerHasNoData)
    }

    @Test func aViewerWhoDoesNotShareIsReportedBeforeThePartner() {
        let result = engine(calendar: utc).result(
            viewer: FreeSlotParticipant(memberId: viewerId, sharesBusyTimes: false),
            partner: FreeSlotParticipant(memberId: partnerId, sharesBusyTimes: false),
            busyRanges: [],
            from: DomainClock.date("2026-09-10", in: utc),
            to: DomainClock.date("2026-09-11", in: utc)
        )
        #expect(result == FreeSlotResult.viewerHasNoData)
    }

    @Test func aSharingPartnerWithoutAnyRangeIsFree() {
        let result = engine(calendar: utc).result(
            viewer: viewer,
            partner: partner,
            busyRanges: [],
            from: DomainClock.date("2026-09-10", in: utc),
            to: DomainClock.date("2026-09-12", in: utc)
        )
        #expect(slots(result).count == 2)
    }

    @Test func twoBookedMembersProduceNoSlotsAtAll() {
        let result = engine(calendar: utc).result(
            viewer: viewer,
            partner: partner,
            busyRanges: [busy(viewerId, "2026-09-10", "2026-09-11", in: utc)],
            from: DomainClock.date("2026-09-10", in: utc),
            to: DomainClock.date("2026-09-11", in: utc)
        )
        #expect(result == FreeSlotResult.none)
    }

    @Test func aPartnerNineHoursAheadGetsTheirOwnStartTime() {
        let result = engine(calendar: utc, partnerTimeZone: "Asia/Tokyo").result(
            viewer: viewer,
            partner: partner,
            busyRanges: [],
            from: DomainClock.date("2026-09-10", in: utc),
            to: DomainClock.date("2026-09-11", in: utc)
        )
        let free = slots(result)
        #expect(free.count == 1)
        #expect(free[0].partnerLabel?.contains("5:00") == true)
    }

    @Test func aPartnerOneHourAheadGetsNoLabel() {
        let result = engine(calendar: utc, partnerTimeZone: "Europe/London").result(
            viewer: viewer,
            partner: partner,
            busyRanges: [],
            from: DomainClock.date("2026-09-10", in: utc),
            to: DomainClock.date("2026-09-11", in: utc)
        )
        #expect(slots(result).first?.partnerLabel == nil)
    }

    @Test func theEveningsFilterStartsSlotsAtSix() {
        let result = engine(calendar: utc).result(
            viewer: viewer,
            partner: partner,
            busyRanges: [],
            from: DomainClock.date("2026-09-10", in: utc),
            to: DomainClock.date("2026-09-11", in: utc),
            filters: FreeSlotFilters(eveningsOnly: true)
        )
        let free = slots(result)
        #expect(free.count == 1)
        #expect(DomainClock.text(free[0].start, in: utc) == "2026-09-10 18:00")
        #expect(free[0].isAllDay == false)
    }

    @Test func theWeekendsFilterKeepsSaturdayAndSunday() {
        let result = engine(calendar: utc).result(
            viewer: viewer,
            partner: partner,
            busyRanges: [],
            from: DomainClock.date("2026-09-10", in: utc),
            to: DomainClock.date("2026-09-14", in: utc),
            filters: FreeSlotFilters(weekendsOnly: true)
        )
        let free = slots(result)
        #expect(free.count == 2)
        #expect(DomainClock.text(free[0].start, in: utc) == "2026-09-12 08:00")
        #expect(DomainClock.text(free[1].start, in: utc) == "2026-09-13 08:00")
    }

    @Test func theTwoHourFilterDropsTheShorterGap() {
        let ranges = [busy(viewerId, "2026-09-10 10:00", "2026-09-10 22:00", in: utc)]
        let hour = engine(calendar: utc).result(
            viewer: viewer,
            partner: partner,
            busyRanges: ranges,
            from: DomainClock.date("2026-09-10", in: utc),
            to: DomainClock.date("2026-09-11", in: utc)
        )
        #expect(slots(hour).count == 2)

        let twoHours = engine(calendar: utc).result(
            viewer: viewer,
            partner: partner,
            busyRanges: ranges,
            from: DomainClock.date("2026-09-10", in: utc),
            to: DomainClock.date("2026-09-11", in: utc),
            filters: FreeSlotFilters(minimumDuration: 2 * 60 * 60)
        )
        let free = slots(twoHours)
        #expect(free.count == 1)
        #expect(free[0].duration == 2 * 60 * 60)
    }

    @Test func aWindowCutShortByTheRangeStartIsNotAllDay() {
        let result = engine(calendar: utc).result(
            viewer: viewer,
            partner: partner,
            busyRanges: [],
            from: DomainClock.date("2026-09-10 12:00", in: utc),
            to: DomainClock.date("2026-09-11", in: utc)
        )
        let free = slots(result)
        #expect(free.count == 1)
        #expect(DomainClock.text(free[0].start, in: utc) == "2026-09-10 12:00")
        #expect(free[0].isAllDay == false)
    }

    @Test func narrowerWorkingHoursShortenEveryWindow() {
        let result = engine(calendar: utc, workingHours: WorkingHours(startHour: 9, endHour: 18)).result(
            viewer: viewer,
            partner: partner,
            busyRanges: [],
            from: DomainClock.date("2026-09-10", in: utc),
            to: DomainClock.date("2026-09-11", in: utc)
        )
        let free = slots(result)
        #expect(free.count == 1)
        #expect(free[0].duration == 9 * 60 * 60)
        #expect(free[0].isAllDay)
    }
}
