import CorbieCore
import SwiftUI

struct ChoreRatingView: View {
    @Environment(\.palette) private var palette
    @Environment(AppEnvironment.self) private var environment

    @State private var model: ChoreRatingViewModel
    @State private var drag: CGSize = .zero

    private let copy = ChoreCopy()

    init(model: ChoreRatingViewModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.l) {
            progress
            if let item = model.current {
                card(item)
                Text("chore.rating.hint")
                    .corbieMono()
                    .foregroundStyle(palette.text2)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            verdicts
            undo
        }
        .padding(.horizontal, CorbieSpacing.l)
        .padding(.vertical, CorbieSpacing.m)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
            Text(copy.progress(position: model.position, total: model.total))
                .corbieMono()
                .foregroundStyle(palette.text2)
            ProgressBar(
                value: model.total == 0 ? 0 : Double(model.index) / Double(model.total),
                accessibilityLabel: String(localized: "chore.rating.progress.label"),
                accessibilityValue: copy.progress(position: model.position, total: model.total)
            )
        }
    }

    private func card(_ item: ChoreItemDTO) -> some View {
        Card(isHighlighted: true) {
            VStack(alignment: .leading, spacing: CorbieSpacing.s) {
                Text(item.title)
                    .corbieScreenTitle()
                    .foregroundStyle(palette.text)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)
                Text(copy.frequency(item.frequency))
                    .corbieMono()
                    .foregroundStyle(palette.text2)
            }
            .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
        }
        .id(item.id)
        .offset(drag)
        .rotationEffect(.degrees(Double(drag.width) / 24))
        .gesture(
            DragGesture()
                .onChanged { drag = $0.translation }
                .onEnded { finished in
                    let verdict = ChoreSwipe.verdict(for: finished.translation)
                    withAnimation(.snappy) { drag = .zero }
                    guard let verdict else { return }
                    rate(verdict)
                }
        )
        .accessibilityElement(children: .combine)
    }

    private var verdicts: some View {
        VStack(spacing: CorbieSpacing.xs) {
            ForEach(ChoreRatingView.order, id: \.self) { verdict in
                SecondaryButton(title: copy.verdictTitle(verdict)) {
                    rate(verdict)
                }
                .disabled(model.current == nil)
            }
        }
    }

    private static let order: [ChoreVerdict] = [.like, .fine, .neutral, .hate]

    private func rate(_ verdict: ChoreVerdict) {
        guard environment.premiumGate.require(.edit) else { return }
        Task { await model.rate(verdict) }
    }

    private var undo: some View {
        Button {
            guard environment.premiumGate.require(.edit) else { return }
            Task { await model.undo() }
        } label: {
            Text("chore.rating.undo")
                .corbieMono()
                .foregroundStyle(palette.accent)
                .frame(maxWidth: .infinity, minHeight: CorbieMetrics.minimumTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.canUndo == false)
        .opacity(model.canUndo ? 1 : 0.4)
    }
}
