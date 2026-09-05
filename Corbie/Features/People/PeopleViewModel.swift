import CorbieCore
import Foundation
import Observation

enum PersonEditorMode: Identifiable {
    case new
    case existing(PersonDTO)

    var id: String {
        switch self {
        case .new: return "new"
        case let .existing(person): return person.id.uuidString
        }
    }

    var person: PersonDTO? {
        switch self {
        case .new: return nil
        case let .existing(person): return person
        }
    }
}

@MainActor
@Observable
final class PeopleViewModel {
    private(set) var people: [PersonDTO] = []
    private(set) var radar: [UUID: PeopleRadarSummary] = [:]
    private(set) var hasLoaded = false
    var editor: PersonEditorMode?

    @ObservationIgnored private var environment: AppEnvironment?

    func bind(_ environment: AppEnvironment) {
        self.environment = environment
    }

    func load() async {
        guard let environment, let space = environment.space else {
            hasLoaded = true
            return
        }
        do {
            people = try await environment.repositories.people.people(spaceId: space.id)
        } catch {
            environment.report(error)
        }
        let summaries = await PeopleRadar(environment: environment).refresh(people: people)
        radar = PeopleRadarSummary.byPerson(summaries)
        hasLoaded = true
    }

    func reload() {
        Task { await load() }
    }

    func startAdding() {
        guard let environment, environment.premiumGate.require(.create) else { return }
        editor = .new
    }

    func startEditing(_ person: PersonDTO) {
        guard let environment, environment.premiumGate.require(.edit) else { return }
        editor = .existing(person)
    }
}
