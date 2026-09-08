import Foundation
import Observation
import SwiftUI

public struct ToastMessage: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let text: String

    public init(text: String) {
        id = UUID()
        self.text = text
    }
}

@Observable @MainActor
public final class ToastCenter {
    public static let displayDuration = Duration.seconds(3)

    public private(set) var current: ToastMessage?

    @ObservationIgnored private var dismissal: Task<Void, Never>?

    public init() {}

    public func show(message: String) {
        dismissal?.cancel()
        current = ToastMessage(text: message)
        dismissal = Task { [weak self] in
            try? await Task.sleep(for: ToastCenter.displayDuration)
            guard !Task.isCancelled else { return }
            self?.current = nil
        }
    }

    public func dismiss() {
        dismissal?.cancel()
        dismissal = nil
        current = nil
    }
}

struct ToastView: View {
    let text: String

    @Environment(\.palette) private var palette

    var body: some View {
        Text(text)
            .corbieCaption()
            .foregroundStyle(palette.text)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, CorbieSpacing.m)
            .padding(.vertical, CorbieSpacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: CorbieRadius.card, style: .continuous)
                    .fill(palette.elevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CorbieRadius.card, style: .continuous)
                    .strokeBorder(palette.border, lineWidth: CorbieMetrics.hairline)
            )
    }
}

struct ToastHostModifier: ViewModifier {
    @Environment(ToastCenter.self) private var center: ToastCenter?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let message = center?.current {
                    ToastView(text: message.text)
                        .padding(.horizontal, CorbieSpacing.m)
                        .padding(.bottom, CorbieSpacing.xl)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            }
            .animation(.easeOut(duration: 0.2), value: center?.current)
    }
}

public extension View {
    func toastHost() -> some View {
        modifier(ToastHostModifier())
    }
}

#if DEBUG
#if canImport(UIKit)
#Preview("Toast") {
    PreviewThemes {
        ToastView(text: "Could not reach the server. Saved locally.")
    }
}
#endif
#endif
