import AppIntents
import CorbieCore
import SwiftUI
import WidgetKit

struct CountdownEntry: TimelineEntry {
    let date: Date
    let snapshot: CountdownSnapshot

    static let placeholder = CountdownEntry(
        date: Date(),
        snapshot: CountdownSnapshot(
            source: .anniversary,
            kind: .anniversary,
            title: nil,
            date: Date(),
            daysAway: 211,
            ordinal: 2,
            isPremium: true
        )
    )

    static func load(now: Date, source: CountdownSource, provider: WidgetDataProvider) async -> CountdownEntry {
        let snapshot = (try? await provider.countdown(source: source, now: now))
            ?? CountdownSnapshot(
                source: source,
                kind: nil,
                title: nil,
                date: nil,
                daysAway: nil,
                ordinal: nil,
                isPremium: true
            )
        return CountdownEntry(date: now, snapshot: snapshot)
    }
}

struct CountdownProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CountdownEntry {
        CountdownEntry.placeholder
    }

    func snapshot(for configuration: CountdownConfigurationIntent, in context: Context) async -> CountdownEntry {
        await CountdownEntry.load(
            now: Date(),
            source: configuration.countdownSource,
            provider: WidgetStore.provider()
        )
    }

    func timeline(
        for configuration: CountdownConfigurationIntent,
        in context: Context
    ) async -> Timeline<CountdownEntry> {
        let source = configuration.countdownSource
        return await WidgetTimelineBuilder.timeline { now in
            await CountdownEntry.load(now: now, source: source, provider: WidgetStore.provider())
        }
    }
}

struct CountdownWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetKinds.countdown,
            intent: CountdownConfigurationIntent.self,
            provider: CountdownProvider()
        ) { entry in
            CountdownWidgetView(entry: entry)
                .corbieWidgetSurface()
        }
        .configurationDisplayName(Text("widget.countdown.title"))
        .description(Text("widget.countdown.description"))
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

struct CountdownWidgetView: View {
    let entry: CountdownEntry

    private var label: String {
        WidgetDateLabel.countdown(
            kind: entry.snapshot.kind,
            ordinal: entry.snapshot.ordinal,
            title: entry.snapshot.title
        )
    }

    var body: some View {
        Group {
            if let daysAway = entry.snapshot.daysAway, let date = entry.snapshot.date {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: 0)
                    WidgetCounter(value: daysAway)
                    Text(label)
                        .corbieMono()
                        .foregroundStyle(CorbieColorPalette.text2)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Text(WidgetDateLabel.shortDate(date, now: entry.date))
                        .corbieMono()
                        .foregroundStyle(CorbieColorPalette.ice)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            } else {
                WidgetEmptyState(title: "widget.countdown.empty", note: "widget.countdown.empty.note")
            }
        }
        .widgetURL(CorbieRoute.calendar.url)
    }
}

#if DEBUG
#Preview("Countdown", as: .systemSmall) {
    CountdownWidget()
} timeline: {
    await CountdownEntry.load(now: Date(), source: .anniversary, provider: WidgetPreviewData.provider())
    await CountdownEntry.load(now: Date(), source: .partnerBirthday, provider: WidgetPreviewData.provider())
    CountdownEntry(
        date: Date(),
        snapshot: CountdownSnapshot(
            source: .wedding,
            kind: nil,
            title: nil,
            date: nil,
            daysAway: nil,
            ordinal: nil,
            isPremium: true
        )
    )
}
#endif
