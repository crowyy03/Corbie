#if DEBUG
import Foundation
import os

public struct PreviewSeedResult: Sendable {
    public let controller: PersistenceController
    public let space: SpaceDTO
    public let me: MemberDTO
    public let partner: MemberDTO
    public let tasks: [TaskDTO]
    public let events: [EventDTO]
    public let wishes: [WishDTO]
    public let plan: PlanDTO
    public let expenses: [PlanExpenseDTO]
    public let steps: [PlanStepDTO]
    public let list: ChecklistListDTO
    public let shoppingList: ChecklistListDTO
    public let capsule: CapsuleDTO
    public let vote: VoteDTO
    public let people: [PersonDTO]
}

public enum PreviewSeed {
    private static let log = Logger(subsystem: CorbieIdentifiers.bundleID, category: "preview-seed")

    public static func make(now: Date = Date(), calendar: Calendar = .current) async throws -> PreviewSeedResult {
        try await seed(into: PersistenceController.inMemory(), now: now, calendar: calendar)
    }

    public static func seed(
        into controller: PersistenceController,
        now: Date = Date(),
        calendar: Calendar = .current
    ) async throws -> PreviewSeedResult {
        let repositories = controller.repositories
        let created = try await repositories.spaces.create(displayCurrency: "USD", creatorMemberId: nil, now: now)
        let me = try await repositories.members.upsertCurrentMember(
            appleUserId: "preview.me",
            spaceId: created.id,
            draft: MemberDraft(
                displayName: "Ilya",
                colorKey: MemberColorSlot.creatorDefault.rawValue,
                birthdayMonth: 3,
                birthdayDay: 14
            ),
            theme: .sand
        ).member
        let partner = try await repositories.members.upsertCurrentMember(
            appleUserId: "preview.partner",
            spaceId: created.id,
            draft: MemberDraft(
                displayName: "Sofia",
                colorKey: MemberColorSlot.partnerDefault.rawValue,
                birthdayMonth: 9,
                birthdayDay: 21
            ),
            theme: .sand
        ).member
        var space = try await repositories.spaces.space(id: created.id) ?? created
        space.togetherSince = day(offset: -460, from: now, calendar: calendar)
        space.weddingDate = day(offset: -120, from: now, calendar: calendar)
        space.creatorMemberId = me.id
        space = try await repositories.spaces.update(space)

        let tasks = try await seedTasks(repositories, spaceId: space.id, me: me, partner: partner, now: now, calendar: calendar)
        let events = try await seedEvents(repositories, spaceId: space.id, me: me, partner: partner, now: now, calendar: calendar)
        let wishes = try await seedWishes(repositories, spaceId: space.id, me: me, partner: partner, now: now)
        let plan = try await repositories.plans.create(
            PlanDraft(
                spaceId: space.id,
                title: "Lisbon in October",
                type: .trip,
                targetAmount: 5000,
                currency: "USD",
                savedAmount: 2400,
                startAt: day(offset: 30, from: now, calendar: calendar),
                endAt: day(offset: 44, from: now, calendar: calendar),
                note: "flights, hotel, food",
                createdByMemberId: me.id
            )
        )
        let expenses = [
            try await repositories.plans.addExpense(
                planId: plan.id,
                draft: PlanExpenseDraft(
                    amount: 640,
                    currency: "USD",
                    note: "flights",
                    date: day(offset: -12, from: now, calendar: calendar) ?? now,
                    addedByMemberId: me.id
                )
            ),
            try await repositories.plans.addExpense(
                planId: plan.id,
                draft: PlanExpenseDraft(
                    amount: 210,
                    currency: "EUR",
                    fxRateToPlanCurrency: 1.09,
                    note: "deposit",
                    date: day(offset: -4, from: now, calendar: calendar) ?? now,
                    addedByMemberId: partner.id
                )
            )
        ]
        let steps = try await seedPlanSteps(repositories, planId: plan.id, me: me, now: now, calendar: calendar)
        let list = try await seedPlacesList(repositories, spaceId: space.id, me: me, partner: partner)
        let shoppingList = try await seedShoppingList(repositories, spaceId: space.id, me: me, partner: partner)
        let capsule = try await repositories.capsules.create(
            CapsuleDraft(
                spaceId: space.id,
                authorMemberId: partner.id,
                recipientMemberId: me.id,
                title: "First year",
                body: "Read this when the leaves turn.",
                opensAt: day(offset: 186, from: now, calendar: calendar) ?? now
            ),
            now: now
        )
        let vote = try await repositories.votes.create(
            VoteDraft(
                spaceId: space.id,
                question: "Where do we eat on Friday",
                options: ["Ramen", "Pizza", "Home"],
                mode: .single,
                revealWhenBothAnswered: true,
                createdByMemberId: partner.id
            )
        )
        let people = try await seedPeople(repositories, spaceId: space.id, me: me, partner: partner)
        let stored = try await repositories.spaces.space(id: space.id) ?? space
        return PreviewSeedResult(
            controller: controller,
            space: stored,
            me: me,
            partner: partner,
            tasks: tasks,
            events: events,
            wishes: wishes,
            plan: plan,
            expenses: expenses,
            steps: steps,
            list: list,
            shoppingList: shoppingList,
            capsule: capsule,
            vote: vote,
            people: people
        )
    }

