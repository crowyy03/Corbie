import CorbieCore
import Foundation

enum WishDetailText {
    static func pageURL(of wish: WishDTO) -> URL? {
        guard let raw = wish.url else { return nil }
        return LinkParser.normalize(raw)
    }

    static func link(_ url: URL) -> String {
        guard let host = url.host(), host.isEmpty == false else { return url.absoluteString }
        let bareHost = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        var path = url.path(percentEncoded: false)
        while path.hasSuffix("/") {
            path.removeLast()
        }
        return bareHost + path
    }

    static func added(
        ownerName: String,
        createdAt: Date?,
        now: Date = Date(),
        locale: Locale = .current,
        calendar: Calendar = .current
    ) -> String {
        let name = ownerName.prefix(1).uppercased(with: locale) + ownerName.dropFirst()
        guard let createdAt else { return name }
        var style = Date.FormatStyle.dateTime.month(.wide).day().locale(locale)
        if calendar.isDate(createdAt, equalTo: now, toGranularity: .year) == false {
            style = style.year()
        }
        return String.localizedStringWithFormat(
            String(localized: "wishes.detail.added"),
            name,
            createdAt.formatted(style)
        )
    }
}
