import CorbieCore
import SwiftUI
import WidgetKit

enum WidgetLayout {
    static let rowHeight: CGFloat = CorbieMetrics.minimumTapTarget
    static let dateRowHeight: CGFloat = 34
    static let wishRowHeight: CGFloat = 30
    static let markSize: CGFloat = 20
    static let markLine: CGFloat = 2
    static let stripeWidth: CGFloat = 3
}

struct WidgetSurface: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    private var theme: CorbieTheme {
        ThemeStore().settings.resolved(for: colorScheme)
    }

    func body(content: Content) -> some View {
        content
            .padding(CorbieSpacing.s)
            .containerBackground(for: .widget) {
                theme.palette.bg
            }
            .corbieTheme(theme)
    }
}

extension View {
    func corbieWidgetSurface() -> some View {
        modifier(WidgetSurface())
    }

    func corbieAccessorySurface() -> some View {
        containerBackground(for: .widget) {
            Color.clear
        }
    }
}

struct WidgetHeading: View {
    @Environment(\.palette) private var palette

    let text: String

    var body: some View {
        Text(text)
            .corbieSectionCaps()
            .foregroundStyle(palette.text2)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .accessibilityAddTraits(.isHeader)
    }
}

struct WidgetCounter: View {
    @Environment(\.palette) private var palette

    let value: Int
    var compact = false

    var body: some View {
        Group {
            if compact {
                Text(value, format: .number).corbieScreenTitle()
            } else {
                Text(value, format: .number).corbieCounter()
            }
        }
        .foregroundStyle(palette.text)
        .minimumScaleFactor(0.4)
        .lineLimit(1)
    }
}

struct WidgetCaption: View {
    @Environment(\.palette) private var palette

    let text: String

    var body: some View {
        Text(text)
            .corbieMono()
            .foregroundStyle(palette.text2)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
    }
}

struct WidgetEmptyState: View {
    @Environment(\.palette) private var palette

    let title: LocalizedStringKey
    let note: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
            Text(title)
                .corbieBody()
                .foregroundStyle(palette.text)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(note)
                .corbieMono()
                .foregroundStyle(palette.text2)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct LockedWidgetView: View {
    var body: some View {
        WidgetEmptyState(title: "widget.locked.title", note: "widget.locked.note")
            .widgetURL(CorbieRoute.paywall.url)
    }
}

struct LockedAccessoryView: View {
    var body: some View {
        Text("widget.locked.short")
            .widgetAccentable()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .widgetURL(CorbieRoute.paywall.url)
    }
}

struct LockedCircularView: View {
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: "lock")
                .widgetAccentable()
        }
        .accessibilityLabel(Text("widget.locked.short"))
        .widgetURL(CorbieRoute.paywall.url)
    }
}

struct WidgetLink<Content: View>: View {
    let route: CorbieRoute
    @ViewBuilder let content: Content

    var body: some View {
        if let url = route.url {
            Link(destination: url) {
                content.contentShape(Rectangle())
            }
        } else {
            content
        }
    }
}

struct WidgetOverflowLine: View {
    @Environment(\.palette) private var palette

    let count: Int

    var body: some View {
        Text(String(localized: "widget.more", defaultValue: "+\(count) more"))
            .corbieMono()
            .foregroundStyle(palette.text2)
            .lineLimit(1)
    }
}

struct WidgetTaskRow: View {
    @Environment(\.palette) private var palette

    let task: WidgetTask
    let now: Date

    private var markColor: Color {
        guard task.isFree == false, let colorKey = task.colorKey else { return palette.text2 }
        return palette.member(storedKey: colorKey)
    }

    var body: some View {
        HStack(spacing: 0) {
            Button(intent: ToggleTaskDoneIntent(taskID: task.id)) {
                Circle()
                    .strokeBorder(markColor, lineWidth: WidgetLayout.markLine)
                    .frame(width: WidgetLayout.markSize, height: WidgetLayout.markSize)
                    .frame(width: CorbieMetrics.minimumTapTarget, height: WidgetLayout.rowHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                Text(String(format: String(localized: "widget.tasks.done.accessibility"), task.title))
            )
            WidgetTaskText(task: task, now: now)
            Spacer(minLength: CorbieSpacing.xs)
        }
        .frame(height: WidgetLayout.rowHeight)
    }
}

struct WidgetTaskText: View {
    @Environment(\.palette) private var palette

    let task: WidgetTask
    let now: Date

