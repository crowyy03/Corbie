import Foundation

public struct ParsedLink: Sendable, Equatable {
    public let canonicalURL: URL
    public let source: WishSource
    public let title: String?
    public let price: Double?
    public let currency: String?
    public let imageURL: URL?
    public let author: String?
    public let imageData: Data?

    public init(
        canonicalURL: URL,
        source: WishSource,
        title: String? = nil,
        price: Double? = nil,
        currency: String? = nil,
        imageURL: URL? = nil,
        author: String? = nil,
        imageData: Data? = nil
    ) {
        self.canonicalURL = canonicalURL
        self.source = source
        self.title = title
        self.price = price
        self.currency = currency
        self.imageURL = imageURL
        self.author = author
        self.imageData = imageData
    }

    public var needsManualEntry: Bool { title == nil || price == nil }
}

public struct LinkParser: Sendable {
    public static let timeout: TimeInterval = 8
    public static let maxImageDownloadBytes = 8_000_000

    private let client: APIClient
    private let imageTransport: any HTTPTransport
    private let timeout: TimeInterval
    private let downloadsImages: Bool

    public init(
        client: APIClient,
        imageTransport: any HTTPTransport = URLSessionTransport(),
        timeout: TimeInterval = LinkParser.timeout,
        downloadsImages: Bool = true
    ) {
        self.client = client
        self.imageTransport = imageTransport
        self.timeout = timeout
        self.downloadsImages = downloadsImages
    }

    public func parse(url: URL) async throws -> ParsedLink {
        guard let normalized = LinkParser.normalize(url.absoluteString) else {
            throw CorbieError.invalidInput("link is not a web address")
        }
        return try await withDeadline(seconds: timeout) {
            let payload: ParsedLinkPayload
            do {
                payload = try await client.parse(url: normalized)
            } catch let failure as APIError {
                throw failure.corbieError
            }
            let canonical = payload.canonicalLink ?? normalized
            let imageURL = payload.imageLink
            let imageData = await self.imageData(for: imageURL)
            return ParsedLink(
                canonicalURL: canonical,
                source: LinkParser.source(from: payload.source),
                title: LinkParser.trimmed(payload.title),
                price: payload.price,
                currency: LinkParser.trimmed(payload.currency)?.uppercased(),
                imageURL: imageURL,
                author: LinkParser.trimmed(payload.author),
                imageData: imageData
            )
        }
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

    public static func source(from raw: String) -> WishSource {
        let lowered = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lowered == "generic" { return .store }
        return WishSource(rawValue: lowered) ?? .store
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    private func imageData(for url: URL?) async -> Data? {
        guard downloadsImages, let url else { return nil }
        guard let response = try? await imageTransport.send(HTTPRequest(method: .get, url: url)) else { return nil }
        guard response.isSuccess, response.body.count <= LinkParser.maxImageDownloadBytes else { return nil }
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
