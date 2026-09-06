#if canImport(AppIntents)
import AppIntents
import Foundation

@available(iOS 17.0, macOS 14.0, *)
public struct ToggleShoppingItemIntent: AppIntent {
    public static let title: LocalizedStringResource = "intent.shopping.toggle.title"
    public static let isDiscoverable = false

    @Parameter(title: "intent.shopping.parameter.id")
    public var taskID: String

    public init() {
        taskID = ""
    }

    public init(taskID: UUID) {
        self.taskID = taskID.uuidString
    }

    public func perform() async throws -> some IntentResult {
        try await TaskIntentRunner.toggleShoppingItem(taskId: TaskIntentRunner.identifier(taskID))
        return .result()
    }
}
#endif
