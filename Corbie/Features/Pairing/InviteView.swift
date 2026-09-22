import CorbieCore
import SwiftUI

struct InviteView: View {
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var model: InviteViewModel
    private let partner: MemberDTO?
    private let onHasCode: (() -> Void)?
    private let onDone: () -> Void

    init(
        environment: AppEnvironment,
        appState: AppState,
        spaceId: UUID,
        partner: MemberDTO?,
        onHasCode: (() -> Void)? = nil,
        onDone: @escaping () -> Void
    ) {
        _model = State(
            initialValue: InviteViewModel(environment: environment, appState: appState, spaceId: spaceId, leave: onDone)
        )
        self.partner = partner
        self.onHasCode = onHasCode
        self.onDone = onDone
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: CorbieSpacing.l) {
                Text("pairing.invite.title")
                    .corbieScreenTitle()
                    .foregroundStyle(palette.text)
                Text("pairing.invite.note")
                    .corbieMono()
                    .foregroundStyle(palette.text2)

                codeCard(at: context.date)

                Spacer()

                actions(at: context.date)
            }
            .padding(.horizontal, CorbieSpacing.l)
            .padding(.vertical, CorbieSpacing.xl)
        }
        .task { await model.appear(partner: partner, reduceMotion: reduceMotion) }
        .onChange(of: partner) { _, partner in
            Task { await model.apply(partner: partner, reduceMotion: reduceMotion) }
        }
        .onChange(of: model.phase) { _, phase in
            guard phase == .joined, let line = model.joinedLine else { return }
            announce(line)
        }
    }

    @ViewBuilder private func codeCard(at date: Date) -> some View {
        Card(isHighlighted: true) {
            VStack(alignment: .leading, spacing: CorbieSpacing.s) {
                switch model.phase {
                case .idle, .working:
                    HStack(spacing: CorbieSpacing.s) {
                        ProgressView()
                            .tint(palette.accent)
                        Text("pairing.invite.working")
                            .corbieMono()
                            .foregroundStyle(palette.text2)
                    }
                case .ready:
                    Text(verbatim: model.code ?? "")
                        .corbieCounter()
                        .foregroundStyle(palette.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .accessibilityLabel(Text("pairing.invite.code.label"))
                        .accessibilityValue(Text(verbatim: InviteCodeFormat.spelledOut(model.code ?? "")))
                    countdownLine(at: date)
                    if model.isShareable(at: date) {
                        newCodeAction
                    }
                case .failed:
                    Text(verbatim: model.failure ?? String(localized: "pairing.invite.failed.note"))
                        .corbieMono()
                        .foregroundStyle(palette.text2)
                case .joined:
                    Text(verbatim: model.joinedLine ?? "")
                        .corbieIntroTitle()
                        .foregroundStyle(palette.text)
                        .fixedSize(horizontal: false, vertical: true)
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
                    .foregroundStyle(palette.text2)
            } else {
                Text(verbatim: String(format: String(localized: "pairing.invite.expires"), countdown.text()))
                    .corbieMono()
                    .foregroundStyle(palette.text2)
                    .monospacedDigit()
            }
        }
    }

    @ViewBuilder private func actions(at date: Date) -> some View {
        if model.phase != .joined {
            waitingActions(at: date)
        }
    }

    private func waitingActions(at date: Date) -> some View {
        VStack(spacing: CorbieSpacing.s) {
            if model.isShareable(at: date) {
                shareButton
            } else if model.phase != .working {
                PrimaryButton(title: String(localized: "pairing.invite.retry")) {
                    Task { await model.makeNewCode() }
                }
            }

            if let onHasCode {
                SecondaryButton(title: String(localized: "pairing.invite.havecode"), action: onHasCode)
            }

            Button(action: onDone) {
                Text("pairing.invite.later")
                    .corbieBody()
                    .foregroundStyle(palette.text2)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: CorbieMetrics.minimumTapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var newCodeAction: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
            Button {
                Task { await model.makeNewCode() }
            } label: {
                Text("pairing.invite.new")
                    .corbieBody()
                    .fontWeight(.semibold)
                    .foregroundStyle(palette.text)
                    .frame(minHeight: CorbieMetrics.minimumTapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("pairing.invite.new.note"))
            Text("pairing.invite.new.note")
                .corbieMono()
                .foregroundStyle(palette.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, CorbieSpacing.s)
    }

    private func announce(_ line: String) {
        var announcement = AttributedString(line)
        announcement.accessibilitySpeechAnnouncementPriority = .high
        AccessibilityNotification.Announcement(announcement).post()
    }

    private var shareButton: some View {
        ShareLink(item: model.shareMessage) {
            Text("pairing.invite.share")
                .corbieBody()
                .fontWeight(.semibold)
                .foregroundStyle(palette.bg)
                .frame(maxWidth: .infinity)
                .frame(minHeight: CorbieMetrics.controlHeight)
                .background(
                    RoundedRectangle(cornerRadius: CorbieRadius.pill, style: .continuous)
                        .fill(palette.text)
                )
                .contentShape(RoundedRectangle(cornerRadius: CorbieRadius.pill, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview {
    InviteView(environment: .preview(), appState: AppState(), spaceId: UUID(), partner: nil, onHasCode: {}, onDone: {})
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CorbieTheme.sand.palette.bg)
}
#endif
