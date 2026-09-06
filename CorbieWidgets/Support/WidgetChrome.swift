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

struct WidgetTaskRow: View {
    let task: WidgetTask
    let now: Date

    private var markColor: Color {
        guard task.isFree == false, let colorKey = task.colorKey else { return CorbieColorPalette.text2 }
        return MemberColor(key: colorKey).color
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
                .foregroundStyle(CorbieColorPalette.text)
                .lineLimit(1)
            if let dueText {
                Text(dueText)
                    .corbieMono()
                    .foregroundStyle(CorbieColorPalette.text2)
                    .lineLimit(1)
            }
        }
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
            if let amountText {
                Text(amountText)
                    .corbieMono()
                    .foregroundStyle(CorbieColorPalette.text2)
                    .lineLimit(1)
            }
        }
    }
}
