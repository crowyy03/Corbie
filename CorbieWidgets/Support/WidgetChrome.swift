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

extension View {
    func corbieWidgetSurface() -> some View {
        padding(CorbieSpacing.s)
            .containerBackground(for: .widget) {
                CorbieColorPalette.bg
            }
    }

    func corbieAccessorySurface() -> some View {
        containerBackground(for: .widget) {
            Color.clear
        }
    }
}

struct WidgetHeading: View {
    let text: String

    var body: some View {
        Text(text)
            .corbieSectionCaps()
            .foregroundStyle(CorbieColorPalette.text2)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .accessibilityAddTraits(.isHeader)
    }
}

struct WidgetCounter: View {
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
        .foregroundStyle(CorbieColorPalette.text)
        .minimumScaleFactor(0.4)
        .lineLimit(1)
    }
}

struct WidgetCaption: View {
    let text: String

    var body: some View {
        Text(text)
            .corbieMono()
            .foregroundStyle(CorbieColorPalette.text2)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
    }
}

struct WidgetEmptyState: View {
    let title: LocalizedStringKey
    let note: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
            Text(title)
                .corbieBody()
                .foregroundStyle(CorbieColorPalette.text)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(note)
                .corbieMono()
                .foregroundStyle(CorbieColorPalette.text2)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct LockedWidgetView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
            Text("widget.locked.title")
                .corbieBody()
                .foregroundStyle(CorbieColorPalette.text)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text("widget.locked.note")
                .corbieMono()
                .foregroundStyle(CorbieColorPalette.text2)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
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
    let count: Int

    var body: some View {
        Text(String(localized: "widget.more", defaultValue: "+\(count) more"))
            .corbieMono()
            .foregroundStyle(CorbieColorPalette.text2)
            .lineLimit(1)
    }
}

struct WidgetTaskMark: View {
    let color: Color

    var body: some View {
        Circle()
            .strokeBorder(color, lineWidth: WidgetLayout.markLine)
            .frame(width: WidgetLayout.markSize, height: WidgetLayout.markSize)
            .frame(width: CorbieMetrics.minimumTapTarget, height: WidgetLayout.rowHeight)
            .contentShape(Rectangle())
    }
}

struct WidgetTaskRow: View {
    let task: WidgetTask
    let now: Date

    private var markColor: Color {
        guard task.isFree == false, let colorKey = task.colorKey else { return CorbieColorPalette.text2 }
        return MemberColor(key: colorKey).color
    }

    private var doneLabel: Text {
        Text(String(format: String(localized: "widget.tasks.done.accessibility"), task.title))
    }

