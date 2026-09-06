import Foundation

public enum RemoteChangeType: String, Sendable, Equatable, CaseIterable {
    case insert
    case update
    case delete
}

public struct RemoteChangeRecord: Sendable, Equatable {
    public let objectURI: URL
    public let type: RemoteChangeType
    public let properties: Set<String>
    public let author: String?
    public let contextName: String?

    public init(
        objectURI: URL,
        type: RemoteChangeType,
        properties: Set<String> = [],
        author: String? = nil,
        contextName: String? = nil
    ) {
        self.objectURI = objectURI
        self.type = type
        self.properties = properties
        self.author = author
        self.contextName = contextName
    }

    public var isFromAnotherDevice: Bool {
        guard let name = author ?? contextName, name.isEmpty == false else { return true }
        return TransactionAuthor(rawValue: name) == nil
    }
}
