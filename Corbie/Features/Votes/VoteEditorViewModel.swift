import CorbieCore
import Foundation
import Observation

@MainActor
@Observable
final class VoteEditorViewModel {
    var template: VoteTemplate = .custom
    var question = ""
    var options: [String] = ["", ""]
    var mode: VoteMode = .single
    var revealWhenBothAnswered = true
    private(set) var isSaving = false
    private(set) var didFinish = false

    @ObservationIgnored private var environment: AppEnvironment?

    var canAddOption: Bool { options.count < VoteDTO.maxOptions }
    var canRemoveOption: Bool { options.count > VoteDTO.minOptions }

    var canSave: Bool {
        isSaving == false
            && question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && filledOptions.count >= VoteDTO.minOptions
            && filledOptions.count == options.count
    }

    private var filledOptions: [String] {
        options
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    }

    func attach(_ environment: AppEnvironment) {
        self.environment = environment
    }

    func apply(_ template: VoteTemplate) {
        self.template = template
        guard template != .custom else { return }
        question = template.question
        options = template.options
        mode = template.mode
    }

    func addOption() {
        guard canAddOption else { return }
        options.append("")
    }

    func removeOption(at index: Int) {
        guard canRemoveOption, options.indices.contains(index) else { return }
        options.remove(at: index)
    }

    func save() async {
        guard let environment, let space = environment.space, canSave else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await environment.repositories.votes.create(
                VoteDraft(
                    spaceId: space.id,
                    question: question.trimmingCharacters(in: .whitespacesAndNewlines),
                    options: filledOptions,
                    mode: mode,
                    revealWhenBothAnswered: revealWhenBothAnswered,
                    createdByMemberId: environment.currentMember?.id
                )
            )
            environment.analytics.record(.voteCreated)
            didFinish = true
        } catch {
            environment.report(error)
        }
    }
}
