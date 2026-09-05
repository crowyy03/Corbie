import CorbieCore
import SwiftUI

struct LaunchPlaceholderView: View {
    var body: some View {
        ZStack {
            CorbieColorPalette.bg
                .ignoresSafeArea()
            CorbieMarkView(size: 44, tint: CorbieColorPalette.text2)
        }
    }
}

#Preview {
    LaunchPlaceholderView()
}
