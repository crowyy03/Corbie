#if canImport(AppIntents)
import AppIntents
import Foundation

public struct TakeTaskIntent: AppIntent, ForegroundContinuableIntent {
    public static let title: LocalizedStringResource = "intent.task.take.title"
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
        try await TaskIntentRunner.take(taskId: TaskIntentRunner.identifier(taskID))
        return .result()
    }
}
#endif
