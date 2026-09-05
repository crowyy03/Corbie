import SwiftUI

struct UsHubView: View {
    private struct Entry: Identifiable {
        let id: String
        let title: String
        let systemImage: String
    }

    private var entries: [Entry] {
        [
            Entry(
                id: "capsules",
                title: String(localized: "us.hub.capsules"),
                systemImage: "envelope"
            ),
            Entry(
                id: "votes",
                title: String(localized: "us.hub.votes"),
                systemImage: "hand.raised"
            ),
            Entry(
                id: "days",
                title: String(localized: "us.hub.days"),
                systemImage: "calendar"
            ),
            Entry(
                id: "people",
                title: String(localized: "us.hub.people"),
                systemImage: "person.crop.circle"
            ),
            Entry(
                id: "settings",
                title: String(localized: "us.hub.settings"),
                systemImage: "gearshape"
            )
        ]
    }

    var body: some View {
        List {
            Section {
                ForEach(entries) { entry in
                    Label(entry.title, systemImage: entry.systemImage)
                }
            } footer: {
                Text("us.hub.note")
                    .font(.footnote)
                    .fontDesign(.monospaced)
            }
        }
    }
}

#Preview {
    UsHubView()
}
