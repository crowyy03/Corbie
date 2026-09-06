#if canImport(AppIntents)
import AppIntents
import Foundation

@available(iOS 17.0, macOS 14.0, *)
public struct ToggleTaskDoneIntent: AppIntent {
    public static let title: LocalizedStringResource = "intent.task.done.title"
    public static let isDiscoverable = false

    @Parameter(title: "intent.task.parameter.id")
    public var taskID: String

    public init() {
        taskID = ""
    }

    public init(taskID: UUID) {
        self.taskID = taskID.uuidString
    }

    public func perform() async throws -> some IntentResult {
        try await TaskIntentRunner.markDone(
            taskId: TaskIntentRunner.identifier(taskID),
            notifications: IntentNotifications.client()
        )
        return .result()
    }
}
#endif
