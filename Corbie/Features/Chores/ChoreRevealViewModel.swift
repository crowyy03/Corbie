import CorbieCore
import Foundation
import Observation

@MainActor
@Observable
final class ChoreRevealViewModel {
    private(set) var choreSet: ChoreSetDTO
    private(set) var isWorking = false

    @ObservationIgnored var onError: ((any Error) -> Void)?
    @ObservationIgnored var onChanged: ((ChoreSetDTO) -> Void)?

    @ObservationIgnored private let repository: any ChoreRepository
    @ObservationIgnored private let context: ChoresContext
    @ObservationIgnored private let analytics: any AnalyticsRecording
    @ObservationIgnored private let copy: ChoreCopy
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var hasRecordedReveal = false

    init(
        set: ChoreSetDTO,
        repository: any ChoreRepository,
        context: ChoresContext,
        analytics: any AnalyticsRecording,
        copy: ChoreCopy = ChoreCopy(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        choreSet = set
        self.repository = repository
        self.context = context
        self.analytics = analytics
        self.copy = copy
        self.now = now
    }

    var presentation: ChoreSplitPresentation {
        ChoreSplitPresentation(
            set: choreSet,
            viewerMemberId: context.memberId,
            partnerMemberId: context.partnerId,
            partnerName: context.partnerName,
            copy: copy
        )
    }

    func recordReveal() {
        guard hasRecordedReveal == false else { return }
        hasRecordedReveal = true
        let shown = presentation
        analytics.record(
            .choreRevealed(tradeCount: shown.trades.count, rotateCount: shown.rotatingCount)
        )
    }

    func apply() async {
        guard isWorking == false else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let tasks = try await repository.apply(setId: choreSet.id, memberId: context.memberId, at: now())
            analytics.record(.choreApplied(taskCount: tasks.count))
            guard let applied = try await repository.set(id: choreSet.id, viewerMemberId: context.memberId) else { return }
            choreSet = applied
            onChanged?(applied)
        } catch {
            onError?(error)
        }
    }
}
