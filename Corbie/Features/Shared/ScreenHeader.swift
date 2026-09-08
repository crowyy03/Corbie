import CorbieCore
import SwiftUI

struct ScreenHeader<Trailing: View>: View {
    let title: String

    @Environment(\.palette) private var palette
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(alignment: .center, spacing: CorbieSpacing.s) {
            Text(title)
                .corbieScreenTitle()
                .foregroundStyle(palette.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: CorbieSpacing.s)
            HStack(spacing: CorbieSpacing.xxs) {
                trailing
            }
        }
        .padding(.horizontal, CorbieSpacing.l)
        .padding(.top, CorbieSpacing.xs)
        .padding(.bottom, CorbieSpacing.xs)
        .background(palette.bg)
    }
}

extension View {
    func screenHeader<Trailing: View>(_ title: String, @ViewBuilder trailing: @escaping () -> Trailing) -> some View {
        toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                ScreenHeader(title: title, trailing: trailing)
            }
    }
}
