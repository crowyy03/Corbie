import CorbieCore
import XCTest
@testable import Corbie

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
