import CorbieCore
import SwiftUI
import WidgetKit

struct LockInlineEntry: TimelineEntry {
    let date: Date
    let snapshot: LockInlineSnapshot

    static let placeholder = LockInlineEntry(
        date: Date(),
        snapshot: LockInlineSnapshot(kind: .personBirthday, name: nil, daysAway: 11, isPremium: true)
    )

    static func load(now: Date, provider: WidgetDataProvider) async -> LockInlineEntry {
        let snapshot = (try? await provider.lockInline(now: now))
            ?? LockInlineSnapshot(kind: nil, name: nil, daysAway: nil, isPremium: true)
        return LockInlineEntry(date: now, snapshot: snapshot)
    }
}

struct LockInlineWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: WidgetKinds.lockInline,
            provider: CorbieTimelineProvider(placeholderEntry: LockInlineEntry.placeholder) { now in
                await LockInlineEntry.load(now: now, provider: WidgetStore.provider())
            }
        ) { entry in
            LockInlineWidgetView(entry: entry)
                .corbieAccessorySurface()
        }
        .configurationDisplayName(Text("widget.lock.inline.title"))
        .description(Text("widget.lock.inline.description"))
        .supportedFamilies([.accessoryInline])
    }
}

struct LockInlineWidgetView: View {
    let entry: LockInlineEntry

    private var line: String? {
        guard let kind = entry.snapshot.kind, let daysAway = entry.snapshot.daysAway else { return nil }
        return String(
            format: String(localized: "widget.lock.inline.line"),
            WidgetDateLabel.relativeDays(daysAway),
            WidgetDateLabel.upcoming(kind: kind, title: entry.snapshot.name)
        )
    }

    var body: some View {
        Group {
            if entry.snapshot.isPremium == false {
                LockedAccessoryView()
            } else if let line {
                Text(line)
                    .widgetURL(CorbieRoute.calendar.url)
            } else {
                Text("widget.lock.inline.empty")
                    .widgetURL(CorbieRoute.calendar.url)
            }
        }
    }
}

#if DEBUG
#Preview("Lock inline", as: .accessoryInline) {
    LockInlineWidget()
} timeline: {
    await LockInlineEntry.load(now: Date(), provider: WidgetPreviewData.provider())
    LockInlineEntry(
        date: Date(),
        snapshot: LockInlineSnapshot(kind: nil, name: nil, daysAway: nil, isPremium: true)
    )
    LockInlineEntry(
        date: Date(),
        snapshot: LockInlineSnapshot(kind: nil, name: nil, daysAway: nil, isPremium: false)
    )
}
#endif
