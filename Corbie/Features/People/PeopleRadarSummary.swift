import CorbieCore
import Foundation

struct PeopleRadarSummary: Identifiable, Equatable {
    enum GiftStatus: Equatable {
        case picked
        case ideas(Int)
        case nothing

        init(_ status: RadarStatus) {
            if status.giftPicked {
                self = .picked
            } else if status.ideasCount > 0 {
                self = .ideas(status.ideasCount)
            } else {
                self = .nothing
            }
        }
    }

    let id: String
    let personId: UUID?
    let name: String?
    let daysAway: Int
    let giftStatus: GiftStatus

    init(id: String, personId: UUID?, name: String?, daysAway: Int, giftStatus: GiftStatus) {
        self.id = id
        self.personId = personId
        self.name = name
        self.daysAway = daysAway
        self.giftStatus = giftStatus
    }

    init(_ line: RadarLine) {
        self.init(
            id: line.id,
            personId: line.autoDate.personId,
            name: line.name,
            daysAway: line.daysAway,
            giftStatus: GiftStatus(line.status)
        )
    }

    func giftText(locale: Locale = .current) -> String {
        switch giftStatus {
        case .picked:
            return String(localized: "people.radar.picked", locale: locale)
        case let .ideas(count):
            return String(localized: "people.radar.ideas", defaultValue: "\(count) ideas saved", locale: locale)
        case .nothing:
            return String(localized: "people.radar.empty", locale: locale)
        }
    }

    func daysText(locale: Locale = .current) -> String {
        guard daysAway > 0 else { return String(localized: "people.radar.today", locale: locale) }
        return String(localized: "people.radar.days", defaultValue: "\(daysAway) days to go", locale: locale)
    }

    func line(locale: Locale = .current) -> String {
        String(
            localized: "people.radar.line",
            defaultValue: "\(daysText(locale: locale)) \u{00B7} \(giftText(locale: locale))",
            locale: locale
        )
    }

    static func byPerson(_ summaries: [PeopleRadarSummary]) -> [UUID: PeopleRadarSummary] {
        var result: [UUID: PeopleRadarSummary] = [:]
        for summary in summaries {
            guard let personId = summary.personId else { continue }
            if let existing = result[personId], existing.daysAway <= summary.daysAway { continue }
            result[personId] = summary
        }
        return result
    }
}
