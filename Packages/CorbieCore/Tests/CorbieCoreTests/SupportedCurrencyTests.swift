import CoreData
import Foundation
import Testing
@testable import CorbieCore

@Suite struct SupportedCurrencyListTests {
    @Test func theListIsEveryCurrencyTheRatesFeedCarries() {
        #expect(SupportedCurrencies.codes.count == 30)
        #expect(Set(SupportedCurrencies.codes).count == 30)
        for code in ["USD", "EUR", "GBP", "BRL", "INR", "KRW", "MXN", "SGD", "HKD", "ZAR", "JPY", "CHF"] {
            #expect(SupportedCurrencies.contains(code), "\(code)")
        }
        #expect(SupportedCurrencies.fallbackCode == "USD")
        #expect(SupportedCurrencies.common.allSatisfy(SupportedCurrencies.contains))
    }

    @Test func rublesAndCurrenciesTheFeedDropsAreNeverOffered() {
        for code in ["RUB", " rub ", "UAH", "BGN", "AED"] {
            #expect(SupportedCurrencies.contains(code) == false, "\(code)")
        }
        #expect(SupportedCurrencies.codeOrFallback("RUB") == "USD")
    }

    @Test func aSupportedCodeIsKeptAndAnythingElseIsTheFallback() {
        #expect(SupportedCurrencies.codeOrFallback(" eur ") == "EUR")
        #expect(SupportedCurrencies.codeOrFallback("PLN") == "PLN")
        #expect(SupportedCurrencies.codeOrFallback("krw") == "KRW")
        #expect(SupportedCurrencies.codeOrFallback("UAH") == "USD")
        #expect(SupportedCurrencies.codeOrFallback("") == "USD")
        #expect(SupportedCurrencies.codeOrFallback(nil) == "USD")
    }

    @Test(arguments: [
        ("en_US", "USD"),
        ("pt_BR", "BRL"),
        ("ko_KR", "KRW"),
        ("en_IN", "INR"),
        ("es_MX", "MXN"),
        ("en_ZA", "ZAR"),
        ("de_DE", "EUR"),
        ("ja_JP", "JPY"),
        ("en_SG", "SGD"),
        ("zh_HK", "HKD"),
        ("en_US@currency=EUR", "EUR"),
        ("ru_RU", "USD"),
        ("uk_UA", "USD"),
        ("ar_AE", "USD"),
        ("en", "USD")
    ])
    func aNewSpaceTakesTheRegionsCurrencyWhenItIsSupported(identifier: String, expected: String) {
        #expect(SupportedCurrencies.defaultCode(for: Locale(identifier: identifier)) == expected)
    }

    @Test func ruRUFallsBackToDollarsBecauseRublesAreNotInTheFeed() {
        let russia = Locale(identifier: "ru_RU")
        #expect(russia.currency?.identifier == "RUB")
        #expect(SupportedCurrencies.defaultCode(for: russia) == "USD")
    }

    @Test func theStoredFallbackStaysDollarsWhateverTheRegion() async throws {
        let controller = PersistenceController.inMemory()
        let space = try await controller.repositories.spaces.create()
        let plan = try await controller.repositories.plans.create(PlanDraft(spaceId: space.id, title: "The pot"))
        #expect(space.displayCurrency == "USD")
        #expect(plan.currency == "USD")
    }

    @Test func thePickerPutsTheDevicesCurrencyFirstThenTheCommonOnesThenTheRest() {
        let brazil = SupportedCurrencies.pickerGroups(for: Locale(identifier: "pt_BR"))
        #expect(brazil.count == 3)
        #expect(brazil[0] == ["BRL"])
        #expect(brazil[1] == SupportedCurrencies.common)
        #expect(Set(brazil.flatMap { $0 }) == Set(SupportedCurrencies.codes))
        #expect(brazil.flatMap { $0 }.count == SupportedCurrencies.codes.count)

        let america = SupportedCurrencies.pickerGroups(for: Locale(identifier: "en_US"))
        #expect(america[0] == ["USD"])
        #expect(america[1] == ["EUR", "GBP", "JPY", "AUD", "CAD", "CHF", "HKD", "SGD"])
        let rest = america[2]
        let names = rest.map { SupportedCurrencies.name(of: $0, in: Locale(identifier: "en_US")) }
        #expect(names == names.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
    }

    @Test func aDeviceInAnUnsupportedCurrencyStartsWithTheCommonOnes() {
        let russia = SupportedCurrencies.pickerGroups(for: Locale(identifier: "ru_RU"))
        #expect(russia.count == 2)
        #expect(russia[0] == SupportedCurrencies.common)
        #expect(russia.flatMap { $0 }.contains("RUB") == false)
    }

    @Test func aPickerRowNamesTheCurrencyAndShowsItsCode() {
        #expect(SupportedCurrencies.label(of: "BRL", in: Locale(identifier: "en_US")) == "Brazilian Real (BRL)")
    }
}

