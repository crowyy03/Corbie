#if canImport(AppIntents)
import AppIntents
import Foundation

@available(iOS 17.0, macOS 14.0, *)
public struct ToggleShoppingItemIntent: AppIntent {
    public static let title: LocalizedStringResource = "intent.shopping.toggle.title"
    public static let isDiscoverable = false

    @Parameter(title: "intent.shopping.parameter.id")
    public var itemID: String

    public init() {
        itemID = ""
    }

    public init(itemID: UUID) {
        self.itemID = itemID.uuidString
    }

    public func perform() async throws -> some IntentResult {
        try await TaskIntentRunner.toggleShoppingItem(itemId: TaskIntentRunner.identifier(itemID))
        return .result()
    }
}
#endif
