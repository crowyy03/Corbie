import CorbieCore
import SwiftUI
import WidgetKit

struct OurDayEntry: TimelineEntry {
    let date: Date
    let snapshot: OurDaySnapshot

    static let placeholder = OurDayEntry(
        date: Date(),
        snapshot: OurDaySnapshot(daysTogether: 460, isPremium: true)
    )

    static func load(now: Date, provider: WidgetDataProvider) async -> OurDayEntry {
        let snapshot = (try? await provider.ourDay(now: now)) ?? OurDaySnapshot(isPremium: true)
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

    private var snapshot: OurDaySnapshot { entry.snapshot }

    var body: some View {
        Group {
            if snapshot.isPremium == false {
                LockedWidgetView()
            } else if snapshot.isEmpty {
                WidgetEmptyState(title: "widget.ourday.empty", note: "widget.ourday.empty.note")
                    .widgetURL(CorbieRoute.today.url)
            } else {
                VStack(alignment: .leading, spacing: CorbieSpacing.s) {
                    header
                    today
                    freeTasks
                    comingUp
                    goal
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .widgetURL(CorbieRoute.today.url)
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        if let days = snapshot.daysTogether {
            WidgetLink(route: .today) {
                VStack(alignment: .leading, spacing: 0) {
                    WidgetCounter(value: days, compact: true)
                    Text("today.header.days")
                        .corbieMono()
                        .foregroundStyle(CorbieColorPalette.text2)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
        }
    }

    @ViewBuilder
    private var today: some View {
        if snapshot.entries.isEmpty == false {
            VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                WidgetHeading(text: String(localized: "today.block.today"))
                ForEach(snapshot.entries) { entry in
                    WidgetTodayRow(entry: entry)
                }
                if snapshot.entriesRemaining > 0 {
                    WidgetOverflowLine(count: snapshot.entriesRemaining)
                }
            }
        }
    }

    @ViewBuilder
    private var freeTasks: some View {
        if snapshot.freeTasks.isEmpty == false {
            VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                WidgetHeading(text: String(localized: "today.block.freetasks"))
                ForEach(snapshot.freeTasks) { task in
                    FreeTaskRow(task: task, now: entry.date)
                }
                if snapshot.freeTasksRemaining > 0 {
                    WidgetOverflowLine(count: snapshot.freeTasksRemaining)
                }
            }
        }
    }

    @ViewBuilder
    private var comingUp: some View {
        if let nextDate = snapshot.nextDate {
            WidgetLink(route: .calendar) {
                WidgetDateRow(date: nextDate, now: entry.date)
            }
        }
    }

    @ViewBuilder
    private var goal: some View {
        if let goal = snapshot.goal, let goalId = goal.goalId {
            WidgetLink(route: .goal(goalId)) {
                WidgetGoalLine(goal: goal)
            }
        }
    }
}

#if DEBUG
#Preview("Our day", as: .systemLarge) {
    OurDayWidget()
} timeline: {
    await OurDayEntry.load(now: Date(), provider: WidgetPreviewData.provider())
    OurDayEntry(date: Date(), snapshot: OurDaySnapshot(isPremium: true))
    OurDayEntry(date: Date(), snapshot: OurDaySnapshot(daysTogether: 460, isPremium: false))
}
#endif
