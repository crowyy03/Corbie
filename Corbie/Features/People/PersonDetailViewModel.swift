import CorbieCore
import Foundation
import Observation

@MainActor
@Observable
final class PersonDetailViewModel {
    private(set) var person: PersonDTO?
    private(set) var ideas: [GiftIdeaDTO] = []
    private(set) var radar: PeopleRadarSummary?
    private(set) var hasLoaded = false
    private(set) var isGone = false
    var editor: PersonEditorMode?
    var giftEditor: GiftIdeaEditorMode?
    var isConfirmingDelete = false

    @ObservationIgnored let personId: UUID
    @ObservationIgnored private var environment: AppEnvironment?

    init(personId: UUID) {
        self.personId = personId
    }

    func bind(_ environment: AppEnvironment) {
        self.environment = environment
    }

    func load() async {
        guard let environment, let space = environment.space else {
            hasLoaded = true
            return
        }
        do {
            let people = try await environment.repositories.people.people(spaceId: space.id)
            guard let current = people.first(where: { $0.id == personId }) else {
                isGone = true
                hasLoaded = true
                return
            }
            person = current
            ideas = try await environment.repositories.people.giftIdeas(personId: personId)
            let summaries = await PeopleRadar(environment: environment).refresh(people: people)
            radar = PeopleRadarSummary.byPerson(summaries)[personId]
        } catch {
            environment.report(error)
        }
        hasLoaded = true
    }

    func reload() {
        Task { await load() }
    }

    func startEditingPerson() {
        guard let environment, let person, environment.premiumGate.require(.edit) else { return }
        editor = .existing(person)
    }

    func startAddingIdea() {
        guard let environment, environment.premiumGate.require(.create) else { return }
        giftEditor = .new
    }

    func startEditingIdea(_ idea: GiftIdeaDTO) {
        guard let environment, environment.premiumGate.require(.edit) else { return }
        giftEditor = .existing(idea)
    }

    func toggle(_ idea: GiftIdeaDTO) async {
        guard let environment, environment.premiumGate.require(.edit) else { return }
        var updated = idea
        updated.isDone.toggle()
        do {
            _ = try await environment.repositories.people.updateGiftIdea(updated)
        } catch {
            environment.report(error)
        }
        await load()
    }

    func deleteIdea(_ idea: GiftIdeaDTO) async {
        guard let environment, environment.premiumGate.require(.edit) else { return }
        do {
            try await environment.repositories.people.deleteGiftIdea(id: idea.id)
        } catch {
            environment.report(error)
        }
        await load()
    }

    func deletePerson() async {
        guard let environment, environment.premiumGate.require(.edit) else { return }
        do {
            try await environment.repositories.people.delete(id: personId)
            isGone = true
            if let space = environment.space {
                let remaining = try await environment.repositories.people.people(spaceId: space.id)
                _ = await PeopleRadar(environment: environment).refresh(people: remaining)
            }
        } catch {
            environment.report(error)
        }
    }

    func priceText(_ idea: GiftIdeaDTO, locale: Locale = .current) -> String? {
        guard let price = idea.price else { return nil }
        let currency = idea.currency ?? environment?.space?.displayCurrency ?? "USD"
        return Money(amount: price, currency: currency).formatted(locale: locale)
    }
}
