import CorbieCore
import SwiftUI

struct PeopleEntryView: View {
    let count: Int

    var body: some View {
        VStack(spacing: CorbieSpacing.l) {
            Spacer(minLength: 0)
            EmptyState(
                systemImage: "person.crop.circle",
                title: String(localized: "us.tile.people.line"),
                subtitle: String(localized: "us.tile.people.count \(count)"),
                monoNote: String(localized: "people.entry.note")
            )
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CorbieColorPalette.bg)
        .navigationTitle(String(localized: "us.hub.people"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        PeopleEntryView(count: 2)
    }
}
