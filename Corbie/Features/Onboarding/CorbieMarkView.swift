import CorbieCore
import SwiftUI

struct CorbieMarkView: View {
    var size: CGFloat = 64
    var tint: Color = CorbieColorPalette.text

    var body: some View {
        HStack(spacing: -size * 0.24) {
            Image(systemName: "bird.fill")
                .scaleEffect(x: -1)
            Image(systemName: "bird.fill")
        }
        .font(.system(size: size, weight: .regular))
        .foregroundStyle(tint)
        .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: CorbieSpacing.xl) {
        CorbieMarkView()
        CorbieMarkView(size: 32, tint: CorbieColorPalette.text2)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(CorbieColorPalette.bg)
}
