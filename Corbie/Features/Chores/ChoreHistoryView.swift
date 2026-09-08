import CorbieCore
import SwiftUI

struct ChoreHistoryView: View {
    @Environment(\.palette) private var palette
    @Environment(AppEnvironment.self) private var environment

    @State private var sets: [ChoreSetDTO] = []
    @State private var hasLoaded = false

    private let copy = ChoreCopy()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CorbieSpacing.l) {
                if sets.isEmpty {
                    if hasLoaded {
                        empty
                    }
                } else {
                    ForEach(sets) { set in
                        past(set)
                    }
                }
            }
            .padding(.horizontal, CorbieSpacing.l)
            .padding(.vertical, CorbieSpacing.m)
        }
        .background(palette.bg)
        .navigationTitle(String(localized: "chore.history.title"))
        .navigationBarTitleDisplayMode(.large)
        .task { await load() }
    }

    private var empty: some View {
        EmptyState(
            systemImage: "clock.arrow.circlepath",
            title: String(localized: "chore.history.empty.title"),
            monoNote: String(localized: "chore.history.empty.note")
        )
        .padding(.top, CorbieSpacing.xxl)
    }

    private func past(_ set: ChoreSetDTO) -> some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
            SectionCaps(text: copy.day(set.appliedAt ?? set.createdAt))
            ChoreSharesView(
                lists: ChoreSplitPresentation(
                    set: set,
                    viewerMemberId: environment.currentMember?.id,
                    partnerMemberId: environment.partner?.id,
                    partnerName: environment.partnerName,
                    copy: copy
                ).lists
            )
        }
    }

    private func load() async {
        guard let space = environment.space else {
            hasLoaded = true
            return
        }
        do {
            sets = try await environment.repositories.chores
                .history(spaceId: space.id, viewerMemberId: environment.currentMember?.id)
                .filter { $0.appliedAt != nil }
        } catch {
            environment.report(error)
        }
        hasLoaded = true
    }
}
