import CorbieCore
import SwiftUI

struct CapsuleOpenView: View {
    @Environment(\.palette) private var palette

    private let onOpened: (CapsuleDTO) -> Void

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var model: CapsuleOpenViewModel

    init(capsule: CapsuleDTO, onOpened: @escaping (CapsuleDTO) -> Void) {
        self.onOpened = onOpened
        _model = State(initialValue: CapsuleOpenViewModel(capsule: capsule))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CorbieSpacing.l) {
                    header
                    SealMark(isBroken: model.isBroken)
                        .frame(width: 120, height: 120)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, CorbieSpacing.m)
                        .accessibilityHidden(true)
                    if model.isBroken {
                        letter
                    } else {
                        prompt
                    }
                }
                .padding(CorbieSpacing.l)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(palette.bg)
            .navigationTitle(String(localized: "capsules.open.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.action.done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            model.attach(environment)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
            Text(model.capsule.title)
                .corbieScreenTitle()
                .foregroundStyle(palette.text)
            Text(String(format: String(localized: "capsules.open.from"), model.authorName))
                .corbieMono()
                .foregroundStyle(palette.text2)
        }
        .accessibilityElement(children: .combine)
    }

    private var prompt: some View {
        VStack(spacing: CorbieSpacing.m) {
            Text("capsules.open.sealed")
                .corbieCaption()
                .foregroundStyle(palette.text2)
                .multilineTextAlignment(.center)
            PrimaryButton(title: String(localized: "capsules.open.action")) {
                breakSeal()
            }
        }
        .frame(maxWidth: .infinity)
        .transition(.opacity)
    }

    private var letter: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.m) {
            Text(model.capsule.body)
                .corbieBody()
                .foregroundStyle(palette.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(model.readByBothText)
                .corbieMono()
                .foregroundStyle(palette.text2)
        }
        .transition(.opacity)
    }

    private func breakSeal() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.55)) {
            model.reveal()
        }
        Task {
            guard let opened = await model.markOpened() else { return }
            onOpened(opened)
        }
    }
}

private struct SealMark: View {
    @Environment(\.palette) private var palette

    let isBroken: Bool

    var body: some View {
        ZStack {
            SealHalf(isTop: true)
                .fill(palette.accent)
                .offset(y: isBroken ? -22 : 0)
                .rotationEffect(.degrees(isBroken ? -8 : 0), anchor: .bottomLeading)
                .opacity(isBroken ? 0.3 : 1)
            SealHalf(isTop: false)
                .fill(palette.accent)
                .offset(y: isBroken ? 22 : 0)
                .rotationEffect(.degrees(isBroken ? 8 : 0), anchor: .topTrailing)
                .opacity(isBroken ? 0.3 : 1)
            Image(systemName: "lock")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(palette.ctaText)
                .opacity(isBroken ? 0 : 1)
            Image(systemName: "envelope.open")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(palette.text2)
                .opacity(isBroken ? 1 : 0)
        }
    }
}

private struct SealHalf: Shape {
    let isTop: Bool

    func path(in rect: CGRect) -> Path {
        let circle = Path(ellipseIn: rect)
        let half = CGRect(
            x: rect.minX,
            y: isTop ? rect.minY : rect.midY,
            width: rect.width,
            height: rect.height / 2
        )
        return circle.intersection(Path(half))
    }
}

#if DEBUG
#Preview {
    CapsuleOpenView(
        capsule: CapsuleDTO(
            id: UUID(),
            title: "First year",
            body: "Read this when the leaves turn.",
            opensAt: Date()
        )
    ) { _ in }
        .environment(AppEnvironment.preview())
}
#endif
