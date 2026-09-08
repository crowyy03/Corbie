import CorbieCore
import SwiftUI

struct CorbieMarkView: View {
    @Environment(\.palette) private var palette

    var size: CGFloat = 64
    var tint: Color?

    var body: some View {
        HStack(spacing: -size * 0.24) {
            Image(systemName: "bird.fill")
                .scaleEffect(x: -1)
            Image(systemName: "bird.fill")
        }
        .font(.system(size: size, weight: .regular))
        .foregroundStyle(tint ?? palette.text)
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    VStack(spacing: CorbieSpacing.xl) {
        CorbieMarkView()
        CorbieMarkView(size: 32, tint: CorbieTheme.sand.palette.text2)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(CorbieTheme.sand.palette.bg)
}
#endif
