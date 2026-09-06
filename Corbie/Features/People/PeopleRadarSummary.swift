import CorbieCore
import Foundation

struct PeopleRadarSummary: Identifiable, Equatable {
    let id: String
    let personId: UUID?
    let name: String?
    let text: RadarText

    init(id: String, personId: UUID?, name: String?, text: RadarText) {
        self.id = id
        self.personId = personId
        self.name = name
        self.text = text
    }

    init(_ line: RadarLine) {
        self.init(id: line.id, personId: line.autoDate.personId, name: line.name, text: RadarText(line))
    }

    static func byPerson(_ summaries: [PeopleRadarSummary]) -> [UUID: PeopleRadarSummary] {
        var result: [UUID: PeopleRadarSummary] = [:]
        for summary in summaries {
            guard let personId = summary.personId else { continue }
            if let existing = result[personId], existing.text.daysAway <= summary.text.daysAway { continue }
            result[personId] = summary
        }
        return result
    }
}
