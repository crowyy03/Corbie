import CorbieCore
import SwiftUI
import WidgetKit

struct LockRectangularEntry: TimelineEntry {
    let date: Date
    let snapshot: LockRectangularSnapshot

    static let placeholder = LockRectangularEntry(
        date: Date(),
        snapshot: LockRectangularSnapshot(
            taskTitle: nil,
            taskId: nil,
            freeCount: 0,
            nextDate: nil,
            isPremium: true
        )
    )

    static func load(now: Date, provider: WidgetDataProvider) async -> LockRectangularEntry {
        let snapshot = (try? await provider.lockRectangular(now: now))
            ?? LockRectangularSnapshot(
                taskTitle: nil,
                taskId: nil,
                freeCount: 0,
                nextDate: nil,
                isPremium: true
            )
        return LockRectangularEntry(date: now, snapshot: snapshot)
    }
}

struct LockRectangularWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: WidgetKinds.lockRectangular,
            provider: CorbieTimelineProvider(placeholderEntry: LockRectangularEntry.placeholder) { now in
                await LockRectangularEntry.load(now: now, provider: WidgetStore.provider())
            }
        ) { entry in
            LockRectangularWidgetView(entry: entry)
                .corbieAccessorySurface()
        }
        .configurationDisplayName(Text("widget.lock.rectangular.title"))
        .description(Text("widget.lock.rectangular.description"))
        .supportedFamilies([.accessoryRectangular])
    }
}

struct LockRectangularWidgetView: View {
    let entry: LockRectangularEntry

    private var freeText: String? {
        guard entry.snapshot.freeCount > 0 else { return nil }
        return String(
            localized: "widget.lock.rectangular.free",
            defaultValue: "+\(entry.snapshot.freeCount) free"
        )
    }

    var body: some View {
        Group {
            if entry.snapshot.isPremium == false {
                LockedAccessoryView()
            } else if let taskTitle = entry.snapshot.taskTitle {
                VStack(alignment: .leading, spacing: 0) {
                    Text("widget.lock.rectangular.heading")
                        .font(.headline)
                        .widgetAccentable()
                        .lineLimit(1)
                    Text(taskTitle)
                        .lineLimit(1)
                    if let freeText {
                        Text(freeText)
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .widgetURL(CorbieRoute.tasks.url)
            } else if let nextDate = entry.snapshot.nextDate {
                VStack(alignment: .leading, spacing: 0) {
                    Text(WidgetDateLabel.relativeDays(nextDate.daysAway))
                        .font(.headline)
                        .widgetAccentable()
                        .lineLimit(1)
                    Text(WidgetDateLabel.upcoming(nextDate))
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .widgetURL(CorbieRoute.calendar.url)
            } else {
                Text("widget.lock.rectangular.empty")
                    .lineLimit(2)
                    .widgetURL(CorbieRoute.tasks.url)
            }
        }
    }
}

#if DEBUG
#Preview("Lock rectangular", as: .accessoryRectangular) {
    LockRectangularWidget()
} timeline: {
    await LockRectangularEntry.load(now: Date(), provider: WidgetPreviewData.provider())
    LockRectangularEntry(
        date: Date(),
        snapshot: LockRectangularSnapshot(taskTitle: nil, taskId: nil, freeCount: 0, nextDate: nil, isPremium: true)
    )
    LockRectangularEntry(
        date: Date(),
        snapshot: LockRectangularSnapshot(taskTitle: nil, taskId: nil, freeCount: 0, nextDate: nil, isPremium: false)
    )
}
#endif
