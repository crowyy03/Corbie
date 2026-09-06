import CorbieCore
import SwiftUI
import WidgetKit

struct FreeSlotsEntry: TimelineEntry {
    let date: Date
    let snapshot: FreeSlotsSnapshot

    static let placeholder = FreeSlotsEntry(
        date: Date(),
        snapshot: FreeSlotsSnapshot(availability: .noSlots, isPremium: true)
    )

    static func load(now: Date, provider: WidgetDataProvider) async -> FreeSlotsEntry {
        let snapshot = (try? await provider.freeSlots(now: now))
            ?? FreeSlotsSnapshot(availability: .noSlots, isPremium: true)
        return FreeSlotsEntry(date: now, snapshot: snapshot)
    }
}

struct FreeSlotsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: WidgetKinds.freeSlots,
            provider: CorbieTimelineProvider(placeholderEntry: FreeSlotsEntry.placeholder) { now in
                await FreeSlotsEntry.load(now: now, provider: WidgetStore.provider())
            }
        ) { entry in
            FreeSlotsWidgetView(entry: entry)
                .corbieWidgetSurface()
        }
        .configurationDisplayName(Text("widget.freeslots.title"))
        .description(Text("widget.freeslots.description"))
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

struct FreeSlotsWidgetView: View {
    let entry: FreeSlotsEntry

    private var emptyTitle: LocalizedStringKey {
        switch entry.snapshot.availability {
        case .notPaired: return "freetime.unpaired.title"
        case .viewerNotSharing: return "freetime.you.title"
        case .partnerNotSharing: return "widget.freeslots.partner"
        case .slots, .noSlots: return "widget.freeslots.empty"
        }
    }

    private var emptyNote: LocalizedStringKey {
        switch entry.snapshot.availability {
        case .notPaired: return "freetime.unpaired.note"
        case .viewerNotSharing: return "freetime.you.note"
        case .partnerNotSharing: return "freetime.partner.note"
        case .slots, .noSlots: return "widget.freeslots.empty.note"
        }
    }

    var body: some View {
        Group {
            if entry.snapshot.isPremium == false {
                LockedWidgetView()
            } else if entry.snapshot.slots.isEmpty {
                WidgetEmptyState(title: emptyTitle, note: emptyNote)
                    .widgetURL(CorbieRoute.calendar.url)
            } else {
                VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                    WidgetHeading(text: String(localized: "freetime.list.caps"))
                    ForEach(entry.snapshot.slots) { slot in
                        WidgetFreeSlotRow(slot: slot)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .widgetURL(CorbieRoute.calendar.url)
            }
        }
    }
}

#if DEBUG
#Preview("Free time", as: .systemMedium) {
    FreeSlotsWidget()
} timeline: {
    await FreeSlotsEntry.load(now: Date(), provider: WidgetPreviewData.provider())
    FreeSlotsEntry(date: Date(), snapshot: FreeSlotsSnapshot(availability: .partnerNotSharing, isPremium: true))
    FreeSlotsEntry(date: Date(), snapshot: FreeSlotsSnapshot(availability: .noSlots, isPremium: false))
}
#endif
