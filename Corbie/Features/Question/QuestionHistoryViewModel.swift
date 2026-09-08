import CorbieCore
import Foundation
import Observation

@MainActor
@Observable
final class QuestionHistoryViewModel {
    private(set) var days: [DailyQuestionDTO] = []
    private(set) var hasLoaded = false
    var search = ""

    @ObservationIgnored private var hasRecordedOpen = false

    func load(_ environment: AppEnvironment) async {
        guard let space = environment.space else {
            days = []
            hasLoaded = true
            return
        }
        do {
            days = try await environment.repositories.questions.history(
                spaceId: space.id,
                viewerMemberId: environment.currentMember?.id,
                search: search
            )
            hasLoaded = true
            recordOpen(environment)
        } catch {
            environment.report(error)
        }
    }

    private func recordOpen(_ environment: AppEnvironment) {
        guard hasRecordedOpen == false else { return }
        hasRecordedOpen = true
        environment.analytics.record(.questionHistoryOpened)
    }
}