    private var dueText: String? {
        guard let dueAt = task.dueAt else { return nil }
        let text = WidgetDateLabel.shortDate(dueAt, now: now)
        let daysAway = Calendar.current.daysAway(from: now, to: dueAt) ?? 0
        let key = daysAway < 0 ? "tasks.row.due.past" : "tasks.row.due"
        return String(format: String(localized: String.LocalizationValue(key)), text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(task.title)
                .corbieBody()
                .foregroundStyle(palette.text)
                .lineLimit(1)
            if let dueText {
                Text(dueText)
                    .corbieMono()
                    .foregroundStyle(palette.text2)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct WidgetDateRow: View {
    @Environment(\.palette) private var palette

    let date: WidgetDate
    let now: Date

    private var stripeColor: Color {
        guard let colorKey = date.colorKey else { return palette.accent }
        return palette.member(storedKey: colorKey)
    }

    private var subtitle: String {
        guard let radar = date.radar else { return WidgetDateLabel.relativeDays(date.daysAway) }
        return RadarText(daysAway: date.daysAway, status: radar).line()
    }

    var body: some View {
        HStack(spacing: CorbieSpacing.xs) {
            Capsule(style: .continuous)
                .fill(stripeColor)
                .frame(width: WidgetLayout.stripeWidth)
            VStack(alignment: .leading, spacing: 0) {
                Text(WidgetDateLabel.upcoming(kind: date.kind, title: date.title, ordinal: date.ordinal))
                    .corbieBody()
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
                Text(subtitle)
                    .corbieMono()
                    .foregroundStyle(palette.text2)
                    .lineLimit(1)
            }
            Spacer(minLength: CorbieSpacing.xs)
            Text(WidgetDateLabel.shortDate(date.date, now: now))
                .corbieMono()
                .foregroundStyle(palette.text2)
                .lineLimit(1)
        }
        .frame(height: WidgetLayout.dateRowHeight)
        .accessibilityElement(children: .combine)
    }
}

struct WidgetEventRow: View {
    @Environment(\.palette) private var palette

    let event: WidgetEvent

    private var stripeColor: Color {
        guard let colorKey = event.colorKey else { return palette.accent }
        return palette.member(storedKey: colorKey)
    }

    var body: some View {
        HStack(spacing: CorbieSpacing.xs) {
            Capsule(style: .continuous)
                .fill(stripeColor)
                .frame(width: WidgetLayout.stripeWidth)
            Text(event.title)
                .corbieBody()
                .foregroundStyle(palette.text)
                .lineLimit(1)
            Spacer(minLength: CorbieSpacing.xs)
            if let startAt = event.startAt, event.isAllDay == false {
                Text(startAt, style: .time)
                    .corbieMono()
                    .foregroundStyle(palette.text2)
                    .lineLimit(1)
            } else {
                Text("today.row.allday")
                    .corbieMono()
                    .foregroundStyle(palette.text2)
                    .lineLimit(1)
            }
        }
        .frame(height: WidgetLayout.dateRowHeight)
        .accessibilityElement(children: .combine)
    }
}

struct WidgetFreeSlotRow: View {
    @Environment(\.palette) private var palette

    let slot: WidgetFreeSlot

    var body: some View {
        HStack(spacing: CorbieSpacing.xs) {
            Capsule(style: .continuous)
                .fill(palette.accent)
                .frame(width: WidgetLayout.stripeWidth)
            Text(slot.dayText)
                .corbieBody()
                .foregroundStyle(palette.text)
                .lineLimit(1)
            Spacer(minLength: CorbieSpacing.xs)
            Text(slot.windowText)
                .corbieMono()
                .foregroundStyle(palette.text2)
                .lineLimit(1)
        }
        .frame(height: WidgetLayout.dateRowHeight)
        .accessibilityElement(children: .combine)
    }
}

struct WidgetPlanLine: View {
    @Environment(\.palette) private var palette

    private let title: String
    private let progress: Double
    private let overspentFraction: Double
    private let amountText: String?
    private let overspendText: String?
    private let stepsText: String?

    init(plan: PlanProgressSnapshot) {
        self.init(
            title: plan.title ?? "",
            progress: plan.progress,
            overspentFraction: plan.overspentFraction,
            saved: plan.savedText,
            target: plan.targetText,
            overspent: plan.overspentText,
            doneStepCount: plan.doneStepCount,
            stepCount: plan.stepCount
        )
    }

    init(plan: TodayPlan) {
        self.init(
            title: plan.title,
            progress: plan.progress,
            overspentFraction: 0,
            saved: plan.savedText,
            target: plan.targetText,
            overspent: nil,
            doneStepCount: plan.doneStepCount,
            stepCount: plan.stepCount
        )
    }

    private init(
        title: String,
        progress: Double,
        overspentFraction: Double,
        saved: String?,
        target: String?,
        overspent: String?,
        doneStepCount: Int,
        stepCount: Int
    ) {
        self.title = title
        self.progress = progress
        self.overspentFraction = overspentFraction
        if let saved, let target {
            amountText = String(format: String(localized: "plans.card.progress"), saved, target)
        } else {
            amountText = nil
        }
        overspendText = overspent.map { String(format: String(localized: "plans.card.overspend"), $0) }
        stepsText = stepCount > 0
            ? String(
                format: String(localized: "plans.card.steps"),
                doneStepCount.formatted(.number),
                stepCount.formatted(.number)
            )
            : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
            HStack(spacing: CorbieSpacing.xs) {
                Text(title)
                    .corbieBody()
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
                Spacer(minLength: CorbieSpacing.xs)
                if let overspendText {
                    Text(overspendText)
                        .corbieMono()
                        .foregroundStyle(palette.warn)
                        .lineLimit(1)
                }
            }
            ProgressBar(
                value: progress,
                overspend: overspentFraction,
                accessibilityLabel: String(localized: "plans.card.progress.label"),
                accessibilityValue: amountText ?? ""
            )
            HStack(spacing: CorbieSpacing.xs) {
                if let amountText {
                    Text(amountText)
                        .corbieMono()
                        .foregroundStyle(palette.text2)
                        .lineLimit(1)
                }
                Spacer(minLength: CorbieSpacing.xs)
                if let stepsText {
                    Text(stepsText)
                        .corbieMono()
                        .foregroundStyle(palette.text2)
                        .lineLimit(1)
                }
            }
        }
    }
}
