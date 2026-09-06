import Foundation

public struct RadarText: Sendable, Equatable {
    public enum Gift: Sendable, Equatable {
        case picked
        case ideas(Int)
        case nothing

        public init(_ status: RadarStatus) {
            if status.giftPicked {
                self = .picked
            } else if status.ideasCount > 0 {
                self = .ideas(status.ideasCount)
            } else {
                self = .nothing
            }
        }
    }

    public let daysAway: Int
    public let gift: Gift

    public init(daysAway: Int, gift: Gift) {
        self.daysAway = daysAway
        self.gift = gift
    }

    public init(daysAway: Int, status: RadarStatus) {
        self.init(daysAway: daysAway, gift: Gift(status))
    }

    public init(_ line: RadarLine) {
        self.init(daysAway: line.daysAway, status: line.status)
    }

    public func daysText(locale: Locale = .current) -> String {
        guard daysAway > 0 else { return String(localized: "people.radar.today", locale: locale) }
        return String(localized: "people.radar.days", defaultValue: "\(daysAway) days to go", locale: locale)
    }

    public func giftText(locale: Locale = .current) -> String {
        switch gift {
        case .picked:
            return String(localized: "people.radar.picked", locale: locale)
        case let .ideas(count):
            return String(localized: "people.radar.ideas", defaultValue: "\(count) ideas saved", locale: locale)
        case .nothing:
            return String(localized: "people.radar.empty", locale: locale)
        }
    }

    public func line(locale: Locale = .current) -> String {
        String(
            localized: "people.radar.line",
            defaultValue: "\(daysText(locale: locale)) \u{00B7} \(giftText(locale: locale))",
            locale: locale
        )
    }
}
