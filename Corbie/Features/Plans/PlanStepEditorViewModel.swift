import CorbieCore
import Observation
import SwiftUI

enum PlanStepAssignee: String, CaseIterable, Hashable, Identifiable {
    case nobody
    case me
    case partner

    var id: String { rawValue }
}

@MainActor
@Observable
final class PlanStepEditorViewModel {
    var title: String
    var note: String
    var assignee: PlanStepAssignee = .nobody
    var hasDue: Bool
    var dueAt: Date
    private(set) var isSaving = false
    private(set) var assigneeOptions: [PlanStepAssignee] = [.nobody, .me]
    private(set) var partnerName = ""

    @ObservationIgnored private let step: PlanStepDTO
    @ObservationIgnored private var loadedAssignee: PlanStepAssignee = .nobody
    @ObservationIgnored private let loadedDue: (hasDue: Bool, dueAt: Date)
    @ObservationIgnored private var environment: AppEnvironment?
    @ObservationIgnored private var didConfigure = false

    init(step: PlanStepDTO) {
        self.step = step
        title = step.title
        note = step.note ?? ""
        let loadedDue = (hasDue: step.dueAt != nil, dueAt: step.dueAt ?? Date())
        hasDue = loadedDue.hasDue
        dueAt = loadedDue.dueAt
        self.loadedDue = loadedDue
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
        loadedAssignee = assignee
        if environment.isPaired || assignee == .partner {
            assigneeOptions = PlanStepAssignee.allCases
        }
    }

    func title(for assignee: PlanStepAssignee) -> String {
        switch assignee {
        case .nobody: String(localized: "plans.step.who.nobody")
        case .me: String(localized: "plans.step.who.me")
        case .partner: partnerName
        }
    }

    func save() async -> Bool {
        guard let environment, environment.premiumGate.require(.edit) else { return false }
        isSaving = true
        defer { isSaving = false }
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        var edited = step
        edited.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        edited.note = trimmedNote.isEmpty ? nil : trimmedNote
        if assignee != loadedAssignee {
            edited.assigneeMemberId = assigneeMemberId(in: environment)
        }
        if hasDue != loadedDue.hasDue || dueAt != loadedDue.dueAt {
            edited.dueAt = hasDue ? dueAt : nil
        }
        do {
            _ = try await environment.repositories.plans.updateStep(edited, from: step)
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
