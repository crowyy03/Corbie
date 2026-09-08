import AppIntents
import CorbieCore
import SwiftUI
import WidgetKit

struct LockCircularEntry: TimelineEntry {
    let date: Date
    let snapshot: LockCircularSnapshot

    static let placeholder = LockCircularEntry(
        date: Date(),
        snapshot: LockCircularSnapshot(mode: .daysTogether, value: 460, progress: nil, isPremium: true)
    )

    static func load(now: Date, mode: LockCircularMode, provider: WidgetDataProvider) async -> LockCircularEntry {
        let snapshot = (try? await provider.lockCircular(mode: mode, now: now))
            ?? LockCircularSnapshot(mode: mode, value: nil, progress: nil, isPremium: true)
        return LockCircularEntry(date: now, snapshot: snapshot)
    }
}

struct LockCircularProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> LockCircularEntry {
        LockCircularEntry.placeholder
    }

    func snapshot(for configuration: LockCircularConfigurationIntent, in context: Context) async -> LockCircularEntry {
        await LockCircularEntry.load(
            now: Date(),
            mode: configuration.circularMode,
            provider: WidgetStore.provider()
        )
    }

    func timeline(
        for configuration: LockCircularConfigurationIntent,
        in context: Context
    ) async -> Timeline<LockCircularEntry> {
        let mode = configuration.circularMode
        return await WidgetTimelineBuilder.timeline { now in
            await LockCircularEntry.load(now: now, mode: mode, provider: WidgetStore.provider())
        }
    }
}

struct LockCircularWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetKinds.lockCircular,
            intent: LockCircularConfigurationIntent.self,
            provider: LockCircularProvider()
        ) { entry in
            LockCircularWidgetView(entry: entry)
                .corbieAccessorySurface()
        }
        .configurationDisplayName(Text("widget.lock.circular.title"))
        .description(Text("widget.lock.circular.description"))
        .supportedFamilies([.accessoryCircular])
    }
}

struct LockCircularWidgetView: View {
    let entry: LockCircularEntry

    private var route: CorbieRoute {
        switch entry.snapshot.mode {
        case .daysTogether: return .us
        case .planRing: return .plans
        case .countdown: return .calendar
        }
    }

    private var accessibilityLabel: String {
        switch entry.snapshot.mode {
        case .daysTogether: return String(localized: "us.counters.days")
        case .planRing:
            return entry.snapshot.progress == nil
                ? String(localized: "plans.detail.saved")
                : String(localized: "plans.card.progress.label")
        case .countdown: return String(localized: "widget.dates.heading")
        }
    }

    var body: some View {
        Group {
            if entry.snapshot.isPremium == false {
                LockedCircularView()
            } else if entry.snapshot.mode == .planRing, let progress = entry.snapshot.progress {
                ring(progress: progress)
            } else if let value = entry.snapshot.value {
                ZStack {
                    AccessoryWidgetBackground()
                    Text(value, format: .number)
                        .font(.system(.title2, design: .rounded).weight(.heavy))
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                        .padding(CorbieSpacing.xxs)
                }
                .widgetAccentable()
                .accessibilityLabel(Text(accessibilityLabel))
                .accessibilityValue(Text(value, format: .number))
                .widgetURL(route.url)
            } else {
                ZStack {
                    AccessoryWidgetBackground()
                    Image(systemName: "calendar")
                        .widgetAccentable()
                }
                .accessibilityLabel(Text(accessibilityLabel))
                .widgetURL(route.url)
            }
        }
    }

    private func ring(progress: Double) -> some View {
        Gauge(value: min(max(progress, 0), 1)) {
            Text("widget.lock.circular.plan")
        } currentValueLabel: {
            Text((entry.snapshot.value ?? 0), format: .number)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetAccentable()
        .accessibilityLabel(Text(accessibilityLabel))
        .widgetURL(route.url)
    }
}

#if DEBUG
#Preview("Lock circular", as: .accessoryCircular) {
    LockCircularWidget()
} timeline: {
    await LockCircularEntry.load(now: Date(), mode: .daysTogether, provider: WidgetPreviewData.provider())
    await LockCircularEntry.load(now: Date(), mode: .planRing, provider: WidgetPreviewData.provider())
    await LockCircularEntry.load(now: Date(), mode: .countdown, provider: WidgetPreviewData.provider())
    LockCircularEntry(
        date: Date(),
        snapshot: LockCircularSnapshot(mode: .daysTogether, value: nil, progress: nil, isPremium: false)
    )
}
#endif
