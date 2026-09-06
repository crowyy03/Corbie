import AppIntents
import CorbieCore
import SwiftUI
import WidgetKit

struct GoalProgressEntry: TimelineEntry {
    let date: Date
    let snapshot: GoalProgressSnapshot

    static let placeholder = GoalProgressEntry(
        date: Date(),
        snapshot: GoalProgressSnapshot(
            goalId: nil,
            title: nil,
            progress: 0.48,
            savedText: nil,
            targetText: nil,
            isOverspent: false,
            overspentText: nil,
            isPremium: true
        )
    )

    static func load(now: Date, goalId: UUID?, provider: WidgetDataProvider) async -> GoalProgressEntry {
        let snapshot = (try? await provider.goalProgress(goalId: goalId, now: now))
            ?? GoalProgressSnapshot(
                goalId: goalId,
                title: nil,
                progress: 0,
                savedText: nil,
                targetText: nil,
                isOverspent: false,
                overspentText: nil,
                isPremium: true
            )
        return GoalProgressEntry(date: now, snapshot: snapshot)
    }
}

struct GoalProgressProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> GoalProgressEntry {
        GoalProgressEntry.placeholder
    }

    func snapshot(for configuration: GoalProgressConfigurationIntent, in context: Context) async -> GoalProgressEntry {
        await GoalProgressEntry.load(now: Date(), goalId: configuration.goalId, provider: WidgetStore.provider())
    }

    func timeline(
        for configuration: GoalProgressConfigurationIntent,
        in context: Context
    ) async -> Timeline<GoalProgressEntry> {
        let goalId = configuration.goalId
        return await WidgetTimelineBuilder.timeline { now in
            await GoalProgressEntry.load(now: now, goalId: goalId, provider: WidgetStore.provider())
        }
    }
}

struct GoalProgressWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetKinds.goalProgress,
            intent: GoalProgressConfigurationIntent.self,
            provider: GoalProgressProvider()
        ) { entry in
            GoalProgressWidgetView(entry: entry)
                .corbieWidgetSurface()
        }
        .configurationDisplayName(Text("widget.goal.title"))
        .description(Text("widget.goal.description"))
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

struct GoalProgressWidgetView: View {
    let entry: GoalProgressEntry

    private var route: CorbieRoute {
        guard let goalId = entry.snapshot.goalId else { return .goals }
        return .goal(goalId)
    }

    var body: some View {
        Group {
            if entry.snapshot.isPremium == false {
                LockedWidgetView()
            } else if entry.snapshot.goalId == nil {
                WidgetEmptyState(title: "widget.goal.empty", note: "widget.goal.empty.note")
                    .widgetURL(route.url)
            } else {
                VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
                    WidgetHeading(text: String(localized: "widget.goal.heading"))
                    Spacer(minLength: 0)
                    WidgetGoalLine(goal: entry.snapshot)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .widgetURL(route.url)
            }
        }
    }
}

#if DEBUG
#Preview("Goal progress", as: .systemMedium) {
    GoalProgressWidget()
} timeline: {
    await GoalProgressEntry.load(now: Date(), goalId: nil, provider: WidgetPreviewData.provider())
    GoalProgressEntry(
        date: Date(),
        snapshot: GoalProgressSnapshot(
            goalId: UUID(),
            title: "Kitchen",
            progress: 1,
            savedText: "$5,000",
            targetText: "$5,000",
            isOverspent: true,
            overspentText: "$340",
            isPremium: true
        )
    )
    GoalProgressEntry(
        date: Date(),
        snapshot: GoalProgressSnapshot(
            goalId: nil,
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
