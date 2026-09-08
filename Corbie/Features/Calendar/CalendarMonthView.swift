import CorbieCore
import SwiftUI

struct CalendarMonthView: View {
    @Environment(\.palette) private var palette

    let model: CalendarViewModel
    let onSelect: (Date) -> Void

    var body: some View {
        VStack(spacing: CorbieSpacing.xs) {
            header
            weekdayRow
            ForEach(model.grid.weeks) { week in
                CalendarWeekRow(
                    week: week,
                    model: model,
                    spans: model.spans.filter { $0.weekIndex == week.index },
                    onSelect: onSelect
                )
            }
        }
    }

    private var header: some View {
        HStack(spacing: CorbieSpacing.xs) {
            Text(model.monthTitle)
                .corbieBody()
                .fontWeight(.semibold)
                .foregroundStyle(palette.text)
            Spacer(minLength: CorbieSpacing.xs)
            if model.isOnCurrentMonth == false {
                Button(String(localized: "calendar.month.today")) {
                    model.showCurrentMonth()
                }
                .buttonStyle(.plain)
                .corbieMono()
                .foregroundStyle(palette.accent)
                .frame(minHeight: CorbieMetrics.minimumTapTarget)
            }
            monthButton(systemImage: "chevron.left", label: "calendar.month.previous", months: -1)
            monthButton(systemImage: "chevron.right", label: "calendar.month.next", months: 1)
        }
    }

    private func monthButton(systemImage: String, label: LocalizedStringKey, months: Int) -> some View {
        Button {
            model.step(months: months)
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: CorbieFont.captionSize, weight: .semibold))
                .foregroundStyle(palette.text2)
                .frame(width: CorbieMetrics.minimumTapTarget, height: CorbieMetrics.minimumTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(model.formatting.weekdaySymbols.enumerated()), id: \.offset) { symbol in
                Text(symbol.element)
                    .corbieMono()
                    .foregroundStyle(palette.text2)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct CalendarWeekRow: View {
    @Environment(\.palette) private var palette

    static let barHeight: CGFloat = 6
    static let barSpacing: CGFloat = 3

    let week: CalendarWeek
    let model: CalendarViewModel
    let spans: [CalendarSpan]
    let onSelect: (Date) -> Void

    private var laneCount: Int {
        spans.map { $0.lane + 1 }.max() ?? 0
    }

    var body: some View {
        VStack(spacing: Self.barSpacing) {
            HStack(spacing: 0) {
                ForEach(week.days, id: \.self) { day in
                    CalendarDayCell(day: day, model: model, onSelect: onSelect)
                }
            }
            if laneCount > 0 {
                bars
                    .frame(height: CGFloat(laneCount) * (Self.barHeight + Self.barSpacing) - Self.barSpacing)
            }
        }
    }

    private var bars: some View {
        GeometryReader { proxy in
            let columnWidth = proxy.size.width / CGFloat(CalendarGrid.columns)
            ZStack(alignment: .topLeading) {
                ForEach(spans) { span in
                    bar(for: span, columnWidth: columnWidth)
                }
            }
        }
    }

    private func bar(for span: CalendarSpan, columnWidth: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: Self.barHeight / 2, style: .continuous)
            .fill(palette.accent)
            .frame(width: max(columnWidth * CGFloat(span.length) - CorbieSpacing.xxs, 2), height: Self.barHeight)
            .offset(
                x: columnWidth * CGFloat(span.startColumn) + CorbieSpacing.xxs / 2,
                y: CGFloat(span.lane) * (Self.barHeight + Self.barSpacing)
            )
            .accessibilityHidden(true)
    }
}

private struct CalendarDayCell: View {
    @Environment(\.palette) private var palette

    static let dotLimit = 2
    static let dotSize: CGFloat = 6

    @Environment(AppEnvironment.self) private var environment

    let day: Date
    let model: CalendarViewModel
    let onSelect: (Date) -> Void

    private var entries: [CalendarEntry] { model.entries(on: day) }

    private var isToday: Bool { model.isToday(day) }

    private var isSelected: Bool { model.selectedDay == day }

    private var isInMonth: Bool { model.grid.isInMonth(day) }

    private var numberColor: Color {
        if isToday { return palette.ctaText }
        return isInMonth ? palette.text : palette.text2
    }

    var body: some View {
        Button {
            onSelect(day)
        } label: {
            VStack(spacing: CorbieSpacing.xxs) {
                Text(model.formatting.dayNumber(day))
                    .corbieCaption()
                    .monospacedDigit()
                    .fontWeight(isToday ? .semibold : .regular)
                    .foregroundStyle(numberColor)
                    .frame(width: CorbieSpacing.xl, height: CorbieSpacing.xl)
                    .background {
                        if isToday {
                            Circle().fill(palette.accent)
                        }
                    }
                    .overlay {
                        if isSelected {
                            Circle().strokeBorder(palette.accent, lineWidth: 2)
                        }
                    }
                dots
            }
            .frame(maxWidth: .infinity, minHeight: CorbieMetrics.minimumTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isInMonth ? 1 : 0.45)
        .accessibilityLabel(Text(model.formatting.dayAccessibilityLabel(day, entryCount: entries.count)))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var dots: some View {
        HStack(spacing: CorbieSpacing.xxs / 2) {
            ForEach(Array(entries.prefix(Self.dotLimit)), id: \.id) { entry in
                Circle()
                    .fill(CalendarEntryTint.color(for: entry, in: environment, palette: palette))
                    .frame(width: Self.dotSize, height: Self.dotSize)
            }
        }
        .frame(height: Self.dotSize)
        .accessibilityHidden(true)
    }
}
