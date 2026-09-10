import CorbieCore
import SwiftUI

struct LaunchRevealView: View {
    @Environment(\.palette) private var palette

    let isReady: Bool
    let onFinished: () -> Void

    @State private var isReadyObserved = false
    @State private var minimumTimeElapsed = false
    @State private var hasFlown = false

    private let markSize: CGFloat = 72
    private let flight: CGFloat = 220

    var body: some View {
        ZStack {
            palette.bg
                .ignoresSafeArea()
            ZStack {
                CorbieRavenShape(side: .left)
                    .fill(palette.text)
                    .offset(x: hasFlown ? -flight : 0, y: hasFlown ? -flight * 0.6 : 0)
                CorbieRavenShape(side: .right)
                    .fill(palette.text)
                    .offset(x: hasFlown ? flight : 0, y: hasFlown ? -flight * 0.6 : 0)
            }
            .frame(width: markSize, height: markSize)
            .accessibilityHidden(true)
        }
        .opacity(hasFlown ? 0 : 1)
        .allowsHitTesting(hasFlown == false)
        .task {
            try? await Task.sleep(for: .milliseconds(500))
            minimumTimeElapsed = true
            flyAwayIfReady()
        }
        .onChange(of: isReady, initial: true) { _, ready in
            isReadyObserved = ready
            flyAwayIfReady()
        }
    }

    private func flyAwayIfReady() {
        guard isReadyObserved, minimumTimeElapsed, hasFlown == false else { return }
        withAnimation(.easeIn(duration: 0.55)) {
            hasFlown = true
        }
        Task {
            try? await Task.sleep(for: .milliseconds(550))
            onFinished()
        }
    }
}

#if DEBUG
#Preview {
    LaunchRevealView(isReady: true) {}
}
#endif
