#if canImport(AppIntents)
import AppIntents
import Foundation

@available(iOS 17.0, macOS 14.0, *)
public struct ToggleGoalStepIntent: AppIntent {
    public static let title: LocalizedStringResource = "intent.goalstep.toggle.title"
    public static let isDiscoverable = false

    @Parameter(title: "intent.goalstep.parameter.id")
    public var stepID: String

    public init() {
        stepID = ""
    }

    public init(stepID: UUID) {
        self.stepID = stepID.uuidString
    }

    public func perform() async throws -> some IntentResult {
        try await TaskIntentRunner.toggleGoalStep(stepId: TaskIntentRunner.identifier(stepID))
        return .result()
    }
}
#endif
