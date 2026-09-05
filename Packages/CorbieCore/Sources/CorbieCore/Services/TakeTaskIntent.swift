#if canImport(AppIntents)
import AppIntents
import Foundation

@available(iOS 17.0, macOS 14.0, *)
public struct TakeTaskIntent: AppIntent {
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
        try await TaskIntentRunner.take(taskId: TaskIntentRunner.identifier(taskID))
        return .result()
    }
}
#endif
