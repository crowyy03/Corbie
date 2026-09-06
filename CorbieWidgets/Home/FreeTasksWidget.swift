import CorbieCore
import SwiftUI
import WidgetKit

struct FreeTasksEntry: TimelineEntry {
    let date: Date
    let snapshot: TasksSnapshot

    static let placeholder = FreeTasksEntry(
        date: Date(),
        snapshot: TasksSnapshot(items: [], remaining: 0, isPremium: true)
    )

    static func load(now: Date, provider: WidgetDataProvider) async -> FreeTasksEntry {
        let snapshot = (try? await provider.freeTasks(now: now))
            ?? TasksSnapshot(items: [], remaining: 0, isPremium: true)
        return FreeTasksEntry(date: now, snapshot: snapshot)
    }
}

struct FreeTasksWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: WidgetKinds.freeTasks,
            provider: CorbieTimelineProvider(placeholderEntry: FreeTasksEntry.placeholder) { now in
                await FreeTasksEntry.load(now: now, provider: WidgetStore.provider())
            }
        ) { entry in
            FreeTasksWidgetView(entry: entry)
                .corbieWidgetSurface()
        }
        .configurationDisplayName(Text("widget.freetasks.title"))
        .description(Text("widget.freetasks.description"))
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

struct FreeTasksWidgetView: View {
    let entry: FreeTasksEntry

    var body: some View {
        Group {
            if entry.snapshot.isPremium == false {
                LockedWidgetView()
            } else if entry.snapshot.items.isEmpty {
                WidgetEmptyState(title: "widget.freetasks.empty", note: "widget.freetasks.empty.note")
                    .widgetURL(CorbieRoute.tasks.url)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(entry.snapshot.items) { task in
                        FreeTaskRow(task: task, now: entry.date)
                    }
                    if entry.snapshot.remaining > 0 {
                        WidgetOverflowLine(count: entry.snapshot.remaining)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .widgetURL(CorbieRoute.tasks.url)
            }
        }
    }
}

struct FreeTaskRow: View {
    let task: WidgetTask
    let now: Date

    var body: some View {
        HStack(spacing: CorbieSpacing.xs) {
            MemberDot(color: CorbieColorPalette.text2)
            WidgetTaskText(task: task, now: now)
            Spacer(minLength: CorbieSpacing.xs)
            Button(intent: TakeTaskIntent(taskID: task.id)) {
                Text("widget.freetasks.take")
                    .corbieMono()
                    .foregroundStyle(CorbieColorPalette.accentInk)
                    .padding(.horizontal, CorbieSpacing.s)
                    .frame(height: CorbieMetrics.chipHeight)
                    .background(CorbieColorPalette.ice, in: Capsule(style: .continuous))
                    .frame(height: WidgetLayout.rowHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                Text(String(format: String(localized: "widget.freetasks.take.accessibility"), task.title))
            )
        }
        .frame(height: WidgetLayout.rowHeight)
    }
}

#if DEBUG
#Preview("Free tasks", as: .systemMedium) {
    FreeTasksWidget()
} timeline: {
    await FreeTasksEntry.load(now: Date(), provider: WidgetPreviewData.provider())
    FreeTasksEntry(date: Date(), snapshot: TasksSnapshot(items: [], remaining: 0, isPremium: true))
    FreeTasksEntry(date: Date(), snapshot: TasksSnapshot(items: [], remaining: 0, isPremium: false))
}
#endif
