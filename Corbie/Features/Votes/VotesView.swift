import CorbieCore
import SwiftUI

struct VotesView: View {
    var startsWithEditor = false

    @Environment(AppEnvironment.self) private var environment
    @State private var model = VotesViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CorbieSpacing.s) {
                if model.votes.isEmpty {
                    if model.isLoading == false {
                        empty
                    }
                } else {
                    ForEach(model.votes) { vote in
                        NavigationLink {
                            VoteView(vote: vote) { updated in
                                model.replace(updated)
                            }
                        } label: {
                            row(vote)
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isButton)
                    }
                }
            }
            .padding(.horizontal, CorbieSpacing.l)
            .padding(.vertical, CorbieSpacing.m)
        }
        .background(CorbieColorPalette.bg)
        .navigationTitle(String(localized: "votes.title"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            AddToolbarItem {
                model.startNew()
            }
        }
        .sheet(isPresented: $model.isEditorPresented) {
            VoteEditorView {
                await model.load(environment)
            }
        }
        .task {
            await model.load(environment)
            if startsWithEditor, model.isEditorPresented == false {
                model.startNew()
            }
        }
    }

    private var empty: some View {
        EmptyState(
            systemImage: "hand.raised",
            title: String(localized: "votes.empty.title"),
            monoNote: String(localized: "votes.empty.note"),
            cta: EmptyStateAction(title: String(localized: "votes.action.new")) {
                model.startNew()
            }
        )
        .padding(.top, CorbieSpacing.xxl)
    }

    private func row(_ vote: VoteDTO) -> some View {
        let outcome = model.outcome(for: vote)
        return Card(showsChromeGradient: outcome == .needsYourAnswer) {
            VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                Text(vote.question)
                    .corbieBody()
                    .fontWeight(.semibold)
                    .foregroundStyle(CorbieColorPalette.text)
                    .multilineTextAlignment(.leading)
                Text(caption(for: vote, outcome: outcome))
                    .corbieMono()
                    .foregroundStyle(CorbieColorPalette.text2)
                    .multilineTextAlignment(.leading)
            }
        }
    }

    private func caption(for vote: VoteDTO, outcome: VoteOutcome) -> String {
        switch outcome {
        case .needsYourAnswer:
            return String(localized: "votes.row.yourturn")
        case .waitingForPartner:
            return String(format: String(localized: "votes.row.waiting"), environment.partnerName)
        case let .match(options):
            return String(
                format: String(localized: "votes.row.match"),
                titles(of: options, in: vote).formatted(.list(type: .and))
            )
        case .mismatch:
            return String(localized: "votes.row.mismatch")
        case .noMatch:
            return String(localized: "votes.row.nomatch")
        }
    }

    private func titles(of indexes: [Int], in vote: VoteDTO) -> [String] {
        indexes.compactMap { index in
            vote.options.indices.contains(index) ? vote.options[index] : nil
        }
    }
}

#Preview {
    NavigationStack {
        VotesView()
    }
    .environment(AppState())
    .environment(AppEnvironment.preview())
}
