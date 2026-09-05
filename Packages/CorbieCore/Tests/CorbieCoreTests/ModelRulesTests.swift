import CoreData
import Foundation
import Testing
@testable import CorbieCore

@Suite struct ModelRulesTests {
    private let model = CorbieModel.shared

    @Test func modelHasEveryEntityFromTheSpec() {
        let expected: Set<String> = [
            "Space", "Member", "TaskItem", "Event", "EventComment", "Wish", "Plan",
            "PlanExpense", "ChecklistList", "ListItem", "Capsule", "CapsuleOpen", "Vote",
            "VoteResponse", "Person", "GiftIdea"
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
        let childNames = ["members", "tasks", "events", "wishes", "plans", "lists", "capsules", "votes", "people"]
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
            ("ChecklistList", "items"),
            ("Person", "giftIdeas"),
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

    @Test func recurrenceIsStoredAsString() throws {
        let task = try #require(model.entitiesByName["TaskItem"])
        let recurrence = try #require(task.attributesByName["recurrenceRaw"])
        #expect(recurrence.attributeType == .stringAttributeType)
        #expect(recurrence.defaultValue as? String == "none")
    }
}
