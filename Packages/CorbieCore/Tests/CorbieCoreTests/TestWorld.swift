import CoreData
import Foundation
@testable import CorbieCore

struct TestWorld {
    let controller: PersistenceController
    let space: SpaceDTO
    let me: MemberDTO
    let partner: MemberDTO

    var repositories: Repositories { controller.repositories }

    static func make(withPartner: Bool = true) async throws -> TestWorld {
        let controller = PersistenceController.inMemory()
        let repositories = controller.repositories
        let space = try await repositories.spaces.create(displayCurrency: "USD")
        let me = try await repositories.members.upsertCurrentMember(
            appleUserId: "apple-me",
            spaceId: space.id,
            draft: MemberDraft(displayName: "Ilya", colorKey: MemberColorSlot.creatorDefault.rawValue),
            theme: .sand
        ).member
        let partner: MemberDTO
        if withPartner {
            partner = try await repositories.members.upsertCurrentMember(
                appleUserId: "apple-partner",
                spaceId: space.id,
                draft: MemberDraft(displayName: "Sofia", colorKey: MemberColorSlot.partnerDefault.rawValue),
                theme: .sand
            ).member
        } else {
            partner = me
        }
        let updated = try await repositories.spaces.space(id: space.id) ?? space
        return TestWorld(controller: controller, space: updated, me: me, partner: partner)
    }

    func count(_ entityName: String) throws -> Int {
        let context = controller.viewContext
        return try context.performAndWait {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            return try context.count(for: request)
        }
    }
}

final class ReloadCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func increment() {
        lock.lock()
        value += 1
        lock.unlock()
    }
}

final class InMemorySecretStore: SecretStore, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Data] = [:]

    func data(for key: String) throws -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }

    func setData(_ value: Data, for key: String) throws {
        lock.lock()
        storage[key] = value
        lock.unlock()
    }

    func removeValue(for key: String) throws {
        lock.lock()
        storage.removeValue(forKey: key)
        lock.unlock()
    }
}
