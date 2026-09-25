#if canImport(AppIntents)
import AppIntents
import Foundation

public struct ToggleTaskDoneIntent: AppIntent, ForegroundContinuableIntent {
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
        guard await TaskIntentRunner.isReadOnly() == false else { throw continueOnThePaywall() }
        try await TaskIntentRunner.markDone(
            taskId: TaskIntentRunner.identifier(taskID),
            notifications: IntentNotifications.client()
        )
        return .result()
    }
}
#endif
