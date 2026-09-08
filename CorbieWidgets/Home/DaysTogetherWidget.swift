import CorbieCore
import SwiftUI
import WidgetKit

struct DaysTogetherEntry: TimelineEntry {
    let date: Date
    let snapshot: DaysTogetherSnapshot

    static let placeholder = DaysTogetherEntry(
        date: Date(),
        snapshot: DaysTogetherSnapshot(days: 460, isPremium: true)
    )

    static func load(now: Date, provider: WidgetDataProvider) async -> DaysTogetherEntry {
        let snapshot = (try? await provider.daysTogether(now: now))
            ?? DaysTogetherSnapshot(days: nil, isPremium: true)
        return DaysTogetherEntry(date: now, snapshot: snapshot)
    }
}

struct DaysTogetherWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: WidgetKinds.daysTogether,
            provider: CorbieTimelineProvider(placeholderEntry: DaysTogetherEntry.placeholder) { now in
                await DaysTogetherEntry.load(now: now, provider: WidgetStore.provider())
            }
        ) { entry in
            DaysTogetherWidgetView(entry: entry)
                .corbieWidgetSurface()
        }
        .configurationDisplayName(Text("widget.daystogether.title"))
        .description(Text("widget.daystogether.description"))
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

struct DaysTogetherWidgetView: View {
    @Environment(\.palette) private var palette

    let entry: DaysTogetherEntry

    var body: some View {
        Group {
            if let days = entry.snapshot.days {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: 0)
                    WidgetCounter(value: days)
                    Text("widget.daystogether.caption")
                        .corbieMono()
                        .foregroundStyle(palette.text2)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            } else {
                WidgetEmptyState(title: "widget.daystogether.empty", note: "widget.daystogether.empty.note")
            }
        }
        .widgetURL(CorbieRoute.calendar.url)
    }
}

#if DEBUG
#Preview("Days together", as: .systemSmall) {
    DaysTogetherWidget()
} timeline: {
    await DaysTogetherEntry.load(now: Date(), provider: WidgetPreviewData.provider())
    DaysTogetherEntry(date: Date(), snapshot: DaysTogetherSnapshot(days: nil, isPremium: true))
}
#endif
