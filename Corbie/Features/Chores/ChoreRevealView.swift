import CorbieCore
import SwiftUI

struct ChoreRevealView: View {
    @Environment(\.palette) private var palette
    @Environment(AppEnvironment.self) private var environment

    @State private var model: ChoreRevealViewModel

    init(model: ChoreRevealViewModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        let shown = model.presentation

        return ScrollView {
            VStack(alignment: .leading, spacing: CorbieSpacing.l) {
                Text(shown.headline)
                    .corbieScreenTitle()
                    .foregroundStyle(palette.text)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(shown.trades) { trade in
                    tradeCard(trade)
                }
                ChoreSharesView(lists: shown.lists)
                Text(shown.footer)
                    .corbieMono()
                    .foregroundStyle(palette.text2)
                PrimaryButton(title: String(localized: "chore.reveal.apply")) {
                    guard environment.premiumGate.require(.create) else { return }
                    Task { await model.apply() }
                }
                .disabled(model.isWorking)
            }
            .padding(.horizontal, CorbieSpacing.l)
            .padding(.vertical, CorbieSpacing.m)
        }
        .task { model.recordReveal() }
    }

    private func tradeCard(_ trade: ChoreTrade) -> some View {
        Card(isHighlighted: true) {
            VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
                Text(trade.title)
                    .corbieBody()
                    .fontWeight(.semibold)
                    .foregroundStyle(palette.text)
                Text(trade.line)
                    .corbieCaption()
                    .foregroundStyle(palette.text2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(trade.stamp)
                    .corbieMono()
                    .foregroundStyle(palette.accent)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct ChoreSharesView: View {
    @Environment(\.palette) private var palette

    let lists: [ChoreShare]

    var body: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.m) {
            ForEach(lists) { list in
                VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
                    SectionCaps(text: list.title)
                    Card {
                        VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
                            ForEach(list.chores, id: \.self) { chore in
                                Text(chore)
                                    .corbieBody()
                                    .foregroundStyle(palette.text)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
    }
}