    private static func seedTasks(
        _ repositories: Repositories,
        spaceId: UUID,
        me: MemberDTO,
        partner: MemberDTO,
        now: Date,
        calendar: Calendar
    ) async throws -> [TaskDTO] {
        var result: [TaskDTO] = []
        result.append(
            try await repositories.tasks.create(
                TaskDraft(
                    spaceId: spaceId,
                    title: "Book the vet",
                    note: "phone, address, what to check",
                    assigneeMemberId: me.id,
                    dueAt: day(offset: 0, from: now, calendar: calendar),
                    createdByMemberId: me.id
                )
            )
        )
        result.append(
            try await repositories.tasks.create(
                TaskDraft(
                    spaceId: spaceId,
                    title: "Pick up the parcel",
                    assigneeMemberId: partner.id,
                    dueAt: day(offset: 2, from: now, calendar: calendar),
                    createdByMemberId: partner.id
                )
            )
        )
        result.append(
            try await repositories.tasks.create(
                TaskDraft(
                    spaceId: spaceId,
                    title: "Buy milk",
                    dueAt: day(offset: 1, from: now, calendar: calendar),
                    createdByMemberId: me.id
                )
            )
        )
        result.append(
            try await repositories.tasks.create(
                TaskDraft(
                    spaceId: spaceId,
                    title: "Water the plants",
                    assigneeMemberId: me.id,
                    dueAt: day(offset: 3, from: now, calendar: calendar),
                    recurrence: .weekdays([2, 5]),
                    createdByMemberId: me.id
                )
            )
        )
        let done = try await repositories.tasks.create(
            TaskDraft(
                spaceId: spaceId,
                title: "Call the landlord",
                assigneeMemberId: partner.id,
                dueAt: day(offset: -1, from: now, calendar: calendar),
                createdByMemberId: me.id
            )
        )
        let completion = try await repositories.tasks.markDone(
            taskId: done.id,
            memberId: partner.id,
            at: day(offset: -1, from: now, calendar: calendar) ?? now
        )
        result.append(completion.task)
        return result
    }

    private static func seedEvents(
        _ repositories: Repositories,
        spaceId: UUID,
        me: MemberDTO,
        partner: MemberDTO,
        now: Date,
        calendar: Calendar
    ) async throws -> [EventDTO] {
        var result: [EventDTO] = []
        let dinner = try await repositories.events.create(
            EventDraft(
                spaceId: spaceId,
                title: "Dinner with Anna",
                startAt: day(offset: 1, from: now, calendar: calendar) ?? now,
                endAt: day(offset: 1, from: now, calendar: calendar),
                kind: .event,
                locationName: "Casa do Alentejo",
                note: "table for four",
                reminderOffsets: [.dayBefore],
                createdByMemberId: me.id
            )
        )
        _ = try await repositories.events.addComment(
            eventId: dinner.id,
            memberId: partner.id,
            text: "I booked it for 19:30"
        )
        result.append(dinner)
        result.append(
            try await repositories.events.create(
                EventDraft(
                    spaceId: spaceId,
                    title: "Lisbon",
                    startAt: day(offset: 30, from: now, calendar: calendar) ?? now,
                    endAt: day(offset: 44, from: now, calendar: calendar),
                    isAllDay: true,
                    kind: .trip,
                    reminderOffsets: [.twoWeeksBefore, .threeDaysBefore],
                    createdByMemberId: partner.id
                )
            )
        )
        return result
    }

    private static func seedWishes(
        _ repositories: Repositories,
        spaceId: UUID,
        me: MemberDTO,
        partner: MemberDTO,
        now: Date
    ) async throws -> [WishDTO] {
        var result: [WishDTO] = []
        result.append(
            try await repositories.wishes.create(
                WishDraft(
                    spaceId: spaceId,
                    ownerMemberId: partner.id,
                    addedByMemberId: partner.id,
                    title: "Linen apron",
                    url: "https://example.com/apron",
                    price: 48,
                    currency: "USD",
                    priority: .must,
                    note: "size M, sand color",
                    source: .etsy
                )
            )
        )
        result.append(
            try await repositories.wishes.create(
                WishDraft(
                    spaceId: spaceId,
                    ownerMemberId: partner.id,
                    addedByMemberId: partner.id,
                    title: "Chemex filters",
                    price: 14.5,
                    currency: "USD",
                    priority: .want,
                    source: .amazon
                )
            )
        )
        result.append(
            try await repositories.wishes.create(
                WishDraft(
                    spaceId: spaceId,
                    ownerMemberId: me.id,
                    addedByMemberId: partner.id,
                    title: "Running belt",
                    price: 32,
                    currency: "USD",
                    priority: .someday,
                    source: .manual
                )
            )
        )
        return result
    }

