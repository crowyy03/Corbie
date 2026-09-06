import CoreData
import Foundation

public struct CoreDataPeopleRepository: PeopleRepository {
    private let access: CoreDataAccess

    public init(stack: CoreDataStack) {
        access = CoreDataAccess(stack: stack)
    }

    public func create(_ draft: PersonDraft) async throws -> PersonDTO {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.isEmpty == false else {
            throw CorbieError.invalidInput("person name is empty")
        }
        try CoreDataPeopleRepository.validateDay(
            month: draft.birthdayMonth,
            day: draft.birthdayDay,
            year: draft.birthdayYear
        )
        return try await access.write { context in
            let space: Space = try ManagedFetch.require(Space.entityName, id: draft.spaceId, in: context)
            let person = Person(context: context)
            context.assign(person, toStoreOf: space)
            person.space = space
            person.name = name
            person.relation = draft.relation
            person.birthdayMonth = draft.birthdayMonth.map(NSNumber.init(value:))
            person.birthdayDay = draft.birthdayDay.map(NSNumber.init(value:))
            person.birthdayYear = draft.birthdayYear.map(NSNumber.init(value:))
            person.ownerMemberId = draft.ownerMemberId
            person.note = draft.note
            return PersonDTO(person)
        }
    }

    public func update(_ person: PersonDTO) async throws -> PersonDTO {
        try CoreDataPeopleRepository.validateDay(
            month: person.birthdayMonth,
            day: person.birthdayDay,
            year: person.birthdayYear
        )
        return try await access.write { context in
            let entity: Person = try ManagedFetch.require(Person.entityName, id: person.id, in: context)
            entity.name = person.name
            entity.relation = person.relation
            entity.birthdayMonth = person.birthdayMonth.map(NSNumber.init(value:))
            entity.birthdayDay = person.birthdayDay.map(NSNumber.init(value:))
            entity.birthdayYear = person.birthdayYear.map(NSNumber.init(value:))
            entity.ownerMemberId = person.ownerMemberId
            entity.note = person.note
            return PersonDTO(entity)
        }
    }

    public func person(id: UUID) async throws -> PersonDTO? {
        try await access.read { context in
            let person: Person? = try ManagedFetch.first(Person.entityName, id: id, in: context)
            return person.map(PersonDTO.init)
        }
    }

    public func people(spaceId: UUID) async throws -> [PersonDTO] {
        try await access.read { context in
            let people: [Person] = try ManagedFetch.all(
                Person.entityName,
                predicate: ManagedFetch.spaceRelation(spaceId),
                sort: [NSSortDescriptor(key: "name", ascending: true)],
                in: context
            )
            return people.map(PersonDTO.init)
        }
    }

    public func delete(id: UUID) async throws {
        try await access.write { context in
            guard let person: Person = try ManagedFetch.first(Person.entityName, id: id, in: context) else { return }
            let events: [Event] = try ManagedFetch.all(
                Event.entityName,
                predicate: NSPredicate(format: "personId == %@", id as NSUUID),
                in: context
            )
            for event in events {
                event.personId = nil
            }
            context.delete(person)
        }
    }

    public func addDate(personId: UUID, draft: PersonDateDraft) async throws -> PersonDateDTO {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.isEmpty == false else {
            throw CorbieError.invalidInput("person date title is empty")
        }
        try CoreDataPeopleRepository.validateDay(month: draft.month, day: draft.day, year: draft.year)
        return try await access.write { context in
            let person: Person = try ManagedFetch.require(Person.entityName, id: personId, in: context)
            let date = PersonDate(context: context)
            context.assign(date, toStoreOf: person)
            date.person = person
            date.title = title
            date.month = draft.month.map(NSNumber.init(value:))
            date.day = draft.day.map(NSNumber.init(value:))
            date.year = draft.year.map(NSNumber.init(value:))
            date.remindersEnabled = draft.remindersEnabled
            return PersonDateDTO(date)
        }
    }

    public func updateDate(_ date: PersonDateDTO) async throws -> PersonDateDTO {
        let title = date.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.isEmpty == false else {
            throw CorbieError.invalidInput("person date title is empty")
        }
        try CoreDataPeopleRepository.validateDay(month: date.month, day: date.day, year: date.year)
        return try await access.write { context in
            let entity: PersonDate = try ManagedFetch.require(PersonDate.entityName, id: date.id, in: context)
            entity.title = title
            entity.month = date.month.map(NSNumber.init(value:))
            entity.day = date.day.map(NSNumber.init(value:))
            entity.year = date.year.map(NSNumber.init(value:))
            entity.remindersEnabled = date.remindersEnabled
            return PersonDateDTO(entity)
        }
    }

    public func dates(personId: UUID) async throws -> [PersonDateDTO] {
        try await access.read { context in
            let dates: [PersonDate] = try ManagedFetch.all(
                PersonDate.entityName,
                predicate: NSPredicate(format: "person.id == %@", personId as NSUUID),
                in: context
            )
            return dates.map(PersonDateDTO.init).sorted(by: PersonDateDTO.inCalendarOrder)
        }
    }

    public func deleteDate(id: UUID) async throws {
        try await access.write { context in
            guard let date: PersonDate = try ManagedFetch.first(PersonDate.entityName, id: id, in: context) else {
                return
            }
            context.delete(date)
        }
    }

    public func addGiftIdea(personId: UUID, draft: GiftIdeaDraft) async throws -> GiftIdeaDTO {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.isEmpty == false else {
            throw CorbieError.invalidInput("gift idea title is empty")
        }
        return try await access.write { context in
            let person: Person = try ManagedFetch.require(Person.entityName, id: personId, in: context)
            let idea = GiftIdea(context: context)
            context.assign(idea, toStoreOf: person)
            idea.person = person
            idea.title = title
            idea.url = draft.url
            idea.price = draft.price.map(NSNumber.init(value:))
            idea.currency = draft.currency
            idea.note = draft.note
            return GiftIdeaDTO(idea)
        }
    }

    public func updateGiftIdea(_ idea: GiftIdeaDTO) async throws -> GiftIdeaDTO {
        try await access.write { context in
            let entity: GiftIdea = try ManagedFetch.require(GiftIdea.entityName, id: idea.id, in: context)
            entity.title = idea.title
            entity.url = idea.url
            entity.price = idea.price.map(NSNumber.init(value:))
            entity.currency = idea.currency
            entity.note = idea.note
            entity.isDone = idea.isDone
            return GiftIdeaDTO(entity)
        }
    }

    public func giftIdeas(personId: UUID) async throws -> [GiftIdeaDTO] {
        try await access.read { context in
            let ideas: [GiftIdea] = try ManagedFetch.all(
                GiftIdea.entityName,
                predicate: NSPredicate(format: "person.id == %@", personId as NSUUID),
                sort: [NSSortDescriptor(key: "createdAt", ascending: true)],
                in: context
            )
            return ideas.map(GiftIdeaDTO.init)
        }
    }

    public func deleteGiftIdea(id: UUID) async throws {
        try await access.write { context in
            guard let idea: GiftIdea = try ManagedFetch.first(GiftIdea.entityName, id: id, in: context) else { return }
            context.delete(idea)
        }
    }

    private static func validateDay(month: Int?, day: Int?, year: Int?) throws {
        if let year, (1...9999).contains(year) == false {
            throw CorbieError.invalidInput("year \(year) is out of range")
        }
        guard let month, let day else { return }
        guard (1...12).contains(month), (1...31).contains(day) else {
            throw CorbieError.invalidInput("birthday \(month)/\(day) is out of range")
        }
    }
}
