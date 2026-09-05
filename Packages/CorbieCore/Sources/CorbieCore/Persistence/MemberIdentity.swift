import CoreData
import Foundation

public final class MemberIdentity: Sendable {
    public static let appleUserIDKey = "apple.user.id"

    private let store: any SecretStore

    public init(store: any SecretStore = KeychainStore()) {
        self.store = store
    }

    public var currentAppleUserID: String? {
        try? store.string(for: MemberIdentity.appleUserIDKey)
    }

    public func setAppleUserID(_ value: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            throw CorbieError.invalidInput("apple user id is empty")
        }
        try store.setString(trimmed, for: MemberIdentity.appleUserIDKey)
    }

    public func clear() throws {
        try store.removeValue(for: MemberIdentity.appleUserIDKey)
    }

    public func currentMember(in stack: CoreDataStack) async throws -> MemberDTO? {
        guard let appleUserID = currentAppleUserID else { return nil }
        let repository = CoreDataMemberRepository(stack: stack)
        return try await repository.member(appleUserId: appleUserID)
    }
}
