import SwiftUI
import WidgetKit

@main
struct CorbieWidgetsBundle: WidgetBundle {
    var body: some Widget {
        DaysTogetherWidget()
    }
}

struct DaysTogetherEntry: TimelineEntry {
    let date: Date
    let days: Int
}

struct DaysTogetherProvider: TimelineProvider {
    func placeholder(in context: Context) -> DaysTogetherEntry {
        DaysTogetherEntry(date: .now, days: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (DaysTogetherEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DaysTogetherEntry>) -> Void) {
        completion(Timeline(entries: [placeholder(in: context)], policy: .never))
    }
}

struct DaysTogetherWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DaysTogether", provider: DaysTogetherProvider()) { entry in
            DaysTogetherWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(Text("widget.daystogether.title"))
        .description(Text("widget.daystogether.description"))
        .supportedFamilies([.systemSmall])
    }
}

struct DaysTogetherWidgetView: View {
    let entry: DaysTogetherEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.days, format: .number)
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text("widget.daystogether.caption")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

#Preview(as: .systemSmall) {
    DaysTogetherWidget()
} timeline: {
    DaysTogetherEntry(date: .now, days: 1250)
}
