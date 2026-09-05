import SwiftUI

struct PlaceholderView: View {
    let title: String
    let note: String

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.title3)
                .multilineTextAlignment(.center)
            Text(note)
                .font(.footnote)
                .fontDesign(.monospaced)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    PlaceholderView(
        title: String(localized: "tasks.placeholder.title"),
        note: String(localized: "tasks.placeholder.note")
    )
}