    private static func seedPlanSteps(
        _ repositories: Repositories,
        planId: UUID,
        me: MemberDTO,
        now: Date,
        calendar: Calendar
    ) async throws -> [PlanStepDTO] {
        _ = try await repositories.plans.addStep(
            planId: planId,
            draft: PlanStepDraft(title: "Renew the passports", assigneeMemberId: me.id)
        )
        _ = try await repositories.plans.addStep(
            planId: planId,
            draft: PlanStepDraft(
                title: "Book the airport transfer",
                note: "two suitcases",
                dueAt: day(offset: 20, from: now, calendar: calendar)
            )
        )
        return try await repositories.plans.steps(planId: planId)
    }

    private static func seedPlacesList(
        _ repositories: Repositories,
        spaceId: UUID,
        me: MemberDTO,
        partner: MemberDTO
    ) async throws -> ChecklistListDTO {
        let list = try await repositories.lists.create(
            ChecklistDraft(
                spaceId: spaceId,
                title: "Places to go",
                subtitle: "Lisbon, this fall",
                template: .places,
                createdByMemberId: me.id
            )
        )
        _ = try await repositories.lists.addItem(
            listId: list.id,
            draft: ListItemDraft(
                title: "Time Out Market",
                note: "go early",
                placeName: "Time Out Market",
                address: "Av. 24 de Julho 49",
                latitude: 38.706,
                longitude: -9.145,
                addedByMemberId: me.id
            )
        )
        _ = try await repositories.lists.addItem(
            listId: list.id,
            draft: ListItemDraft(
                title: "Miradouro da Senhora do Monte",
                placeName: "Miradouro da Senhora do Monte",
                latitude: 38.719,
                longitude: -9.132,
                addedByMemberId: partner.id
            )
        )
        return try await repositories.lists.list(id: list.id) ?? list
    }

    private static func seedShoppingList(
        _ repositories: Repositories,
        spaceId: UUID,
        me: MemberDTO,
        partner: MemberDTO
    ) async throws -> ChecklistListDTO {
        let list = try await repositories.lists.pinnedShoppingList(
            spaceId: spaceId,
            title: "Shopping",
            createdByMemberId: me.id
        )
        for title in ["Milk", "Coffee", "Sourdough"] {
            _ = try await repositories.lists.addItem(
                listId: list.id,
                draft: ListItemDraft(title: title, addedByMemberId: partner.id)
            )
        }
        return try await repositories.lists.list(id: list.id) ?? list
    }


    private static func seedPeople(
        _ repositories: Repositories,
        spaceId: UUID,
        me: MemberDTO,
        partner: MemberDTO
    ) async throws -> [PersonDTO] {
        let anna = try await repositories.people.create(
            PersonDraft(
                spaceId: spaceId,
                name: "Anna",
                relation: "Mom",
                birthdayMonth: 10,
                birthdayDay: 12,
                ownerMemberId: partner.id,
                note: "loves ceramics"
            )
        )
        _ = try await repositories.people.addGiftIdea(
            personId: anna.id,
            draft: GiftIdeaDraft(title: "Ceramics workshop", price: 90, currency: "USD")
        )
        _ = try await repositories.people.addGiftIdea(
            personId: anna.id,
            draft: GiftIdeaDraft(title: "Wool scarf", price: 45, currency: "USD")
        )
        let mark = try await repositories.people.create(
            PersonDraft(
                spaceId: spaceId,
                name: "Mark",
                relation: "Friend",
                birthdayMonth: 2,
                birthdayDay: 29,
                ownerMemberId: me.id
            )
        )
        return try await repositories.people.people(spaceId: spaceId).filter { [anna.id, mark.id].contains($0.id) }
    }

    private static func day(offset: Int, from now: Date, calendar: Calendar) -> Date? {
        guard let shifted = calendar.date(byAdding: .day, value: offset, to: now) else { return nil }
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: shifted)
    }
}

extension PersistenceController {
    public static func previewSeeded(now: Date = Date(), calendar: Calendar = .current) async -> PersistenceController {
        let controller = PersistenceController.inMemory()
        do {
            _ = try await PreviewSeed.seed(into: controller, now: now, calendar: calendar)
        } catch {
            PreviewSeed.logSeedFailure(error)
        }
        return controller
    }
}

extension PreviewSeed {
    static func logSeedFailure(_ error: any Error) {
        log.error("preview seed failed: \(error.localizedDescription, privacy: .public)")
    }
}
#endif
