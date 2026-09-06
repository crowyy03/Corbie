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

        let folder = ModelEntity(TaskFolder.entityName, TaskFolder.self)
        folder.attribute("title", .stringAttributeType)
        folder.attribute("subtitle", .stringAttributeType)
        folder.attribute("templateRaw", .stringAttributeType, defaultValue: FolderTemplate.empty.rawValue)
        folder.attribute("anyoneCanCheck", .booleanAttributeType, optional: false, defaultValue: true)
        folder.attribute("isPinnedShopping", .booleanAttributeType, optional: false, defaultValue: false)
        folder.attribute("sortIndex", .integer32AttributeType, optional: false, defaultValue: 0)
        folder.attribute("createdByMemberId", .UUIDAttributeType)
        folder.attribute("createdAt", .dateAttributeType)

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
        task.attribute("placeName", .stringAttributeType)
        task.attribute("address", .stringAttributeType)
        task.attribute("lat", .doubleAttributeType)
        task.attribute("lon", .doubleAttributeType)
        task.attribute("sortIndex", .integer32AttributeType, optional: false, defaultValue: 0)
        task.attribute("sourceGoalId", .UUIDAttributeType)
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

        let goal = ModelEntity(Goal.entityName, Goal.self)
        goal.attribute("title", .stringAttributeType)
        goal.attribute("typeRaw", .stringAttributeType, defaultValue: GoalType.other.rawValue)
        goal.attribute("targetAmount", .doubleAttributeType, optional: false, defaultValue: 0.0)
        goal.attribute("currency", .stringAttributeType, defaultValue: "USD")
        goal.attribute("savedAmount", .doubleAttributeType, optional: false, defaultValue: 0.0)
        goal.attribute("startAt", .dateAttributeType)
        goal.attribute("endAt", .dateAttributeType)
        goal.attribute("statusRaw", .stringAttributeType, defaultValue: GoalStatus.active.rawValue)
        goal.attribute("createdByMemberId", .UUIDAttributeType)
        goal.attribute("note", .stringAttributeType)
        goal.attribute("createdAt", .dateAttributeType)

        let expense = ModelEntity(GoalExpense.entityName, GoalExpense.self)
        expense.attribute("amount", .doubleAttributeType, optional: false, defaultValue: 0.0)
        expense.attribute("currency", .stringAttributeType)
        expense.attribute("fxRateToGoalCurrency", .doubleAttributeType, optional: false, defaultValue: 1.0)
        expense.attribute("amountInGoalCurrency", .doubleAttributeType, optional: false, defaultValue: 0.0)
        expense.attribute("note", .stringAttributeType)
        expense.attribute("date", .dateAttributeType)
        expense.attribute("addedByMemberId", .UUIDAttributeType)
        expense.attribute("createdAt", .dateAttributeType)

        let step = ModelEntity(GoalStep.entityName, GoalStep.self)
        step.attribute("title", .stringAttributeType)
        step.attribute("note", .stringAttributeType)
        step.attribute("isDone", .booleanAttributeType, optional: false, defaultValue: false)
        step.attribute("doneByMemberId", .UUIDAttributeType)
        step.attribute("doneAt", .dateAttributeType)
        step.attribute("assigneeMemberId", .UUIDAttributeType)
        step.attribute("dueAt", .dateAttributeType)
        step.attribute("sortIndex", .integer32AttributeType, optional: false, defaultValue: 0)
        step.attribute("createdAt", .dateAttributeType)

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
        space.owns(folder, many: "folders", inverse: "space")
        space.owns(event, many: "events", inverse: "space")
        space.owns(wish, many: "wishes", inverse: "space")
        space.owns(goal, many: "goals", inverse: "space")
        space.owns(busy, many: "busyIntervals", inverse: "space")
        space.owns(capsule, many: "capsules", inverse: "space")
        space.owns(vote, many: "votes", inverse: "space")
        space.owns(person, many: "people", inverse: "space")
        folder.keeps(task, many: "tasks", inverse: "folder")
        event.owns(comment, many: "comments", inverse: "event")
        capsule.owns(capsuleOpen, many: "opens", inverse: "capsule")
        vote.owns(voteResponse, many: "responses", inverse: "vote")
        goal.owns(expense, many: "expenses", inverse: "goal")
        goal.owns(step, many: "steps", inverse: "goal")
        person.owns(giftIdea, many: "giftIdeas", inverse: "person")
        person.owns(personDate, many: "dates", inverse: "person")

        let builders = [
            space, member, folder, task, event, comment, wish, goal, expense, step, busy,
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

    func keeps(_ child: ModelEntity, many name: String, inverse: String) {
        relate(child, many: name, inverse: inverse, deleteRule: .nullifyDeleteRule)
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
