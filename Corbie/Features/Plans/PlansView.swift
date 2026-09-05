import SwiftUI

struct PlansView: View {
    var body: some View {
        PlaceholderView(
            title: String(localized: "plans.placeholder.title"),
            note: String(localized: "plans.placeholder.note")
        )
    }
}

#Preview {
    PlansView()
}
