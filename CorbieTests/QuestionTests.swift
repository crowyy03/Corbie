import CorbieCore
import XCTest
@testable import Corbie

final class QuestionReminderPlannerTests: XCTestCase {
    private let viewerId = UUID()
    private let partnerId = UUID()

    func testTheReminderIsPlannedForTheDayTheQuestionBelongsTo() throws {
        let plan = try XCTUnwrap(
            QuestionReminderPlanner.plan(
                question: question(dayKey: "2026-09-07"),
                viewerMemberId: viewerId,
                partnerMemberId: partnerId,
                today: "2026-09-07"
            )
        )
        XCTAssertEqual(plan.dayKey, "2026-09-07")
        XCTAssertFalse(plan.partnerAnswered)
        XCTAssertFalse(plan.viewerAnswered)
    }

    func testAQuestionFromAnotherDayIsNotWorthAReminder() {
        XCTAssertNil(
            QuestionReminderPlanner.plan(
                question: question(dayKey: "2026-09-06"),
                viewerMemberId: viewerId,
                partnerMemberId: partnerId,
                today: "2026-09-07"
            )
        )
    }

    func testWithoutAQuestionOrAViewerThereIsNothingToPlan() {
        XCTAssertNil(
            QuestionReminderPlanner.plan(
                question: nil,
                viewerMemberId: viewerId,
                partnerMemberId: partnerId,
                today: "2026-09-07"
            )
        )
        XCTAssertNil(
            QuestionReminderPlanner.plan(
                question: question(dayKey: "2026-09-07"),
                viewerMemberId: nil,
                partnerMemberId: partnerId,
                today: "2026-09-07"
            )
        )
    }

    func testThePlanReportsWhoHasAlreadyWritten() throws {
        var today = question(dayKey: "2026-09-07")
        today.answers = [
            QuestionAnswerDTO(id: UUID(), memberId: partnerId, text: "The bread we burned"),
        ]
        let waiting = try XCTUnwrap(
            QuestionReminderPlanner.plan(
                question: today,
                viewerMemberId: viewerId,
                partnerMemberId: partnerId,
                today: "2026-09-07"
            )
        )
        XCTAssertTrue(waiting.partnerAnswered)
        XCTAssertFalse(waiting.viewerAnswered)

        today.answers.append(QuestionAnswerDTO(id: UUID(), memberId: viewerId, text: "A dog on the tram"))
        let done = try XCTUnwrap(
            QuestionReminderPlanner.plan(
                question: today,
                viewerMemberId: viewerId,
                partnerMemberId: partnerId,
                today: "2026-09-07"
            )
        )
        XCTAssertTrue(done.viewerAnswered)
    }

    func testAPartnerNobodyHasJoinedYetNeverCountsAsAnswered() throws {
        var today = question(dayKey: "2026-09-07")
        today.answers = [QuestionAnswerDTO(id: UUID(), memberId: viewerId, text: "A dog on the tram")]
        let plan = try XCTUnwrap(
            QuestionReminderPlanner.plan(
                question: today,
                viewerMemberId: viewerId,
                partnerMemberId: nil,
                today: "2026-09-07"
            )
        )
        XCTAssertFalse(plan.partnerAnswered)
        XCTAssertTrue(plan.viewerAnswered)
    }

    private func question(dayKey: String) -> DailyQuestionDTO {
        DailyQuestionDTO(id: UUID(), questionId: "q0001", dayKey: dayKey)
    }
}

@MainActor
final class QuestionDraftTests: XCTestCase {
    func testTheDraftStopsAtTheAnswerLimit() {
        let model = QuestionViewModel(question: DailyQuestionDTO(id: UUID()), text: "What made you laugh today")
        model.draft = String(repeating: "a", count: QuestionAnswerDTO.maxLength + 60)
        XCTAssertEqual(model.draft.count, QuestionAnswerDTO.maxLength)
        XCTAssertEqual(model.charactersLeft, 0)
    }

    func testTheCounterOnlyAppearsNearTheLimit() {
        let model = QuestionViewModel(question: DailyQuestionDTO(id: UUID()), text: "What made you laugh today")
        model.draft = String(repeating: "a", count: QuestionViewModel.counterThreshold - 1)
        XCTAssertFalse(model.showsCounter)
        model.draft += "a"
        XCTAssertTrue(model.showsCounter)
        XCTAssertEqual(model.charactersLeft, QuestionAnswerDTO.maxLength - QuestionViewModel.counterThreshold)
    }

    func testAnEmptyOrBlankDraftCannotBeSaved() {
        let model = QuestionViewModel(question: DailyQuestionDTO(id: UUID()), text: "What made you laugh today")
        XCTAssertFalse(model.canSave)
        model.draft = "   \n "
        XCTAssertFalse(model.canSave)
        model.draft = "A dog on the tram"
        XCTAssertTrue(model.canSave)
    }
}
