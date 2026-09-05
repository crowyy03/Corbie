import XCTest
@testable import Corbie

final class PeopleRelationTests: XCTestCase {
    private let english = Locale(identifier: "en_US")

    func testAnEmptyQueryOffersEverySuggestion() {
        XCTAssertEqual(RelationSuggestion.matching("", locale: english), RelationSuggestion.allCases)
        XCTAssertEqual(RelationSuggestion.matching("   ", locale: english), RelationSuggestion.allCases)
    }

    func testAPrefixNarrowsTheList() {
        XCTAssertEqual(RelationSuggestion.matching("mo", locale: english), [.mom])
        XCTAssertEqual(RelationSuggestion.matching("fri", locale: english), [.friend])
    }

    func testMatchingIsCaseInsensitiveAndLooksInsideTheWord() {
        XCTAssertEqual(RelationSuggestion.matching("ER", locale: english), [.sister, .brother])
    }

    func testAnExactMatchStopsSuggestingItself() {
        XCTAssertEqual(RelationSuggestion.matching("Mom", locale: english), [])
        XCTAssertEqual(RelationSuggestion.matching("mom", locale: english), [])
        XCTAssertEqual(RelationSuggestion.matching(" Friend ", locale: english), [])
    }

    func testAFreeTextRelationHasNoSuggestions() {
        XCTAssertEqual(RelationSuggestion.matching("landlord", locale: english), [])
    }

    func testTitlesComeFromTheCatalog() {
        XCTAssertEqual(RelationSuggestion.mom.title(locale: english), "Mom")
        XCTAssertEqual(RelationSuggestion.colleague.title(locale: english), "Colleague")
        XCTAssertEqual(RelationSuggestion.mom.key, "people.editor.relation.mom")
    }
}
