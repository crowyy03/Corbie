import AppIntents
import CorbieCore
import SwiftUI
import WidgetKit

struct PlanProgressEntry: TimelineEntry {
    let date: Date
    let snapshot: PlanProgressSnapshot

    static let placeholder = PlanProgressEntry(
        date: Date(),
        snapshot: PlanProgressSnapshot(
            planId: nil,
            title: nil,
            progress: 0.48,
            savedText: nil,
            targetText: nil,
            isOverspent: false,
            overspentText: nil,
            isPremium: true
        )
    )

    static func load(now: Date, planId: UUID?, provider: WidgetDataProvider) async -> PlanProgressEntry {
        let snapshot = (try? await provider.planProgress(planId: planId, now: now))
            ?? PlanProgressSnapshot(
                planId: planId,
                title: nil,
                progress: 0,
                savedText: nil,
                targetText: nil,
                isOverspent: false,
                overspentText: nil,
                isPremium: true
            )
        return PlanProgressEntry(date: now, snapshot: snapshot)
    }
}

struct PlanProgressProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PlanProgressEntry {
        PlanProgressEntry.placeholder
    }

    func snapshot(for configuration: PlanProgressConfigurationIntent, in context: Context) async -> PlanProgressEntry {
        await PlanProgressEntry.load(now: Date(), planId: configuration.planId, provider: WidgetStore.provider())
    }

    func timeline(
        for configuration: PlanProgressConfigurationIntent,
        in context: Context
    ) async -> Timeline<PlanProgressEntry> {
        let planId = configuration.planId
        return await WidgetTimelineBuilder.timeline { now in
            await PlanProgressEntry.load(now: now, planId: planId, provider: WidgetStore.provider())
        }
    }
}

struct PlanProgressWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetKinds.planProgress,
            intent: PlanProgressConfigurationIntent.self,
            provider: PlanProgressProvider()
        ) { entry in
            PlanProgressWidgetView(entry: entry)
                .corbieWidgetSurface()
        }
        .configurationDisplayName(Text("widget.plan.title"))
        .description(Text("widget.plan.description"))
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

struct PlanProgressWidgetView: View {
    let entry: PlanProgressEntry

    private var route: CorbieRoute {
        guard let planId = entry.snapshot.planId else { return .plans }
        return .plan(planId)
    }

    var body: some View {
        Group {
            if entry.snapshot.isPremium == false {
                LockedWidgetView()
            } else if entry.snapshot.planId == nil {
                WidgetEmptyState(title: "widget.plan.empty", note: "widget.plan.empty.note")
                    .widgetURL(route.url)
            } else {
                VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
                    WidgetHeading(text: String(localized: "widget.plan.heading"))
                    Spacer(minLength: 0)
                    WidgetPlanLine(plan: entry.snapshot)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .widgetURL(route.url)
            }
        }
    }
}

#if DEBUG
#Preview("Plan progress", as: .systemMedium) {
    PlanProgressWidget()
} timeline: {
    await PlanProgressEntry.load(now: Date(), planId: nil, provider: WidgetPreviewData.provider())
    PlanProgressEntry(
        date: Date(),
        snapshot: PlanProgressSnapshot(
            planId: UUID(),
            title: "Kitchen",
            progress: 1,
            savedText: "$5,000",
            targetText: "$5,000",
            isOverspent: true,
            overspentText: "$340",
            isPremium: true
        )
    )
    PlanProgressEntry(
        date: Date(),
        snapshot: PlanProgressSnapshot(
            planId: UUID(),
            title: "The pot",
            progress: 0,
            savedText: "$1,640",
            targetText: nil,
            isOverspent: false,
            overspentText: nil,
            isOpenEnded: true,
            expenseCount: 6,
            isPremium: true
        )
    )
    PlanProgressEntry(
        date: Date(),
        snapshot: PlanProgressSnapshot(
            planId: nil,
            title: nil,
            progress: 0,
            savedText: nil,
            targetText: nil,
            isOverspent: false,
            overspentText: nil,
            isPremium: false
        )
    )
}
#endif