@Suite struct UnsupportedCurrencyRepairTests {
    private let later = Date(timeIntervalSince1970: 1_900_000_000)

    private struct Rows {
        let plan: PlanDTO
        let expense: PlanExpenseDTO
        let wish: WishDTO
        let idea: GiftIdeaDTO
        let personId: UUID
    }

    private func makeRows(_ world: TestWorld, currency: String = "USD") async throws -> Rows {
        let repositories = world.repositories
        let plan = try await repositories.plans.create(
            PlanDraft(
                spaceId: world.space.id,
                title: "Lisbon",
                type: .trip,
                targetAmount: 150_000,
                currency: currency,
                savedAmount: 1240,
                createdByMemberId: world.partner.id
            )
        )
        let expense = try await repositories.plans.addExpense(
            planId: plan.id,
            draft: PlanExpenseDraft(amount: 5000, currency: currency, addedByMemberId: world.partner.id)
        )
        let wish = try await repositories.wishes.create(
            WishDraft(
                spaceId: world.space.id,
                ownerMemberId: world.partner.id,
                addedByMemberId: world.partner.id,
                title: "Kettle",
                price: 7990,
                currency: currency
            )
        )
        let person = try await repositories.people.create(PersonDraft(spaceId: world.space.id, name: "Mum"))
        let idea = try await repositories.people.addGiftIdea(
            personId: person.id,
            draft: GiftIdeaDraft(title: "Scarf", price: 3500, currency: currency)
        )
        return Rows(plan: plan, expense: expense, wish: wish, idea: idea, personId: person.id)
    }

    private func setStoredCurrency(
        _ code: String?,
        _ entityName: String,
        key: String = "currency",
        id: UUID,
        in world: TestWorld
    ) async throws {
        try await OtherContext.change(entityName, id: id, in: world.controller) { (object: NSManagedObject) in
            object.setValue(code, forKey: key)
        }
    }

