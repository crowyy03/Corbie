import Foundation

public enum PriceLeftOut: Sendable, Equatable {
    case unsupportedCurrency(String)
    case unknownCurrency
}

public struct ParsedLink: Sendable, Equatable {
    public let canonicalURL: URL
    public let source: WishSource
    public let title: String?
    public let price: Double?
    public let currency: String?
    public let priceLeftOut: PriceLeftOut?
    public let imageURL: URL?
    public let imageData: Data?

    public init(
        canonicalURL: URL,
        source: WishSource,
        title: String? = nil,
        price: Double? = nil,
        currency: String? = nil,
        priceLeftOut: PriceLeftOut? = nil,
        imageURL: URL? = nil,
        imageData: Data? = nil
    ) {
        self.canonicalURL = canonicalURL
        self.source = source
        self.title = title
        self.price = price
        self.currency = currency
        self.priceLeftOut = priceLeftOut
        self.imageURL = imageURL
        self.imageData = imageData
    }

    public var isEmpty: Bool {
        let hasTitle = title.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false } ?? false
        return hasTitle == false && imageURL == nil && imageData == nil
    }
}

public struct LinkParser: Sendable {
    public static let serverTimeout: TimeInterval = 15
    public static let imageTimeout: TimeInterval = 5
    public static let maxImageDownloadBytes = 8_000_000

    private let client: APIClient
    private let imageTransport: any HTTPTransport
    private let serverTimeout: TimeInterval
    private let imageTimeout: TimeInterval
    private let downloadsImages: Bool

    public init(
        client: APIClient,
        imageTransport: any HTTPTransport = URLSessionTransport(),
        serverTimeout: TimeInterval = LinkParser.serverTimeout,
        imageTimeout: TimeInterval = LinkParser.imageTimeout,
        downloadsImages: Bool = true
    ) {
        self.client = client
        self.imageTransport = imageTransport
        self.serverTimeout = serverTimeout
        self.imageTimeout = imageTimeout
        self.downloadsImages = downloadsImages
    }

    public func parse(url: URL) async throws -> ParsedLink {
        guard let normalized = LinkParser.normalize(url.absoluteString) else {
            throw CorbieError.invalidInput("link is not a web address")
        }
        let payload = try await withDeadline(seconds: serverTimeout) { [client] in
            do {
                return try await client.parse(url: normalized)
            } catch let failure as APIError {
                throw failure.corbieError
            }
        }
        let canonical = payload.canonicalLink ?? normalized
        let pricing = LinkParser.pricing(of: payload, link: normalized, page: canonical)
        let imageURL = payload.imageLink
        let imageData = await self.imageData(for: imageURL)
        return ParsedLink(
            canonicalURL: canonical,
            source: LinkParser.source(from: payload.source),
            title: LinkParser.trimmed(payload.title),
            price: pricing.price,
            currency: pricing.currency,
            priceLeftOut: pricing.leftOut,
            imageURL: imageURL,
            imageData: imageData
        )
    }

    public func parse(rawURL: String) async throws -> ParsedLink {
        guard let normalized = LinkParser.normalize(rawURL) else {
            throw CorbieError.invalidInput("link is not a web address")
        }
        return try await parse(url: normalized)
    }

    public static func normalize(_ raw: String) -> URL? {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        if trimmed.contains("://") == false {
            trimmed = "https://" + trimmed
        }
        guard var components = URLComponents(string: trimmed) else { return nil }
        guard let scheme = components.scheme?.lowercased(), scheme == "https" || scheme == "http" else {
            return nil
        }
        components.scheme = scheme
        guard let host = components.host, host.contains("."), host.hasSuffix(".") == false else {
            return nil
        }
        return components.url
    }

    public static func firstLink(in text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = detector.matches(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed))
        for match in matches {
            guard let scheme = match.url?.scheme?.lowercased(), scheme == "https" || scheme == "http",
                  let range = Range(match.range, in: trimmed),
                  let link = normalize(linkText(at: range, in: trimmed))
            else { continue }
            return link
        }
        return nil
    }

    public static func firstLink(url: URL?, text: @autoclosure () -> String?) -> URL? {
        if let url, let link = normalize(url.absoluteString) { return link }
        return text().flatMap(firstLink(in:))
    }

    private static func linkText(at range: Range<String.Index>, in text: String) -> String {
        let isWholeText = range.lowerBound == text.startIndex && text.contains(where: \.isWhitespace) == false
        if isWholeText { return text }
        let found = text[range]
        let opensWithBracket = range.lowerBound > text.startIndex && text[text.index(before: range.lowerBound)] == "("
        let closesOneBracketTooMany = found.hasSuffix(")")
            && found.filter { $0 == ")" }.count > found.filter { $0 == "(" }.count
        return String(opensWithBracket && closesOneBracketTooMany ? found.dropLast() : found)
    }

    public static func source(from raw: String) -> WishSource {
        let lowered = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lowered == "generic" { return .store }
        return WishSource(rawValue: lowered) ?? .store
    }

    private static func pricing(
        of payload: ParsedLinkPayload,
        link: URL,
        page: URL
    ) -> (price: Double?, currency: String?, leftOut: PriceLeftOut?) {
        if let currency = trimmed(payload.currency)?.uppercased() {
            if SupportedCurrencies.contains(currency) {
                return (payload.price, currency, nil)
            }
            guard payload.price != nil else { return (nil, nil, nil) }
            WishLinkLog.priceInUnsupportedCurrency(link, currency: currency)
            return (nil, nil, .unsupportedCurrency(currency))
        }
        guard let price = payload.price else { return (nil, nil, nil) }
        guard let inferred = LinkCurrencyInference.match(for: page) else {
            WishLinkLog.priceWithoutCurrency(link, page: page)
            return (nil, nil, .unknownCurrency)
        }
        WishLinkLog.priceCurrencyInferred(link, page: page, inferred: inferred)
        return (price, inferred.currency, nil)
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    private func imageData(for url: URL?) async -> Data? {
        guard downloadsImages, let url else { return nil }
        let response = try? await withDeadline(seconds: imageTimeout) { [imageTransport] in
            try await imageTransport.send(HTTPRequest(method: .get, url: url))
        }
        guard let response, response.isSuccess, response.body.count <= LinkParser.maxImageDownloadBytes else {
            return nil
        }
        return ImageDownsampler.downsample(response.body)?.data
    }
}

func withDeadline<T: Sendable>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
            throw CorbieError.network("timed out")
        }
        guard let first = try await group.next() else {
            throw CorbieError.network("timed out")
        }
        group.cancelAll()
        return first
    }
}
