import CoreData
import Foundation
import Testing
@testable import CorbieCore

@Suite struct ModelRulesTests {
    private let model = CorbieModel.shared

    @Test func modelHasEveryEntityFromTheSpec() {
        let expected: Set<String> = [
            "Space", "Member", "TaskItem", "Event", "EventComment", "Wish", "Plan",
            "PlanExpense", "PlanStep", "ChecklistList", "ListItem", "BusyInterval", "Capsule", "CapsuleOpen", "Vote",
            "VoteResponse", "Person", "GiftIdea", "PersonDate"
        ]
        #expect(Set(model.entities.compactMap(\.name)) == expected)
    }

    @Test func everyAttributeIsOptionalOrHasDefaultValue() {
        for entity in model.entities {
            for attribute in entity.attributesByName.values {
                let hasDefault = attribute.defaultValue != nil
                #expect(
                    attribute.isOptional || hasDefault,
                    "\(entity.name ?? "?").\(attribute.name) is required without a default value"
                )
            }
        }
    }

    @Test func noEntityUsesUniquenessConstraints() {
        for entity in model.entities {
            #expect(entity.uniquenessConstraints.isEmpty, "\(entity.name ?? "?") declares a uniqueness constraint")
        }
    }

    @Test func noRelationshipIsOrdered() {
        for entity in model.entities {
            for relationship in entity.relationshipsByName.values {
                #expect(relationship.isOrdered == false, "\(entity.name ?? "?").\(relationship.name) is ordered")
            }
        }
    }

    @Test func everyRelationshipHasAnInverse() {
        for entity in model.entities {
            for relationship in entity.relationshipsByName.values {
                let inverse = relationship.inverseRelationship
                #expect(inverse != nil, "\(entity.name ?? "?").\(relationship.name) has no inverse")
                #expect(inverse?.inverseRelationship?.name == relationship.name)
            }
        }
    }

    @Test func everyEntityHasAnIndexedUUIDIdentifier() {
        for entity in model.entities {
            let id = entity.attributesByName["id"]
            #expect(id?.attributeType == .UUIDAttributeType, "\(entity.name ?? "?") has no UUID id")
            let indexed = entity.indexes.contains { index in
                index.elements.contains { $0.propertyName == "id" }
            }
            #expect(indexed, "\(entity.name ?? "?").id is not indexed")
        }
    }

    @Test func everyEntityResolvesItsManagedObjectClass() {
        for entity in model.entities {
            let className = entity.managedObjectClassName ?? ""
            #expect(className.hasPrefix("CorbieCore."), "\(entity.name ?? "?") is not module qualified")
            #expect(NSClassFromString(className) != nil, "\(className) does not resolve")
        }
    }

    @Test func spaceOwnsItsChildrenAndChildrenNullifyBack() throws {
        let space = try #require(model.entitiesByName["Space"])
        let childNames = [
            "members", "tasks", "events", "wishes", "plans", "lists", "busyIntervals",
            "capsules", "votes", "people"
        ]
        for name in childNames {
            let relationship = try #require(space.relationshipsByName[name])
            #expect(relationship.deleteRule == .cascadeDeleteRule, "Space.\(name) does not cascade")
            #expect(relationship.isToMany)
            let inverse = try #require(relationship.inverseRelationship)
            #expect(inverse.deleteRule == .nullifyDeleteRule, "\(inverse.name) does not nullify")
            #expect(inverse.isToMany == false)
        }
    }

    @Test func parentsCascadeToTheirOwnChildren() throws {
        let owners = [
            ("Event", "comments"),
            ("Plan", "expenses"),
            ("Plan", "steps"),
            ("ChecklistList", "items"),
            ("Person", "giftIdeas"),
            ("Person", "dates"),
            ("Vote", "responses"),
            ("Capsule", "opens")
        ]
        for (entityName, relationshipName) in owners {
            let entity = try #require(model.entitiesByName[entityName])
            let relationship = try #require(entity.relationshipsByName[relationshipName])
            #expect(relationship.deleteRule == .cascadeDeleteRule, "\(entityName).\(relationshipName) does not cascade")
            #expect(relationship.inverseRelationship?.deleteRule == .nullifyDeleteRule)
        }
    }

    @Test func wishImageIsStoredExternally() throws {
        let wish = try #require(model.entitiesByName["Wish"])
        let image = try #require(wish.attributesByName["localImage"])
        #expect(image.attributeType == .binaryDataAttributeType)
        #expect(image.allowsExternalBinaryDataStorage)
    }

    @Test func jsonBackedAttributesAreBinary() throws {
        let pairs = [("VoteResponse", "optionIndexesData"), ("Member", "notificationPrefsData")]
        for (entityName, attributeName) in pairs {
            let entity = try #require(model.entitiesByName[entityName])
            let attribute = try #require(entity.attributesByName[attributeName])
            #expect(attribute.attributeType == .binaryDataAttributeType)
        }
    }

    @Test func voteAnswersAreOneRecordPerMember() throws {
        let vote = try #require(model.entitiesByName["Vote"])
        #expect(vote.attributesByName["responsesData"] == nil)
        let response = try #require(model.entitiesByName["VoteResponse"])
        #expect(response.attributesByName["memberId"]?.attributeType == .UUIDAttributeType)
        #expect(vote.relationshipsByName["responses"]?.destinationEntity?.name == "VoteResponse")
    }

    @Test func capsuleReadersAreOneRecordPerMember() throws {
        let capsule = try #require(model.entitiesByName["Capsule"])
        #expect(capsule.attributesByName["openedByMemberIdsData"] == nil)
        #expect(capsule.attributesByName["openedAt"] == nil)
        let open = try #require(model.entitiesByName["CapsuleOpen"])
        #expect(open.attributesByName["memberId"]?.attributeType == .UUIDAttributeType)
        #expect(open.attributesByName["openedAt"]?.attributeType == .dateAttributeType)
        #expect(capsule.relationshipsByName["opens"]?.destinationEntity?.name == "CapsuleOpen")
    }

    @Test func memberKeepsOnlyTheHashOfTheAppleIdentifier() throws {
        let member = try #require(model.entitiesByName["Member"])
        #expect(member.attributesByName["appleUserId"] == nil)
        #expect(member.attributesByName["appleUserHash"]?.attributeType == .stringAttributeType)
    }

    @Test func personDatesKeepTheirOwnDayAndRemindersFlag() throws {
        let personDate = try #require(model.entitiesByName["PersonDate"])
        #expect(personDate.attributesByName["title"]?.attributeType == .stringAttributeType)
        for name in ["month", "day", "year"] {
            let attribute = try #require(personDate.attributesByName[name])
            #expect(attribute.isOptional, "PersonDate.\(name) is required")
        }
        let reminders = try #require(personDate.attributesByName["remindersEnabled"])
        #expect(reminders.attributeType == .booleanAttributeType)
        #expect(reminders.defaultValue as? Bool == true)
        let person = try #require(model.entitiesByName["Person"])
        #expect(person.attributesByName["birthdayYear"]?.isOptional == true)
        #expect(person.relationshipsByName["dates"]?.destinationEntity?.name == "PersonDate")
        #expect(personDate.relationshipsByName["person"]?.destinationEntity?.name == "Person")
    }

    @Test func busyIntervalsCarryNoText() throws {
        let busy = try #require(model.entitiesByName["BusyInterval"])
        let textual = busy.attributesByName.values.filter { $0.attributeType == .stringAttributeType }
        #expect(textual.map(\.name) == ["sourceRaw"])
        #expect(busy.attributesByName["startAt"]?.attributeType == .dateAttributeType)
        #expect(busy.attributesByName["endAt"]?.attributeType == .dateAttributeType)
        #expect(busy.attributesByName["memberId"]?.attributeType == .UUIDAttributeType)
    }

    @Test func theTaskCarriesOnlyItsOwnFields() throws {
        let task = try #require(model.entitiesByName["TaskItem"])
        for name in ["placeName", "address", "lat", "lon", "sortIndex", "sourcePlanId"] {
            #expect(task.attributesByName[name] == nil, "TaskItem.\(name) came back")
        }
        #expect(task.relationshipsByName["folder"] == nil)
    }

    @Test func listItemsCarryTheirPlace() throws {
        let item = try #require(model.entitiesByName["ListItem"])
        for name in ["placeName", "address", "latitude", "longitude"] {
            #expect(item.attributesByName[name]?.isOptional == true, "ListItem.\(name) is required")
        }
        let sortIndex = try #require(item.attributesByName["sortIndex"])
        #expect(sortIndex.defaultValue as? Int == 0)
        #expect(item.relationshipsByName["list"]?.destinationEntity?.name == "ChecklistList")
    }

    @Test func memberCarriesTheBusyAndBadgeFields() throws {
        let member = try #require(model.entitiesByName["Member"])
        let shares = try #require(member.attributesByName["sharesBusyTimes"])
        #expect(shares.attributeType == .booleanAttributeType)
        #expect(shares.defaultValue as? Bool == false)
        #expect(member.attributesByName["lastRecapSeenAt"]?.attributeType == .dateAttributeType)
        #expect(member.attributesByName["lastUsVisitAt"]?.attributeType == .dateAttributeType)
    }

    @Test func recurrenceIsStoredAsString() throws {
        let task = try #require(model.entitiesByName["TaskItem"])
        let recurrence = try #require(task.attributesByName["recurrenceRaw"])
        #expect(recurrence.attributeType == .stringAttributeType)
        #expect(recurrence.defaultValue as? String == "none")
    }
}