    var body: some View {
        HStack(spacing: 0) {
            Group {
                switch task.source {
                case .task:
                    Button(intent: ToggleTaskDoneIntent(taskID: task.id)) {
                        WidgetTaskMark(color: markColor)
                    }
                case .goalStep:
                    Button(intent: ToggleGoalStepIntent(stepID: task.id)) {
                        WidgetTaskMark(color: markColor)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(doneLabel)
            WidgetTaskText(task: task, now: now)
            Spacer(minLength: CorbieSpacing.xs)
        }
        .frame(height: WidgetLayout.rowHeight)
    }
}

struct WidgetTaskText: View {
    let task: WidgetTask
    let now: Date

    private var caption: String? {
        if let goalTitle = task.goalTitle {
            return String(format: String(localized: "tasks.row.subtitle.fromgoal"), goalTitle)
        }
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
                .foregroundStyle(CorbieColorPalette.text)
                .lineLimit(1)
            if let caption {
                Text(caption)
                    .corbieMono()
                    .foregroundStyle(CorbieColorPalette.text2)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct WidgetTodayRow: View {
    let entry: WidgetTodayEntry

    private var dotColor: Color {
        guard let colorKey = entry.colorKey else { return CorbieColorPalette.text2 }
        return MemberColor(key: colorKey).color
    }

    private var caption: String {
        if let goalTitle = entry.goalTitle {
            return String(format: String(localized: "today.row.fromgoal"), goalTitle)
        }
        guard let timeText = entry.timeText else { return String(localized: "today.row.allday") }
        return timeText
    }

    var body: some View {
        HStack(spacing: CorbieSpacing.xs) {
            MemberDot(color: dotColor)
            Text(entry.title)
                .corbieBody()
                .foregroundStyle(CorbieColorPalette.text)
                .strikethrough(entry.isDone, color: CorbieColorPalette.text2)
                .lineLimit(1)
            Spacer(minLength: CorbieSpacing.xs)
            Text(caption)
                .corbieMono()
                .foregroundStyle(CorbieColorPalette.text2)
                .lineLimit(1)
        }
        .frame(height: WidgetLayout.dateRowHeight)
        .accessibilityElement(children: .combine)
    }
}

struct WidgetFreeSlotRow: View {
    let slot: WidgetFreeSlot

    var body: some View {
        HStack(spacing: CorbieSpacing.xs) {
            Capsule(style: .continuous)
                .fill(CorbieColorPalette.ice)
                .frame(width: WidgetLayout.stripeWidth)
            Text(slot.dayText)
                .corbieBody()
                .foregroundStyle(CorbieColorPalette.text)
                .lineLimit(1)
            Spacer(minLength: CorbieSpacing.xs)
            Text(slot.windowText)
                .corbieMono()
                .foregroundStyle(CorbieColorPalette.text2)
                .lineLimit(1)
        }
        .frame(height: WidgetLayout.dateRowHeight)
        .accessibilityElement(children: .combine)
    }
}

struct WidgetDateRow: View {
    let date: WidgetDate
    let now: Date

    private var stripeColor: Color {
        guard let colorKey = date.colorKey else { return CorbieColorPalette.ice }
        return MemberColor(key: colorKey).color
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
                    .foregroundStyle(CorbieColorPalette.text)
                    .lineLimit(1)
                Text(subtitle)
                    .corbieMono()
                    .foregroundStyle(CorbieColorPalette.text2)
                    .lineLimit(1)
            }
            Spacer(minLength: CorbieSpacing.xs)
            Text(WidgetDateLabel.shortDate(date.date, now: now))
                .corbieMono()
                .foregroundStyle(CorbieColorPalette.text2)
                .lineLimit(1)
        }
        .frame(height: WidgetLayout.dateRowHeight)
        .accessibilityElement(children: .combine)
    }
}

struct WidgetGoalLine: View {
    let goal: GoalProgressSnapshot

    private var amountText: String? {
        guard let saved = goal.savedText, let target = goal.targetText else { return nil }
        return String(format: String(localized: "goals.card.progress"), saved, target)
    }

    private var overspendText: String? {
        guard let overspent = goal.overspentText else { return nil }
        return String(format: String(localized: "goals.card.overspend"), overspent)
    }

    private var stepsText: String? {
        guard goal.hasSteps else { return nil }
        return WidgetGoalText.steps(done: goal.stepsDone, total: goal.stepsTotal)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
            HStack(spacing: CorbieSpacing.xs) {
                Text(goal.title ?? "")
                    .corbieBody()
                    .foregroundStyle(CorbieColorPalette.text)
                    .lineLimit(1)
                Spacer(minLength: CorbieSpacing.xs)
                if let overspendText {
                    Text(overspendText)
                        .corbieMono()
                        .foregroundStyle(CorbieColorPalette.warn)
                        .lineLimit(1)
                }
            }
            ProgressBar(
                value: goal.progress,
                overspend: goal.isOverspent ? 0.25 : 0,
                accessibilityLabel: String(localized: "goals.card.progress.label"),
                accessibilityValue: amountText ?? ""
            )
            HStack(spacing: CorbieSpacing.xs) {
                if let amountText {
                    Text(amountText)
                        .corbieMono()
                        .foregroundStyle(CorbieColorPalette.text2)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if let stepsText {
                    Text(stepsText)
                        .corbieMono()
                        .foregroundStyle(CorbieColorPalette.text2)
                        .lineLimit(1)
                }
            }
        }
    }
}
