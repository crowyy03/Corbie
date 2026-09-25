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

@MainActor
final class QuestionReadOnlyTests: XCTestCase {
    func testTappingTheEditorOfAReadOnlySpaceRaisesThePaywall() async {
        let environment = AppEnvironment.previewSignedIn()
        environment.premiumGate.update(.readOnly)
        let model = QuestionViewModel(question: DailyQuestionDTO(id: UUID()), text: "What made you laugh today")
        await model.attach(environment)

        model.requestWriteAccess()

        XCTAssertEqual(environment.premiumGate.pendingPaywall?.reason, .create)
        XCTAssertEqual(environment.premiumGate.pendingPaywall?.action, .create)
    }

    func testAPaidSpaceTypesWithoutAPaywall() async {
        let environment = AppEnvironment.previewSignedIn()
        environment.premiumGate.update(.premium(source: .storeKit, expiresAt: nil))
        let model = QuestionViewModel(question: DailyQuestionDTO(id: UUID()), text: "What made you laugh today")
        await model.attach(environment)

        model.requestWriteAccess()

        XCTAssertNil(environment.premiumGate.pendingPaywall)
    }
}

final class QuestionStatusCopyTests: XCTestCase {
    func testEachStateReadsItsOwnStatusLine() {
        XCTAssertEqual(QuestionCopy.status(.unanswered(partnerAnswered: true), partnerName: "Sofia"), "Sofia answered · your turn")
        XCTAssertEqual(QuestionCopy.status(.waitingForPartner, partnerName: "Sofia"), "You answered · waiting for Sofia")
        XCTAssertEqual(QuestionCopy.status(.revealUnread, partnerName: "Sofia"), "Sofia answered · tap to see")
        XCTAssertEqual(QuestionCopy.status(.revealRead, partnerName: "Sofia"), "Both answered")
    }

    func testTheDotSaysWhoseAnswerIsWaiting() {
        XCTAssertEqual(QuestionCopy.waitingDotLabel(partnerName: "Sofia"), "Sofia's answer is waiting")
    }
}