    private func storedCurrency(
        _ entityName: String,
        key: String = "currency",
        id: UUID,
        in world: TestWorld
    ) throws -> String? {
        let context = world.controller.stack.newBackgroundContext()
        return try context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            request.predicate = NSPredicate(format: "id == %@", id as NSUUID)
            return try context.fetch(request).first?.value(forKey: key) as? String
        }
    }

    private func storeRubles(_ rows: Rows, in world: TestWorld) async throws {
        try await setStoredCurrency("RUB", Space.entityName, key: "displayCurrency", id: world.space.id, in: world)
        try await setStoredCurrency("RUB", Plan.entityName, id: rows.plan.id, in: world)
        try await setStoredCurrency("RUB", PlanExpense.entityName, id: rows.expense.id, in: world)
        try await setStoredCurrency("rub", Wish.entityName, id: rows.wish.id, in: world)
        try await setStoredCurrency("UAH", GiftIdea.entityName, id: rows.idea.id, in: world)
    }

    @Test func everyUnsupportedCodeInTheSpaceBecomesDollarsAndNoAmountMoves() async throws {
        let world = try await TestWorld.make()
        let rows = try await makeRows(world)
        try await storeRubles(rows, in: world)

        let replaced = try await UnsupportedCurrencyRepair(repositories: world.repositories).run(spaceId: world.space.id)

        #expect(replaced == 5)
        #expect(try storedCurrency(Space.entityName, key: "displayCurrency", id: world.space.id, in: world) == "USD")
        #expect(try storedCurrency(Plan.entityName, id: rows.plan.id, in: world) == "USD")
        #expect(try storedCurrency(PlanExpense.entityName, id: rows.expense.id, in: world) == "USD")
        #expect(try storedCurrency(Wish.entityName, id: rows.wish.id, in: world) == "USD")
        #expect(try storedCurrency(GiftIdea.entityName, id: rows.idea.id, in: world) == "USD")

        let repositories = world.repositories
        let plan = try #require(try await repositories.plans.plan(id: rows.plan.id))
        #expect(plan.targetAmount == 150_000)
        #expect(plan.savedAmount == 1240)
        #expect(plan.addedAmount == 5000)
        let expense = try #require(try await repositories.plans.expenses(planId: rows.plan.id).first)
        #expect(expense.amount == 5000)
        #expect(expense.fxRateToPlanCurrency == 1)
        #expect(expense.amountInPlanCurrency == 5000)
        #expect(try await repositories.wishes.wish(id: rows.wish.id)?.price == 7990)
        let idea = try #require(try await repositories.people.giftIdeas(personId: rows.personId).first)
        #expect(idea.price == 3500)
    }

    @Test func aSecondRunFindsNothingToDo() async throws {
        let world = try await TestWorld.make()
        let rows = try await makeRows(world)
        try await storeRubles(rows, in: world)
        let repair = UnsupportedCurrencyRepair(repositories: world.repositories)

        #expect(try await repair.run(spaceId: world.space.id) == 5)
        #expect(try await repair.run(spaceId: world.space.id) == 0)
        #expect(try storedCurrency(Plan.entityName, id: rows.plan.id, in: world) == "USD")
    }

    @Test func supportedAndMissingCodesAreLeftAlone() async throws {
        let world = try await TestWorld.make()
        let rows = try await makeRows(world, currency: "EUR")
        let bare = try await world.repositories.wishes.create(
            WishDraft(spaceId: world.space.id, ownerMemberId: world.me.id, title: "Something nice")
        )

        let replaced = try await UnsupportedCurrencyRepair(repositories: world.repositories).run(spaceId: world.space.id)

        #expect(replaced == 0)
        #expect(try storedCurrency(Space.entityName, key: "displayCurrency", id: world.space.id, in: world) == "USD")
        #expect(try storedCurrency(Plan.entityName, id: rows.plan.id, in: world) == "EUR")
        #expect(try storedCurrency(PlanExpense.entityName, id: rows.expense.id, in: world) == "EUR")
        #expect(try storedCurrency(Wish.entityName, id: rows.wish.id, in: world) == "EUR")
        #expect(try storedCurrency(GiftIdea.entityName, id: rows.idea.id, in: world) == "EUR")
        #expect(try storedCurrency(Wish.entityName, id: bare.id, in: world) == nil)
    }

    @Test func anotherSpaceIsNotTouched() async throws {
        let world = try await TestWorld.make()
        let other = try await world.repositories.spaces.create(displayCurrency: "RUB")
        let otherPlan = try await world.repositories.plans.create(
            PlanDraft(spaceId: other.id, title: "Dacha", currency: "RUB")
        )

        _ = try await UnsupportedCurrencyRepair(repositories: world.repositories).run(spaceId: world.space.id)

        #expect(try storedCurrency(Space.entityName, key: "displayCurrency", id: other.id, in: world) == "RUB")
        #expect(try storedCurrency(Plan.entityName, id: otherPlan.id, in: world) == "RUB")
    }

    @Test func aStaleCopyEditedElsewhereKeepsItsOtherFields() async throws {
        let world = try await TestWorld.make()
        let rows = try await makeRows(world)
        try await storeRubles(rows, in: world)
        try await OtherContext.change(Space.entityName, id: world.space.id, in: world.controller) { (space: Space) in
            space.weddingDate = later
        }
        try await OtherContext.change(Plan.entityName, id: rows.plan.id, in: world.controller) { (plan: Plan) in
            plan.title = "Lisbon in May"
            plan.savedAmount = 2000
            plan.status = .completed
        }
        try await OtherContext.change(Wish.entityName, id: rows.wish.id, in: world.controller) { (wish: Wish) in
            wish.title = "Kettle, the green one"
            wish.price = NSNumber(value: 8490)
            wish.note = "not the loud one"
        }
        try await OtherContext.change(GiftIdea.entityName, id: rows.idea.id, in: world.controller) { (idea: GiftIdea) in
            idea.isDone = true
        }

        _ = try await UnsupportedCurrencyRepair(repositories: world.repositories).run(spaceId: world.space.id)

        let repositories = world.repositories
        let space = try #require(try await repositories.spaces.space(id: world.space.id))
        #expect(space.weddingDate == later)
        let plan = try #require(try await repositories.plans.plan(id: rows.plan.id))
        #expect(plan.title == "Lisbon in May")
        #expect(plan.savedAmount == 2000)
        #expect(plan.status == .completed)
        #expect(plan.currency == "USD")
        let wish = try #require(try await repositories.wishes.wish(id: rows.wish.id))
        #expect(wish.title == "Kettle, the green one")
        #expect(wish.price == 8490)
        #expect(wish.note == "not the loud one")
        #expect(wish.currency == "USD")
        let idea = try #require(try await repositories.people.giftIdeas(personId: rows.personId).first)
        #expect(idea.isDone)
        #expect(try storedCurrency(GiftIdea.entityName, id: rows.idea.id, in: world) == "USD")
    }

    @Test func aStoredRubleIsShownAsDollarsBeforeTheRepairRuns() async throws {
        let world = try await TestWorld.make()
        let rows = try await makeRows(world)
        try await storeRubles(rows, in: world)
        let repositories = world.repositories

        #expect(try await repositories.spaces.space(id: world.space.id)?.displayCurrency == "USD")
        #expect(try await repositories.plans.plan(id: rows.plan.id)?.currency == "USD")
        #expect(try await repositories.plans.expenses(planId: rows.plan.id).first?.currency == "USD")
        #expect(try await repositories.wishes.wish(id: rows.wish.id)?.currency == "USD")
        let ideas = try await repositories.people.giftIdeas(personId: rows.personId)
        #expect(ideas.first?.currency == "USD")
        #expect(try storedCurrency(Plan.entityName, id: rows.plan.id, in: world) == "RUB")
    }
}
