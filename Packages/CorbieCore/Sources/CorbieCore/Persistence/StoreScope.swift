import Foundation

public enum StoreScope: String, Sendable, CaseIterable {
    case privateStore = "private"
    case sharedStore = "shared"

    public var fileName: String { rawValue + ".sqlite" }
}

public enum TransactionAuthor: String, Sendable, CaseIterable {
    case app
    case widgets
    case share
    case tests
}
