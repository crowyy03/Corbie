import Foundation

enum RelationSuggestion: String, CaseIterable, Identifiable {
    case mom
    case dad
    case sister
    case brother
    case friend
    case colleague

    var id: String { rawValue }

    var key: String { "people.editor.relation." + rawValue }

    func title(locale: Locale = .current) -> String {
        String(localized: String.LocalizationValue(key), locale: locale)
    }

    static func matching(_ query: String, locale: Locale = .current) -> [RelationSuggestion] {
        let typed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard typed.isEmpty == false else { return allCases }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return allCases.filter { suggestion in
            let title = suggestion.title(locale: locale)
            guard title.compare(typed, options: options, range: nil, locale: locale) != .orderedSame else {
                return false
            }
            return title.range(of: typed, options: options, range: nil, locale: locale) != nil
        }
    }
}
