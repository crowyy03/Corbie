import CorbieCore
import SwiftUI

struct CorbieMarkView: View {
    @Environment(\.palette) private var palette

    var size: CGFloat = 64
    var tint: Color?

    var body: some View {
        CorbieMarkShape()
            .fill(tint ?? palette.text)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    PreviewThemes {
        HStack(alignment: .bottom, spacing: CorbieSpacing.l) {
            CorbieMarkView(size: 24)
            CorbieMarkView(size: 44)
            CorbieMarkView(size: 76)
            CorbieMarkView(size: 200)
        }
    }
}
#endif
