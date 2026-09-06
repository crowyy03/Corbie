import CorbieCore
import Observation
import SwiftUI

enum GoalStepAssignee: String, CaseIterable, Hashable, Identifiable {
    case nobody
    case me
    case partner

    var id: String { rawValue }
}

@MainActor
@Observable
final class GoalStepEditorViewModel {
    var title: String
    var note: String
    var assignee: GoalStepAssignee = .nobody
    var hasDue: Bool
    var dueAt: Date
    private(set) var isSaving = false
    private(set) var assigneeOptions: [GoalStepAssignee] = [.nobody, .me]
    private(set) var partnerName = ""

    @ObservationIgnored private let step: GoalStepDTO
    @ObservationIgnored private var environment: AppEnvironment?
    @ObservationIgnored private var didConfigure = false

    init(step: GoalStepDTO) {
        self.step = step
        title = step.title
        note = step.note ?? ""
        hasDue = step.dueAt != nil
        dueAt = step.dueAt ?? Date()
    }

    var canSave: Bool {
        isSaving == false && title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    func attach(_ environment: AppEnvironment) {
        self.environment = environment
        guard didConfigure == false else { return }
        didConfigure = true
        partnerName = environment.partnerName
        if let assigneeMemberId = step.assigneeMemberId {
            assignee = environment.isCurrentMember(assigneeMemberId) ? .me : .partner
        }
        if environment.isPaired || assignee == .partner {
            assigneeOptions = GoalStepAssignee.allCases
        }
    }

    func title(for assignee: GoalStepAssignee) -> String {
        switch assignee {
        case .nobody: String(localized: "goals.step.who.nobody")
        case .me: String(localized: "goals.step.who.me")
        case .partner: partnerName
        }
    }

    func save() async -> Bool {
        guard let environment, environment.premiumGate.require(.edit) else { return false }
        isSaving = true
        defer { isSaving = false }
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        var updated = step
        updated.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.note = trimmedNote.isEmpty ? nil : trimmedNote
        updated.assigneeMemberId = assigneeMemberId(in: environment)
        updated.dueAt = hasDue ? dueAt : nil
        do {
            _ = try await environment.repositories.goals.updateStep(updated)
            return true
        } catch {
            environment.report(error)
            return false
        }
    }

    private func assigneeMemberId(in environment: AppEnvironment) -> UUID? {
        switch assignee {
        case .nobody: nil
        case .me: environment.currentMember?.id
        case .partner: environment.partner?.id ?? step.assigneeMemberId
        }
    }
}
