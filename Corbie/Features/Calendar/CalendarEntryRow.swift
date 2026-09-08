import CorbieCore
import SwiftUI

struct CalendarEntryRow: View {
    @Environment(\.palette) private var palette

    static let dayColumnWidth: CGFloat = 52
    static let colorBarWidth: CGFloat = 3

    @Environment(AppEnvironment.self) private var environment

    let entry: CalendarEntry
    let model: CalendarViewModel

    var body: some View {
        Card {
            HStack(alignment: .center, spacing: CorbieSpacing.m) {
                dayColumn
                RoundedRectangle(cornerRadius: Self.colorBarWidth / 2, style: .continuous)
                    .fill(CalendarEntryTint.color(for: entry, in: environment, palette: palette))
                    .frame(width: Self.colorBarWidth)
                    .frame(maxHeight: .infinity)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                    Text(model.formatting.title(for: entry))
                        .corbieBody()
                        .foregroundStyle(palette.text)
                        .multilineTextAlignment(.leading)
                    Text(caption)
                        .corbieMono()
                        .foregroundStyle(palette.text2)
                        .multilineTextAlignment(.leading)
                    if let radar = model.radarLine(for: entry) {
                        Text(model.formatting.radarCaption(for: radar))
                            .corbieMono()
                            .foregroundStyle(palette.accent)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }

    private var dayColumn: some View {
        VStack(spacing: 0) {
            Text(model.formatting.dayNumber(entry.startDay))
                .corbieScreenTitle()
                .monospacedDigit()
                .foregroundStyle(palette.text)
            Text(model.formatting.monthCaption(entry.startDay))
                .corbieMono()
                .foregroundStyle(palette.text2)
        }
        .frame(minWidth: Self.dayColumnWidth, alignment: .leading)
    }

    private var caption: String {
        let relative = model.formatting.relativeCaption(for: entry, now: model.now)
        guard entry.isAllDay == false || entry.spansDays else { return relative }
        return relative + " · " + model.formatting.schedule(for: entry)
    }
}
