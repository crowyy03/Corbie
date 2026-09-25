#if canImport(AppIntents)
import AppIntents
import Foundation

public struct ToggleShoppingItemIntent: AppIntent, ForegroundContinuableIntent {
    public static let title: LocalizedStringResource = "intent.shopping.toggle.title"
    public static let isDiscoverable = false

    @Parameter(title: "intent.shopping.parameter.id")
    public var itemID: String

    @Parameter(title: "intent.shopping.parameter.showedchecked", default: false)
    public var showedChecked: Bool

    public init() {
        itemID = ""
        showedChecked = false
    }

    public init(itemID: UUID, showedChecked: Bool) {
        self.itemID = itemID.uuidString
        self.showedChecked = showedChecked
    }

    public func perform() async throws -> some IntentResult {
        guard await TaskIntentRunner.isReadOnly() == false else { throw continueOnThePaywall() }
        try await TaskIntentRunner.toggleShoppingItem(
            itemId: TaskIntentRunner.identifier(itemID),
            showedChecked: showedChecked
        )
        return .result()
    }
}
#endif
