import CorbieCore
import SwiftUI

struct ChoreHistoryView: View {
    @Environment(\.palette) private var palette
    @Environment(AppEnvironment.self) private var environment

    @State private var model = ChoreHistoryViewModel()

    private let copy = ChoreCopy()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CorbieSpacing.l) {
                if model.sets.isEmpty {
                    if model.hasLoaded {
                        empty
                    }
                } else {
                    ForEach(model.sets) { set in
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
        .task {
            model.attach(environment)
            await model.load()
        }
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
}
