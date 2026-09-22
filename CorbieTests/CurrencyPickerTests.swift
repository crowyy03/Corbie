import CorbieCore
import XCTest
@testable import Corbie

@MainActor
final class CurrencyPickerTests: XCTestCase {
    private func environment(displayCurrency: String) throws -> AppEnvironment {
        let environment = AppEnvironment.previewSignedIn(paired: false)
        var space = try XCTUnwrap(environment.space)
        space.displayCurrency = displayCurrency
        environment.apply(space: space)
        return environment
    }

    func testEveryPickerOffersTheSameEightInTheSameOrder() throws {
        let environment = try environment(displayCurrency: "EUR")
        let plan = PlanDTO(id: UUID(), title: "Lisbon", currency: "EUR")

        let settings = SettingsViewModel()
        settings.attach(environment)
        let planEditor = PlanEditorViewModel(plan: nil)
        planEditor.attach(environment)
        let expenseEditor = ExpenseEditorViewModel(plan: plan)
        expenseEditor.attach(environment)
        let wishEditor = WishEditorViewModel()
        wishEditor.configure(environment, request: WishEditorRequest(wish: nil, link: nil))
        let giftEditor = GiftIdeaEditorViewModel(personId: UUID(), mode: .new)
        giftEditor.bind(environment)

        let expected = ["USD", "EUR", "GBP", "CAD", "AUD", "NZD", "JPY", "CHF"]
        XCTAssertEqual(settings.currencies, expected)
        XCTAssertEqual(planEditor.currencies, expected)
        XCTAssertEqual(expenseEditor.currencies, expected)
        XCTAssertEqual(wishEditor.currencies, expected)
        XCTAssertEqual(giftEditor.currencies, expected)
        XCTAssertFalse(expected.contains("RUB"))
    }

    func testNewThingsStartOnTheSpaceCurrencyAndOnDollarsWithoutOne() throws {
        XCTAssertEqual(PlanEditorViewModel(plan: nil).currency, "USD")
        XCTAssertEqual(WishEditorViewModel().currency, "USD")
        XCTAssertEqual(SettingsViewModel().displayCurrency, "USD")

        let environment = try environment(displayCurrency: "GBP")
        let planEditor = PlanEditorViewModel(plan: nil)
        planEditor.attach(environment)
        let wishEditor = WishEditorViewModel()
        wishEditor.configure(environment, request: WishEditorRequest(wish: nil, link: nil))
        let giftEditor = GiftIdeaEditorViewModel(personId: UUID(), mode: .new)
        giftEditor.bind(environment)

        XCTAssertEqual(planEditor.currency, "GBP")
        XCTAssertEqual(wishEditor.currency, "GBP")
        XCTAssertEqual(giftEditor.currency, "GBP")
    }

    func testARubleCopyNeverBecomesThePickerSelection() throws {
        let environment = try environment(displayCurrency: "EUR")
        let planEditor = PlanEditorViewModel(plan: PlanDTO(id: UUID(), title: "Dacha", currency: "RUB"))
        let wishEditor = WishEditorViewModel()
        wishEditor.configure(
            environment,
            request: WishEditorRequest(wish: WishDTO(id: UUID(), title: "Kettle", price: 7990, currency: "RUB"))
        )

        XCTAssertEqual(planEditor.currency, "USD")
        XCTAssertEqual(wishEditor.currency, "EUR")
    }
}
