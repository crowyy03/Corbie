import CorbieCore
import Foundation
import Observation

@MainActor
@Observable
final class QuestionViewModel {
    static let counterThreshold = 400

    private(set) var question: DailyQuestionDTO
    private(set) var isWriting: Bool
    private(set) var isSaving = false

    var draft: String {
        didSet {
            guard draft.count > QuestionAnswerDTO.maxLength else { return }
            draft = String(draft.prefix(QuestionAnswerDTO.maxLength))
        }
    }

    let text: String

    @ObservationIgnored var onChanged: ((DailyQuestionDTO) -> Void)?

    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var environment: AppEnvironment?
    @ObservationIgnored private var reloadObserver: (any NSObjectProtocol)?
    @ObservationIgnored private var hasRecordedReveal = false

    init(question: DailyQuestionDTO, text: String, now: @escaping @Sendable () -> Date = { Date() }) {
        self.question = question
        self.text = text
        self.now = now
        draft = ""
        isWriting = true
    }

    var viewerMemberId: UUID? { environment?.currentMember?.id }

    var ownAnswer: QuestionAnswerDTO? { question.answer(by: viewerMemberId) }

    var partnerAnswer: QuestionAnswerDTO? { question.answer(by: environment?.partner?.id) }

    var isRevealed: Bool { question.isRevealed }

    var canEditOwnAnswer: Bool {
        guard let ownAnswer, isWriting == false else { return false }
        return question.canEdit(ownAnswer, at: now())
    }

    var canNudge: Bool { question.canNudge(as: viewerMemberId) }

    var canSave: Bool {
        isSaving == false && draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var showsCounter: Bool { draft.count >= QuestionViewModel.counterThreshold }

    var charactersLeft: Int { max(0, QuestionAnswerDTO.maxLength - draft.count) }

    func attach(_ environment: AppEnvironment, center: NotificationCenter = .default) async {
        self.environment = environment
        isWriting = ownAnswer == nil
        draft = ownAnswer?.text ?? ""
        if reloadObserver == nil {
            reloadObserver = center.addObserver(
                forName: WidgetReloadRequest.notificationName,
                object: nil,
                queue: nil
            ) { [weak self] _ in
                Task { @MainActor in await self?.refresh() }
            }
        }
        await markSeen()
        recordRevealIfShown()
    }

    func detach(center: NotificationCenter = .default) {
        guard let reloadObserver else { return }
        center.removeObserver(reloadObserver)
        self.reloadObserver = nil
    }

    func startEditing() {
        draft = ownAnswer?.text ?? ""
        isWriting = true
    }

    func save() async {
        guard let environment, let memberId = viewerMemberId, canSave else { return }
        let existing = ownAnswer
        guard environment.premiumGate.require(existing == nil ? .create : .edit) else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)
            let updated: DailyQuestionDTO
            if let existing {
                updated = try await environment.repositories.questions.editAnswer(
                    answerId: existing.id,
                    text: body,
                    at: now()
                )
            } else {
                updated = try await environment.repositories.questions.answer(
                    dailyQuestionId: question.id,
                    memberId: memberId,
                    text: body,
                    at: now()
                )
                environment.analytics.record(.questionAnswered)
            }
            isWriting = false
            apply(updated)
        } catch {
            environment.report(error)
        }
    }

    func nudge() async {
        guard let environment, let memberId = viewerMemberId, canNudge else { return }
        do {
            let updated = try await environment.repositories.questions.nudge(
                dailyQuestionId: question.id,
                memberId: memberId,
                at: now()
            )
            environment.analytics.record(.questionNudgeSent)
            environment.toasts.show(message: String(localized: "question.nudge.sent"))
            apply(updated)
        } catch {
            environment.report(error)
        }
    }

    func refresh() async {
        guard let environment, let space = environment.space else { return }
        do {
            guard let stored = try await environment.repositories.questions.storedQuestion(
                spaceId: space.id,
                viewerMemberId: viewerMemberId,
                now: now()
            ), stored.id == question.id else { return }
            apply(stored)
        } catch {
            environment.report(error)
        }
    }

    private func apply(_ updated: DailyQuestionDTO) {
        question = updated
        onChanged?(updated)
        recordRevealIfShown()
    }

    private func markSeen() async {
        guard let environment, let memberId = viewerMemberId else { return }
        do {
            let member = try await environment.repositories.questions.markSeen(
                memberId: memberId,
                dayKey: question.dayKey
            )
            environment.apply(member: member)
            await environment.usBadge.refresh(
                space: environment.space,
                viewer: member,
                partner: environment.partner
            )
        } catch {
            environment.report(error)
        }
    }

    private func recordRevealIfShown() {
        guard question.isRevealed, hasRecordedReveal == false else { return }
        hasRecordedReveal = true
        environment?.analytics.record(.questionRevealed)
    }
}
