import CorbieCore
import SwiftUI

struct LaunchPlaceholderView: View {
    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            palette.bg
                .ignoresSafeArea()
            CorbieMarkView(size: 44, tint: palette.text2)
        }
    }
}

#if DEBUG
#Preview {
    LaunchPlaceholderView()
}
#endif
