import CoreData
import Foundation
import Testing
@testable import CorbieCore

@Suite struct NetLegacyMirrorTests {
    private let now = NetTestSupport.date("2026-09-25T10:00:00Z")

    private static func prereleaseModel() -> NSManagedObjectModel {
        let model = CorbieModel.build()
        guard let space = model.entitiesByName[Space.entityName] else { return model }
        space.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        let kept = space.properties.filter { $0.name.hasPrefix("productionSubscription") == false }
        let status = NSAttributeDescription()
        status.name = "subscriptionStatusRaw"
        status.attributeType = .stringAttributeType
        status.isOptional = true
        status.defaultValue = SubscriptionStatus.none.rawValue
        let expiry = NSAttributeDescription()
        expiry.name = "subscriptionExpiresAt"
        expiry.attributeType = .dateAttributeType
        expiry.isOptional = true
        space.properties = kept + [status, expiry]
        return model
    }

    @Test func theMirrorLivesInFieldsThatOnlyThisVersionWrites() throws {
        let attributes = try #require(CorbieModel.shared.entitiesByName[Space.entityName]?.attributesByName)
        #expect(attributes["productionSubscriptionStatusRaw"] != nil)
        #expect(attributes["productionSubscriptionExpiresAt"] != nil)
        #expect(attributes["subscriptionStatusRaw"] == nil)
        #expect(attributes["subscriptionExpiresAt"] == nil)
    }

    @Test func aMirrorWrittenByAnOlderBuildIsNeverReadAsPaid() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("corbie-legacy-mirror-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let spaceId = UUID()

        let older = NSPersistentContainer(name: CorbieModel.name, managedObjectModel: Self.prereleaseModel())
        older.persistentStoreDescriptions = CoreDataStack.storeDescriptions(in: directory, mirroring: .disabled)
        var loadError: (any Error)?
        older.loadPersistentStores { _, error in loadError = loadError ?? error }
        #expect(loadError == nil)
        let context = older.viewContext
        try context.performAndWait {
            let space = NSEntityDescription.insertNewObject(forEntityName: Space.entityName, into: context)
            space.setValue(spaceId, forKey: "id")
            space.setValue(SubscriptionStatus.active.rawValue, forKey: "subscriptionStatusRaw")
            space.setValue(now.addingTimeInterval(365 * 86_400), forKey: "subscriptionExpiresAt")
            try context.save()
        }
        for store in older.persistentStoreCoordinator.persistentStores {
            try older.persistentStoreCoordinator.remove(store)
        }

        let current = PersistenceController(stack: CoreDataStack(storesIn: directory))
        #expect(current.stack.loadFailure == nil)
        let space = try #require(try await current.repositories.spaces.space(id: spaceId))
        #expect(space.subscriptionStatus == SubscriptionStatus.none)
        #expect(space.subscriptionExpiresAt == nil)
        #expect(WidgetPremiumRule.isPremium(space: space, now: now, monetizationEnabled: true) == false)
        #expect(
            EntitlementResolver.resolve(EntitlementInputs(space: MirroredEntitlement(space: space), now: now)) == .readOnly
        )
    }
}
