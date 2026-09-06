import CorbieCore
import SwiftUI
import WidgetKit

struct TasksEntry: TimelineEntry {
    let date: Date
    let snapshot: TasksSnapshot

    static let placeholder = TasksEntry(
        date: Date(),
        snapshot: TasksSnapshot(items: [], remaining: 0, isPremium: true)
    )

    static func load(now: Date, provider: WidgetDataProvider) async -> TasksEntry {
        let snapshot = (try? await provider.tasks(now: now))
            ?? TasksSnapshot(items: [], remaining: 0, isPremium: true)
        return TasksEntry(date: now, snapshot: snapshot)
    }
}

struct TasksWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: WidgetKinds.tasks,
            provider: CorbieTimelineProvider(placeholderEntry: TasksEntry.placeholder) { now in
                await TasksEntry.load(now: now, provider: WidgetStore.provider())
            }
        ) { entry in
            TasksWidgetView(entry: entry)
                .corbieWidgetSurface()
        }
        .configurationDisplayName(Text("widget.tasks.title"))
        .description(Text("widget.tasks.description"))
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

struct TasksWidgetView: View {
    let entry: TasksEntry

    var body: some View {
        Group {
            if entry.snapshot.isPremium == false {
                LockedWidgetView()
            } else if entry.snapshot.items.isEmpty {
                WidgetEmptyState(title: "widget.tasks.empty", note: "widget.tasks.empty.note")
                    .widgetURL(CorbieRoute.tasks.url)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(entry.snapshot.items) { task in
                        WidgetTaskRow(task: task, now: entry.date)
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
#Preview("Tasks", as: .systemMedium) {
    TasksWidget()
} timeline: {
    await TasksEntry.load(now: Date(), provider: WidgetPreviewData.provider())
    TasksEntry(date: Date(), snapshot: TasksSnapshot(items: [], remaining: 0, isPremium: true))
    TasksEntry(date: Date(), snapshot: TasksSnapshot(items: [], remaining: 0, isPremium: false))
}
#endif
