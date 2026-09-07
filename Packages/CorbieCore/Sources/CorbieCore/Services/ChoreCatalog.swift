import Foundation

public enum ChoreGroup: String, Sendable, Equatable, CaseIterable, Codable {
    case kitchen
    case cleaning
    case laundry
    case shopping
    case money
    case pets
    case plants
    case car
    case outside
    case keepingInTouch

    public var titleKey: String { "chore.group." + rawValue.lowercased() }
}

public struct ChoreCatalogItem: Sendable, Equatable, Codable, Identifiable {
    public static let languages = ["en", "de", "es", "fr", "it"]

    public let id: String
    public let group: ChoreGroup
    public let frequency: ChoreFrequency
    public let preselected: Bool
    public let text: [String: String]

    public init(id: String, group: ChoreGroup, frequency: ChoreFrequency, preselected: Bool, text: [String: String]) {
        self.id = id
        self.group = group
        self.frequency = frequency
        self.preselected = preselected
        self.text = text
    }

    public var loadPerWeek: Double { frequency.loadPerWeek }

    public func text(for locale: Locale) -> String {
        let language = locale.language.languageCode?.identifier ?? "en"
        return text[language] ?? text["en"] ?? ""
    }
}

public struct ChoreCatalog: Sendable, Equatable {
    public static let fileName = "Chores"

    public static let bundled = ChoreCatalog.load(from: ChoreCatalog.bundledURL)

    public let items: [ChoreCatalogItem]

    public init(items: [ChoreCatalogItem]) {
        self.items = items
    }

    public static var bundledURL: URL? {
        Bundle.module.url(forResource: ChoreCatalog.fileName, withExtension: "json")
    }

    public static func load(from url: URL?) -> ChoreCatalog {
        guard let url,
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([ChoreCatalogItem].self, from: data) else {
            return ChoreCatalog(items: [])
        }
        return ChoreCatalog(items: decoded)
    }

    public var isEmpty: Bool { items.isEmpty }

    public var preselectedIds: [String] { items.filter(\.preselected).map(\.id) }

    public func items(in group: ChoreGroup) -> [ChoreCatalogItem] {
        items.filter { $0.group == group }
    }

    public func item(id: String) -> ChoreCatalogItem? {
        items.first { $0.id == id }
    }

    public var groups: [ChoreGroup] {
        ChoreGroup.allCases.filter { group in items.contains { $0.group == group } }
    }
}
