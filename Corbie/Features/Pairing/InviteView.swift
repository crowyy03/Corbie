import CorbieCore
import SwiftUI

struct InviteView: View {
    @State private var model: InviteViewModel
    private let onHasCode: (() -> Void)?
    private let onDone: () -> Void

    init(
        environment: AppEnvironment,
        spaceId: UUID,
        onHasCode: (() -> Void)? = nil,
        onDone: @escaping () -> Void
    ) {
        _model = State(initialValue: InviteViewModel(environment: environment, spaceId: spaceId))
        self.onHasCode = onHasCode
        self.onDone = onDone
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: CorbieSpacing.l) {
                Text("pairing.invite.title")
                    .corbieScreenTitle()
                    .foregroundStyle(CorbieColorPalette.text)
                Text("pairing.invite.note")
                    .corbieMono()
                    .foregroundStyle(CorbieColorPalette.text2)

                codeCard(at: context.date)

                Spacer()

                actions(at: context.date)
            }
            .padding(.horizontal, CorbieSpacing.l)
            .padding(.vertical, CorbieSpacing.xl)
        }
        .task { await model.generate() }
    }

    @ViewBuilder private func codeCard(at date: Date) -> some View {
        Card(showsChromeGradient: true) {
            VStack(alignment: .leading, spacing: CorbieSpacing.s) {
                switch model.phase {
                case .idle, .working:
                    HStack(spacing: CorbieSpacing.s) {
                        ProgressView()
                            .tint(CorbieColorPalette.ice)
                        Text("pairing.invite.working")
                            .corbieMono()
                            .foregroundStyle(CorbieColorPalette.text2)
                    }
                case .ready:
                    Text(verbatim: model.code ?? "")
                        .corbieCounter()
                        .foregroundStyle(CorbieColorPalette.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .accessibilityLabel(Text("pairing.invite.code.label"))
                        .accessibilityValue(Text(verbatim: InviteCodeFormat.spelledOut(model.code ?? "")))
                    countdownLine(at: date)
                case .failed:
                    Text("pairing.invite.failed.note")
                        .corbieMono()
                        .foregroundStyle(CorbieColorPalette.text2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private func countdownLine(at date: Date) -> some View {
        if let countdown = model.countdown(at: date) {
            if countdown.isExpired {
                Text("pairing.invite.expired")
                    .corbieMono()
                    .foregroundStyle(CorbieColorPalette.text2)
            } else {
                Text(verbatim: String(format: String(localized: "pairing.invite.expires"), countdown.text()))
                    .corbieMono()
                    .foregroundStyle(CorbieColorPalette.text2)
                    .monospacedDigit()
            }
        }
    }

    @ViewBuilder private func actions(at date: Date) -> some View {
        VStack(spacing: CorbieSpacing.s) {
            if model.isShareable(at: date) {
                shareButton
            } else if model.phase != .working {
                PrimaryButton(title: String(localized: "pairing.invite.retry")) {
                    Task { await model.generate() }
                }
            }

            if let onHasCode {
                SecondaryButton(title: String(localized: "pairing.invite.havecode"), action: onHasCode)
            }

            Button(action: onDone) {
                Text("pairing.invite.later")
                    .corbieBody()
                    .foregroundStyle(CorbieColorPalette.text2)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: CorbieMetrics.minimumTapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var shareButton: some View {
        ShareLink(item: model.shareMessage) {
            Text("pairing.invite.share")
                .corbieBody()
                .fontWeight(.semibold)
                .foregroundStyle(CorbieColorPalette.bg)
                .frame(maxWidth: .infinity)
                .frame(minHeight: CorbieMetrics.controlHeight)
                .background(
                    RoundedRectangle(cornerRadius: CorbieRadius.pill, style: .continuous)
                        .fill(CorbieColorPalette.text)
                )
                .contentShape(RoundedRectangle(cornerRadius: CorbieRadius.pill, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    InviteView(environment: .preview(), spaceId: UUID(), onHasCode: {}, onDone: {})
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CorbieColorPalette.bg)
}
