import CorbieCore
import SwiftUI
import WidgetKit

struct OurDayEntry: TimelineEntry {
    let date: Date
    let snapshot: OurDaySnapshot

    static let placeholder = OurDayEntry(
        date: Date(),
        snapshot: OurDaySnapshot(days: 460, tasks: [], events: [], plan: nil, isPremium: true)
    )

    static func load(now: Date, provider: WidgetDataProvider) async -> OurDayEntry {
        let snapshot = (try? await provider.ourDay(now: now))
            ?? OurDaySnapshot(days: nil, tasks: [], events: [], plan: nil, isPremium: true)
        return OurDayEntry(date: now, snapshot: snapshot)
    }
}

struct OurDayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: WidgetKinds.ourDay,
            provider: CorbieTimelineProvider(placeholderEntry: OurDayEntry.placeholder) { now in
                await OurDayEntry.load(now: now, provider: WidgetStore.provider())
            }
        ) { entry in
            OurDayWidgetView(entry: entry)
                .corbieWidgetSurface()
        }
        .configurationDisplayName(Text("widget.ourday.title"))
        .description(Text("widget.ourday.description"))
        .supportedFamilies([.systemLarge])
        .contentMarginsDisabled()
    }
}

struct OurDayWidgetView: View {
    let entry: OurDayEntry

    private var isEmpty: Bool {
        entry.snapshot.days == nil
            && entry.snapshot.tasks.isEmpty
            && entry.snapshot.events.isEmpty
            && entry.snapshot.plan == nil
    }

    var body: some View {
        Group {
            if entry.snapshot.isPremium == false {
                LockedWidgetView()
            } else if isEmpty {
                WidgetEmptyState(title: "widget.ourday.empty", note: "widget.ourday.empty.note")
                    .widgetURL(CorbieRoute.us.url)
            } else {
                VStack(alignment: .leading, spacing: CorbieSpacing.s) {
                    if let days = entry.snapshot.days {
                        WidgetLink(route: .us) {
                            VStack(alignment: .leading, spacing: 0) {
                                WidgetCounter(value: days, compact: true)
                                Text("widget.daystogether.caption")
                                    .corbieMono()
                                    .foregroundStyle(CorbieColorPalette.text2)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityElement(children: .combine)
                        }
                    }
                    ForEach(entry.snapshot.tasks) { task in
                        WidgetTaskRow(task: task, now: entry.date)
                    }
                    ForEach(entry.snapshot.events) { event in
                        WidgetLink(route: .calendar) {
                            WidgetEventRow(event: event)
                        }
                    }
                    if let plan = entry.snapshot.plan {
                        WidgetLink(route: .plan(plan.id)) {
                            WidgetPlanLine(plan: plan)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .widgetURL(CorbieRoute.tasks.url)
            }
        }
    }
}

#if DEBUG
#Preview("Our day", as: .systemLarge) {
    OurDayWidget()
} timeline: {
    await OurDayEntry.load(now: Date(), provider: WidgetPreviewData.provider())
    OurDayEntry(date: Date(), snapshot: OurDaySnapshot(days: nil, tasks: [], events: [], plan: nil, isPremium: true))
    OurDayEntry(date: Date(), snapshot: OurDaySnapshot(days: 460, tasks: [], events: [], plan: nil, isPremium: false))
}
#endif
