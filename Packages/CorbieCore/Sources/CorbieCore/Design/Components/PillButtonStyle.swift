import SwiftUI

struct CorbiePillButtonStyle: ButtonStyle {
    enum Variant {
        case filled
        case outlined
    }

    let variant: Variant

    func makeBody(configuration: Configuration) -> some View {
        PillLabel(configuration: configuration, variant: variant)
    }

    private struct PillLabel: View {
        let configuration: ButtonStyleConfiguration
        let variant: Variant

        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.palette) private var palette

        private var shape: RoundedRectangle {
            RoundedRectangle(cornerRadius: CorbieRadius.pill, style: .continuous)
        }

        private var foreground: Color {
            switch variant {
            case .filled: return palette.ctaText
            case .outlined: return palette.text
            }
        }

        private var fill: Color {
            switch variant {
            case .filled: return palette.ctaFill
            case .outlined: return .clear
            }
        }

        private var stroke: Color {
            switch variant {
            case .filled: return .clear
            case .outlined: return palette.border
            }
        }

        var body: some View {
            configuration.label
                .corbieBody()
                .fontWeight(.semibold)
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .frame(minHeight: CorbieMetrics.controlHeight)
                .background(shape.fill(fill))
                .overlay(shape.strokeBorder(stroke, lineWidth: CorbieMetrics.hairline))
                .contentShape(shape)
                .opacity(isEnabled ? 1 : 0.4)
                .opacity(configuration.isPressed ? 0.82 : 1)
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
        }
    }
}
