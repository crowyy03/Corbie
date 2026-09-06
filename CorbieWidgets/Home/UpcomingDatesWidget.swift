import CorbieCore
import SwiftUI
import WidgetKit

struct UpcomingDatesEntry: TimelineEntry {
    let date: Date
    let snapshot: UpcomingDatesSnapshot

    static let placeholder = UpcomingDatesEntry(
        date: Date(),
        snapshot: UpcomingDatesSnapshot(items: [], isPremium: true)
    )

    static func load(now: Date, provider: WidgetDataProvider) async -> UpcomingDatesEntry {
        let snapshot = (try? await provider.upcomingDates(now: now))
            ?? UpcomingDatesSnapshot(items: [], isPremium: true)
        return UpcomingDatesEntry(date: now, snapshot: snapshot)
    }
}

struct UpcomingDatesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: WidgetKinds.upcomingDates,
            provider: CorbieTimelineProvider(placeholderEntry: UpcomingDatesEntry.placeholder) { now in
                await UpcomingDatesEntry.load(now: now, provider: WidgetStore.provider())
            }
        ) { entry in
            UpcomingDatesWidgetView(entry: entry)
                .corbieWidgetSurface()
        }
        .configurationDisplayName(Text("widget.dates.title"))
        .description(Text("widget.dates.description"))
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

struct UpcomingDatesWidgetView: View {
    let entry: UpcomingDatesEntry

    var body: some View {
        Group {
            if entry.snapshot.isPremium == false {
                LockedWidgetView()
            } else if entry.snapshot.items.isEmpty {
                WidgetEmptyState(title: "widget.dates.empty", note: "widget.dates.empty.note")
                    .widgetURL(CorbieRoute.calendar.url)
            } else {
                VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                    WidgetHeading(text: String(localized: "widget.dates.heading"))
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(entry.snapshot.items) { date in
                            WidgetDateRow(date: date, now: entry.date)
                        }
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
#Preview("Upcoming dates", as: .systemMedium) {
    UpcomingDatesWidget()
} timeline: {
    await UpcomingDatesEntry.load(now: Date(), provider: WidgetPreviewData.provider())
    UpcomingDatesEntry(date: Date(), snapshot: UpcomingDatesSnapshot(items: [], isPremium: true))
    UpcomingDatesEntry(date: Date(), snapshot: UpcomingDatesSnapshot(items: [], isPremium: false))
}
#endif
