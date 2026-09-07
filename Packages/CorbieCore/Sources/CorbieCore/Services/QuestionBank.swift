import Foundation

public enum QuestionTheme: String, Sendable, Equatable, CaseIterable, Codable {
    case memories
    case everyday
    case future
    case tastes
    case values
    case playful
    case gratitude
    case growth
    case people
    case team
}

public enum QuestionStage: String, Sendable, Equatable, CaseIterable, Codable {
    case any
    case sixMonths = "6m+"
    case twoYears = "2y+"

    public var minimumMonthsTogether: Int {
        switch self {
        case .any: return 0
        case .sixMonths: return 6
        case .twoYears: return 24
        }
    }

    public func suits(togetherSince: Date?, now: Date, calendar: Calendar = .utc) -> Bool {
        let months = minimumMonthsTogether
        guard months > 0 else { return true }
        guard let togetherSince, togetherSince <= now else { return false }
        guard let earliest = calendar.date(byAdding: .month, value: months, to: togetherSince) else { return false }
        return earliest <= now
    }
}

public enum QuestionTone: String, Sendable, Equatable, CaseIterable, Codable {
    case light
    case deep
    case playful
}

public struct QuestionBankEntry: Sendable, Equatable, Codable, Identifiable {
    public static let languages = ["en", "de", "es", "fr", "it"]
    public static let maxEnglishLength = 90

    public let id: String
    public let theme: QuestionTheme
    public let stage: QuestionStage
    public let tone: QuestionTone
    public let text: [String: String]

    public init(id: String, theme: QuestionTheme, stage: QuestionStage, tone: QuestionTone, text: [String: String]) {
        self.id = id
        self.theme = theme
        self.stage = stage
        self.tone = tone
        self.text = text
    }

    public func text(for locale: Locale) -> String {
        let language = locale.language.languageCode?.identifier ?? "en"
        return text[language] ?? text["en"] ?? ""
    }
}

public struct QuestionBank: Sendable, Equatable {
    public static let directoryName = "Questions"

    public static let bundled = QuestionBank.load(from: QuestionBank.bundledDirectory)

    public let entries: [QuestionBankEntry]
    private let byId: [String: QuestionBankEntry]

    public init(entries: [QuestionBankEntry]) {
        self.entries = entries.sorted { $0.id < $1.id }
        byId = Dictionary(entries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    public static var bundledDirectory: URL? {
        Bundle.module.url(forResource: QuestionBank.directoryName, withExtension: nil)
    }

    public static func load(from directory: URL?) -> QuestionBank {
        guard let directory else { return QuestionBank(entries: []) }
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []
        let decoder = JSONDecoder()
        var collected: [String: QuestionBankEntry] = [:]
        for file in files.filter({ $0.pathExtension.lowercased() == "json" }).sorted(by: { $0.path < $1.path }) {
            guard let data = try? Data(contentsOf: file),
                  let decoded = try? decoder.decode([QuestionBankEntry].self, from: data) else { continue }
            for entry in decoded where collected[entry.id] == nil {
                collected[entry.id] = entry
            }
        }
        return QuestionBank(entries: Array(collected.values))
    }

    public var isEmpty: Bool { entries.isEmpty }

    public var questionIds: [String] { entries.map(\.id) }

    public func entry(id: String) -> QuestionBankEntry? {
        byId[id]
    }
}
