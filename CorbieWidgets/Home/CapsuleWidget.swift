import CorbieCore
import SwiftUI
import WidgetKit

struct CapsuleEntry: TimelineEntry {
    let date: Date
    let snapshot: CapsuleSnapshot

    static let placeholder = CapsuleEntry(
        date: Date(),
        snapshot: CapsuleSnapshot(
            capsuleId: nil,
            authorName: nil,
            opensAt: Date(),
            daysAway: 185,
            isForViewer: true,
            isPremium: true
        )
    )

    static func load(now: Date, provider: WidgetDataProvider) async -> CapsuleEntry {
        let snapshot = (try? await provider.capsule(now: now))
            ?? CapsuleSnapshot(
                capsuleId: nil,
                authorName: nil,
                opensAt: nil,
                daysAway: nil,
                isForViewer: false,
                isPremium: true
            )
        return CapsuleEntry(date: now, snapshot: snapshot)
    }
}

struct CapsuleWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: WidgetKinds.capsule,
            provider: CorbieTimelineProvider(placeholderEntry: CapsuleEntry.placeholder) { now in
                await CapsuleEntry.load(now: now, provider: WidgetStore.provider())
            }
        ) { entry in
            CapsuleWidgetView(entry: entry)
                .corbieWidgetSurface()
        }
        .configurationDisplayName(Text("widget.capsule.title"))
        .description(Text("widget.capsule.description"))
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

struct CapsuleWidgetView: View {
    @Environment(\.palette) private var palette

    let entry: CapsuleEntry

    private var caption: String {
        guard entry.snapshot.isForViewer else { return String(localized: "widget.capsule.yours") }
        guard let name = entry.snapshot.authorName, name.isEmpty == false else {
            return String(localized: "widget.capsule.from.plain")
        }
        return String(format: String(localized: "widget.capsule.from"), name)
    }

    var body: some View {
        Group {
            if entry.snapshot.isPremium == false {
                LockedWidgetView()
            } else if let daysAway = entry.snapshot.daysAway, let opensAt = entry.snapshot.opensAt {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: 0)
                    WidgetCounter(value: daysAway)
                    WidgetCaption(text: caption)
                    Text(WidgetDateLabel.shortDate(opensAt, now: entry.date))
                        .corbieMono()
                        .foregroundStyle(palette.accent)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .widgetURL(CorbieRoute.capsules.url)
            } else {
                WidgetEmptyState(title: "widget.capsule.empty", note: "widget.capsule.empty.note")
                    .widgetURL(CorbieRoute.capsules.url)
            }
        }
    }
}

#if DEBUG
#Preview("Capsule", as: .systemSmall) {
    CapsuleWidget()
} timeline: {
    await CapsuleEntry.load(now: Date(), provider: WidgetPreviewData.provider())
    CapsuleEntry(
        date: Date(),
        snapshot: CapsuleSnapshot(
            capsuleId: nil,
            authorName: nil,
            opensAt: nil,
            daysAway: nil,
            isForViewer: false,
            isPremium: true
        )
    )
    CapsuleEntry(
        date: Date(),
        snapshot: CapsuleSnapshot(
            capsuleId: nil,
            authorName: nil,
            opensAt: nil,
            daysAway: nil,
            isForViewer: false,
            isPremium: false
        )
    )
}
#endif
