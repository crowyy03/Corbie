import CoreData
import Foundation

public enum CorbieModel {
    public static let name = "Corbie"

    nonisolated(unsafe) public static let shared: NSManagedObjectModel = build()

    public static func build() -> NSManagedObjectModel {
        let space = ModelEntity(Space.entityName, Space.self)
        space.attribute("createdAt", .dateAttributeType)
        space.attribute("creatorMemberId", .UUIDAttributeType)
        space.attribute("togetherSince", .dateAttributeType)
        space.attribute("weddingDate", .dateAttributeType)
        space.attribute("displayCurrency", .stringAttributeType, defaultValue: "USD")
        space.attribute("trialEndsAt", .dateAttributeType)
        space.attribute("subscriptionStatusRaw", .stringAttributeType, defaultValue: SubscriptionStatus.trial.rawValue)
        space.attribute("subscriptionExpiresAt", .dateAttributeType)
        space.attribute("subscriptionPayerMemberId", .UUIDAttributeType)

        let member = ModelEntity(Member.entityName, Member.self)
        member.attribute("appleUserHash", .stringAttributeType)
        member.attribute("displayName", .stringAttributeType)
        member.attribute("colorKey", .stringAttributeType)
        member.attribute("birthdayMonth", .integer16AttributeType)
        member.attribute("birthdayDay", .integer16AttributeType)
        member.attribute("joinedAt", .dateAttributeType)
        member.attribute("lastSeenAt", .dateAttributeType)
        member.attribute("sharesBusyTimes", .booleanAttributeType, optional: false, defaultValue: false)
        member.attribute("lastRecapSeenAt", .dateAttributeType)
        member.attribute("lastUsVisitAt", .dateAttributeType)
        member.attribute("notificationPrefsData", .binaryDataAttributeType)

        let task = ModelEntity(TaskItem.entityName, TaskItem.self)
        task.attribute("title", .stringAttributeType)
        task.attribute("note", .stringAttributeType)
        task.attribute("assigneeMemberId", .UUIDAttributeType)
        task.attribute("dueAt", .dateAttributeType)
        task.attribute("isDone", .booleanAttributeType, optional: false, defaultValue: false)
        task.attribute("doneByMemberId", .UUIDAttributeType)
        task.attribute("doneAt", .dateAttributeType)
        task.attribute("createdByMemberId", .UUIDAttributeType)
        task.attribute("takenAt", .dateAttributeType)
        task.attribute("recurrenceRaw", .stringAttributeType, defaultValue: Recurrence.none.rawValue)
        task.attribute("archivedAt", .dateAttributeType)
        task.attribute("createdAt", .dateAttributeType)

        let event = ModelEntity(Event.entityName, Event.self)
        event.attribute("title", .stringAttributeType)
        event.attribute("startAt", .dateAttributeType)
        event.attribute("endAt", .dateAttributeType)
        event.attribute("isAllDay", .booleanAttributeType, optional: false, defaultValue: false)
        event.attribute("kindRaw", .stringAttributeType, defaultValue: EventKind.event.rawValue)
        event.attribute("personId", .UUIDAttributeType)
        event.attribute("locationName", .stringAttributeType)
        event.attribute("address", .stringAttributeType)
        event.attribute("latitude", .doubleAttributeType)
        event.attribute("longitude", .doubleAttributeType)
        event.attribute("note", .stringAttributeType)
        event.attribute("reminderOffsetsData", .binaryDataAttributeType)
        event.attribute("createdByMemberId", .UUIDAttributeType)
        event.attribute("createdAt", .dateAttributeType)

        let comment = ModelEntity(EventComment.entityName, EventComment.self)
        comment.attribute("memberId", .UUIDAttributeType)
        comment.attribute("text", .stringAttributeType)
        comment.attribute("createdAt", .dateAttributeType)

        let wish = ModelEntity(Wish.entityName, Wish.self)
        wish.attribute("ownerMemberId", .UUIDAttributeType)
        wish.attribute("addedByMemberId", .UUIDAttributeType)
        wish.attribute("title", .stringAttributeType)
        wish.attribute("url", .stringAttributeType)
        wish.attribute("imageURL", .stringAttributeType)
        wish.attribute("localImage", .binaryDataAttributeType, external: true)
        wish.attribute("price", .doubleAttributeType)
        wish.attribute("currency", .stringAttributeType)
        wish.attribute("priorityRaw", .stringAttributeType, defaultValue: WishPriority.want.rawValue)
        wish.attribute("note", .stringAttributeType)
        wish.attribute("sourceRaw", .stringAttributeType, defaultValue: WishSource.manual.rawValue)
        wish.attribute("isFulfilled", .booleanAttributeType, optional: false, defaultValue: false)
        wish.attribute("fulfilledAt", .dateAttributeType)
        wish.attribute("needsParse", .booleanAttributeType, optional: false, defaultValue: false)
        wish.attribute("createdAt", .dateAttributeType)

        let plan = ModelEntity(Plan.entityName, Plan.self)
        plan.attribute("title", .stringAttributeType)
        plan.attribute("typeRaw", .stringAttributeType, defaultValue: PlanType.other.rawValue)
        plan.attribute("targetAmount", .doubleAttributeType, optional: false, defaultValue: 0.0)
        plan.attribute("currency", .stringAttributeType, defaultValue: "USD")
        plan.attribute("savedAmount", .doubleAttributeType, optional: false, defaultValue: 0.0)
        plan.attribute("startAt", .dateAttributeType)
        plan.attribute("endAt", .dateAttributeType)
        plan.attribute("statusRaw", .stringAttributeType, defaultValue: PlanStatus.active.rawValue)
        plan.attribute("createdByMemberId", .UUIDAttributeType)
        plan.attribute("note", .stringAttributeType)
        plan.attribute("createdAt", .dateAttributeType)

        let expense = ModelEntity(PlanExpense.entityName, PlanExpense.self)
        expense.attribute("amount", .doubleAttributeType, optional: false, defaultValue: 0.0)
        expense.attribute("currency", .stringAttributeType)
        expense.attribute("fxRateToPlanCurrency", .doubleAttributeType, optional: false, defaultValue: 1.0)
        expense.attribute("amountInPlanCurrency", .doubleAttributeType, optional: false, defaultValue: 0.0)
        expense.attribute("note", .stringAttributeType)
        expense.attribute("date", .dateAttributeType)
        expense.attribute("addedByMemberId", .UUIDAttributeType)
        expense.attribute("createdAt", .dateAttributeType)

        let step = ModelEntity(PlanStep.entityName, PlanStep.self)
        step.attribute("title", .stringAttributeType)
        step.attribute("note", .stringAttributeType)
        step.attribute("isDone", .booleanAttributeType, optional: false, defaultValue: false)
        step.attribute("doneByMemberId", .UUIDAttributeType)
        step.attribute("doneAt", .dateAttributeType)
        step.attribute("assigneeMemberId", .UUIDAttributeType)
        step.attribute("dueAt", .dateAttributeType)
        step.attribute("sortIndex", .integer32AttributeType, optional: false, defaultValue: 0)
        step.attribute("createdAt", .dateAttributeType)

        let list = ModelEntity(ChecklistList.entityName, ChecklistList.self)
        list.attribute("title", .stringAttributeType)
        list.attribute("subtitle", .stringAttributeType)
        list.attribute("templateRaw", .stringAttributeType, defaultValue: ListTemplate.empty.rawValue)
        list.attribute("anyoneCanCheck", .booleanAttributeType, optional: false, defaultValue: true)
        list.attribute("isPinnedShopping", .booleanAttributeType, optional: false, defaultValue: false)
        list.attribute("createdByMemberId", .UUIDAttributeType)
        list.attribute("createdAt", .dateAttributeType)

        let listItem = ModelEntity(ListItem.entityName, ListItem.self)
        listItem.attribute("title", .stringAttributeType)
        listItem.attribute("isChecked", .booleanAttributeType, optional: false, defaultValue: false)
        listItem.attribute("checkedByMemberId", .UUIDAttributeType)
        listItem.attribute("checkedAt", .dateAttributeType)
        listItem.attribute("addedByMemberId", .UUIDAttributeType)
        listItem.attribute("note", .stringAttributeType)
        listItem.attribute("placeName", .stringAttributeType)
        listItem.attribute("address", .stringAttributeType)
        listItem.attribute("latitude", .doubleAttributeType)
        listItem.attribute("longitude", .doubleAttributeType)
        listItem.attribute("sortIndex", .integer32AttributeType, optional: false, defaultValue: 0)
        listItem.attribute("createdAt", .dateAttributeType)

        let busy = ModelEntity(BusyInterval.entityName, BusyInterval.self)
        busy.attribute("memberId", .UUIDAttributeType)
        busy.attribute("startAt", .dateAttributeType)
        busy.attribute("endAt", .dateAttributeType)
        busy.attribute("sourceRaw", .stringAttributeType, defaultValue: BusyIntervalSource.device.rawValue)
        busy.attribute("updatedAt", .dateAttributeType)

        let capsule = ModelEntity(CapsuleItem.entityName, CapsuleItem.self)
        capsule.attribute("authorMemberId", .UUIDAttributeType)
        capsule.attribute("recipientMemberId", .UUIDAttributeType)
        capsule.attribute("title", .stringAttributeType)
        capsule.attribute("body", .stringAttributeType)
        capsule.attribute("opensAt", .dateAttributeType)
        capsule.attribute("createdAt", .dateAttributeType)

        let capsuleOpen = ModelEntity(CapsuleOpen.entityName, CapsuleOpen.self)
        capsuleOpen.attribute("memberId", .UUIDAttributeType)
        capsuleOpen.attribute("openedAt", .dateAttributeType)

        let vote = ModelEntity(Vote.entityName, Vote.self)
        vote.attribute("question", .stringAttributeType)
        vote.attribute("optionsData", .binaryDataAttributeType)
        vote.attribute("modeRaw", .stringAttributeType, defaultValue: VoteMode.single.rawValue)
        vote.attribute("createdByMemberId", .UUIDAttributeType)
        vote.attribute("revealWhenBothAnswered", .booleanAttributeType, optional: false, defaultValue: true)
        vote.attribute("revealedAt", .dateAttributeType)
        vote.attribute("createdAt", .dateAttributeType)

        let voteResponse = ModelEntity(VoteResponse.entityName, VoteResponse.self)
        voteResponse.attribute("memberId", .UUIDAttributeType)
        voteResponse.attribute("optionIndexesData", .binaryDataAttributeType)
        voteResponse.attribute("answeredAt", .dateAttributeType)

        let person = ModelEntity(Person.entityName, Person.self)
        person.attribute("name", .stringAttributeType)
        person.attribute("relation", .stringAttributeType)
        person.attribute("birthdayMonth", .integer16AttributeType)
        person.attribute("birthdayDay", .integer16AttributeType)
        person.attribute("birthdayYear", .integer32AttributeType)
        person.attribute("ownerMemberId", .UUIDAttributeType)
        person.attribute("note", .stringAttributeType)
        person.attribute("createdAt", .dateAttributeType)

        let personDate = ModelEntity(PersonDate.entityName, PersonDate.self)
        personDate.attribute("title", .stringAttributeType)
        personDate.attribute("month", .integer16AttributeType)
        personDate.attribute("day", .integer16AttributeType)
        personDate.attribute("year", .integer32AttributeType)
        personDate.attribute("remindersEnabled", .booleanAttributeType, optional: false, defaultValue: true)
        personDate.attribute("createdAt", .dateAttributeType)

        let giftIdea = ModelEntity(GiftIdea.entityName, GiftIdea.self)
        giftIdea.attribute("title", .stringAttributeType)
        giftIdea.attribute("url", .stringAttributeType)
        giftIdea.attribute("price", .doubleAttributeType)
        giftIdea.attribute("currency", .stringAttributeType)
        giftIdea.attribute("note", .stringAttributeType)
        giftIdea.attribute("isDone", .booleanAttributeType, optional: false, defaultValue: false)
        giftIdea.attribute("createdAt", .dateAttributeType)

        space.owns(member, many: "members", inverse: "space")
        space.owns(task, many: "tasks", inverse: "space")
        space.owns(event, many: "events", inverse: "space")
        space.owns(wish, many: "wishes", inverse: "space")
        space.owns(plan, many: "plans", inverse: "space")
        space.owns(list, many: "lists", inverse: "space")
        space.owns(busy, many: "busyIntervals", inverse: "space")
        space.owns(capsule, many: "capsules", inverse: "space")
        space.owns(vote, many: "votes", inverse: "space")
        space.owns(person, many: "people", inverse: "space")
        event.owns(comment, many: "comments", inverse: "event")
        capsule.owns(capsuleOpen, many: "opens", inverse: "capsule")
        vote.owns(voteResponse, many: "responses", inverse: "vote")
        plan.owns(expense, many: "expenses", inverse: "plan")
        plan.owns(step, many: "steps", inverse: "plan")
        list.owns(listItem, many: "items", inverse: "list")
        person.owns(giftIdea, many: "giftIdeas", inverse: "person")
        person.owns(personDate, many: "dates", inverse: "person")

        let builders = [
            space, member, task, event, comment, wish, plan, expense, step, list, listItem, busy,
            capsule, capsuleOpen, vote, voteResponse, person, giftIdea, personDate
        ]
        let model = NSManagedObjectModel()
        model.entities = builders.map { $0.finish() }
        return model
    }
}

