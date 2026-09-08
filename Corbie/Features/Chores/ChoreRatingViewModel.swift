import CorbieCore
import Foundation
import Observation

@MainActor
@Observable
final class ChoreRatingViewModel {
    private(set) var choreSet: ChoreSetDTO
    private(set) var index: Int
    private(set) var isWorking = false

    @ObservationIgnored var onError: ((any Error) -> Void)?
    @ObservationIgnored var onChanged: ((ChoreSetDTO) -> Void)?

    @ObservationIgnored private let repository: any ChoreRepository
    @ObservationIgnored private let memberId: UUID?
    @ObservationIgnored private let analytics: any AnalyticsRecording
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var hasRecordedDone = false

    init(
        set: ChoreSetDTO,
        repository: any ChoreRepository,
        memberId: UUID?,
        analytics: any AnalyticsRecording,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        choreSet = set
        self.repository = repository
        self.memberId = memberId
        self.analytics = analytics
        self.now = now
        index = set.includedItems.firstIndex { $0.verdict(of: memberId) == nil } ?? set.includedItems.count
    }

    var queue: [ChoreItemDTO] { choreSet.includedItems }

    var current: ChoreItemDTO? { queue.indices.contains(index) ? queue[index] : nil }

    var total: Int { queue.count }

    var position: Int { min(index + 1, total) }

    var canUndo: Bool { index > 0 && isWorking == false }

    var isDone: Bool { index >= total }

    func rate(_ verdict: ChoreVerdict) async {
        guard let item = current, let memberId, isWorking == false else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            choreSet = try await repository.rate(itemId: item.id, memberId: memberId, verdict: verdict, at: now())
            index += 1
            onChanged?(choreSet)
            guard isDone, hasRecordedDone == false else { return }
            hasRecordedDone = true
            analytics.record(.choreRatingDone)
        } catch {
            onError?(error)
        }
    }

    func undo() async {
        guard canUndo, let memberId else { return }
        let item = queue[index - 1]
        isWorking = true
        defer { isWorking = false }
        do {
            choreSet = try await repository.undoRating(itemId: item.id, memberId: memberId)
            index -= 1
            onChanged?(choreSet)
        } catch {
            onError?(error)
        }
    }
}
