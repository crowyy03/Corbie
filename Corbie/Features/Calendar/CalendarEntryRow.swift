import CorbieCore
import SwiftUI

struct CalendarEntryRow: View {
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
                    .fill(CalendarPalette.color(for: entry, in: environment))
                    .frame(width: Self.colorBarWidth)
                    .frame(maxHeight: .infinity)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                    Text(model.formatting.title(for: entry))
                        .corbieBody()
                        .foregroundStyle(CorbieColorPalette.text)
                        .multilineTextAlignment(.leading)
                    Text(caption)
                        .corbieMono()
                        .foregroundStyle(CorbieColorPalette.text2)
                        .multilineTextAlignment(.leading)
                    if let radar = model.radarLine(for: entry) {
                        Text(model.formatting.radarCaption(for: radar))
                            .corbieMono()
                            .foregroundStyle(CorbieColorPalette.ice)
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
                .foregroundStyle(CorbieColorPalette.text)
            Text(model.formatting.monthCaption(entry.startDay))
                .corbieMono()
                .foregroundStyle(CorbieColorPalette.text2)
        }
        .frame(minWidth: Self.dayColumnWidth, alignment: .leading)
    }

    private var caption: String {
        let relative = model.formatting.relativeCaption(for: entry, now: model.now)
        guard entry.isAllDay == false || entry.spansDays else { return relative }
        return relative + " · " + model.formatting.schedule(for: entry)
    }
}