private final class ModelEntity {
    let entity = NSEntityDescription()
    private var properties: [NSPropertyDescription] = []
    private let idAttribute: NSAttributeDescription

    init(_ name: String, _ managedObjectClass: AnyClass) {
        entity.name = name
        entity.managedObjectClassName = NSStringFromClass(managedObjectClass)
        idAttribute = NSAttributeDescription()
        idAttribute.name = "id"
        idAttribute.attributeType = .UUIDAttributeType
        idAttribute.isOptional = true
        properties.append(idAttribute)
    }

    func attribute(
        _ name: String,
        _ type: NSAttributeType,
        optional: Bool = true,
        defaultValue: Any? = nil,
        external: Bool = false
    ) {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        attribute.defaultValue = defaultValue
        attribute.allowsExternalBinaryDataStorage = external
        properties.append(attribute)
    }

    func owns(_ child: ModelEntity, many name: String, inverse: String) {
        relate(child, many: name, inverse: inverse, deleteRule: .cascadeDeleteRule)
    }

    private func relate(
        _ child: ModelEntity,
        many name: String,
        inverse: String,
        deleteRule: NSDeleteRule
    ) {
        let toMany = NSRelationshipDescription()
        toMany.name = name
        toMany.destinationEntity = child.entity
        toMany.minCount = 0
        toMany.maxCount = 0
        toMany.deleteRule = deleteRule
        toMany.isOptional = true
        toMany.isOrdered = false

        let toOne = NSRelationshipDescription()
        toOne.name = inverse
        toOne.destinationEntity = entity
        toOne.minCount = 0
        toOne.maxCount = 1
        toOne.deleteRule = .nullifyDeleteRule
        toOne.isOptional = true
        toOne.isOrdered = false

        toMany.inverseRelationship = toOne
        toOne.inverseRelationship = toMany
        properties.append(toMany)
        child.properties.append(toOne)
    }

    func finish() -> NSEntityDescription {
        entity.properties = properties
        let element = NSFetchIndexElementDescription(property: idAttribute, collationType: .binary)
        let index = NSFetchIndexDescription(name: "by_id", elements: [element])
        entity.indexes = [index]
        return entity
    }
}
