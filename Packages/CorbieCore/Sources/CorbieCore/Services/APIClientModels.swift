import Foundation

public enum CorbieJSON {
    public static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            guard let date = CorbieJSON.date(from: raw) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "not a date: \(raw)")
            }
            return date
        }
        return decoder
    }

    public static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(CorbieJSON.string(from: date))
        }
        return encoder
    }

    public static func date(from raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: trimmed) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let date = plain.date(from: trimmed) { return date }
        return dayFormatter.date(from: trimmed)
    }

    public static func string(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private static var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}

public enum ServerErrorCode: String, Sendable, Equatable, CaseIterable, Codable {
    case unauthorized
    case invalidRequest = "invalid_request"
    case notFound = "not_found"
    case expired
    case redeemed
    case rateLimited = "rate_limited"
    case upstreamFailed = "upstream_failed"
    case internalFailure = "internal"
}

public struct ServerErrorEnvelope: Sendable, Equatable, Codable {
    public let error: String
    public let message: String

    public init(error: String, message: String) {
        self.error = error
        self.message = message
    }

    public var code: ServerErrorCode? { ServerErrorCode(rawValue: error) }
}

public struct APIError: Error, Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case server
        case transport
        case decoding
        case invalidRequest
        case missingAppleToken
    }

    public let kind: Kind
    public let status: Int?
    public let envelope: ServerErrorEnvelope?
    public let retryAfter: TimeInterval?
    public let detail: String

    public init(
        kind: Kind,
        status: Int? = nil,
        envelope: ServerErrorEnvelope? = nil,
        retryAfter: TimeInterval? = nil,
        detail: String
    ) {
        self.kind = kind
        self.status = status
        self.envelope = envelope
        self.retryAfter = retryAfter
        self.detail = detail
    }

    public var code: ServerErrorCode? { envelope?.code }
    public var isUnauthorized: Bool { status == 401 || code == .unauthorized || kind == .missingAppleToken }
    public var isRateLimited: Bool { status == 429 || code == .rateLimited }
    public var isNotFound: Bool { status == 404 || code == .notFound }
    public var isExpired: Bool { code == .expired }
    public var isRedeemed: Bool { code == .redeemed }
    public var isMethodNotAllowed: Bool { status == 405 }

    public var corbieError: CorbieError {
        switch kind {
        case .missingAppleToken:
            return .auth(detail)
        case .server where isUnauthorized:
            return .auth(detail)
        case .server, .transport, .decoding, .invalidRequest:
            return .network(detail)
        }
    }

    static func server(status: Int, body: Data, retryAfter: TimeInterval?) -> APIError {
        let envelope = try? CorbieJSON.decoder.decode(ServerErrorEnvelope.self, from: body)
        let described = envelope.map { "\($0.error): \($0.message)" } ?? "http \(status)"
        return APIError(
            kind: .server,
            status: status,
            envelope: envelope,
            retryAfter: retryAfter,
            detail: "\(status) \(described)"
        )
    }

    static func transport(_ error: Error) -> APIError {
        APIError(kind: .transport, detail: String(describing: error))
    }

    static func decoding(_ error: Error) -> APIError {
        APIError(kind: .decoding, detail: String(describing: error))
    }

    static func invalidRequest(_ detail: String) -> APIError {
        APIError(kind: .invalidRequest, detail: detail)
    }

    static let missingAppleToken = APIError(kind: .missingAppleToken, detail: "no apple identity token")
}

extension APIError: LocalizedError {
    public var errorDescription: String? { corbieError.errorDescription }
    public var failureReason: String? { detail }
}

public struct InviteCode: Sendable, Equatable, Codable {
    public let code: String
    public let expiresAt: Date

    public init(code: String, expiresAt: Date) {
        self.code = code
        self.expiresAt = expiresAt
    }
}

public struct InviteShare: Sendable, Equatable, Codable {
    public let shareURL: String
    public let spaceId: UUID

    public init(shareURL: String, spaceId: UUID) {
        self.shareURL = shareURL
        self.spaceId = spaceId
    }

    public var shareLink: URL? { URL(string: shareURL) }
}

public struct ParsedLinkPayload: Sendable, Equatable, Codable {
    public let canonicalURL: String
    public let source: String
    public let title: String?
    public let price: Double?
    public let currency: String?
    public let imageURL: String?
    public let author: String?

    public init(
        canonicalURL: String,
        source: String,
        title: String? = nil,
        price: Double? = nil,
        currency: String? = nil,
        imageURL: String? = nil,
        author: String? = nil
    ) {
        self.canonicalURL = canonicalURL
        self.source = source
        self.title = title
        self.price = price
        self.currency = currency
        self.imageURL = imageURL
        self.author = author
    }

    public var canonicalLink: URL? { URL(string: canonicalURL) }
    public var imageLink: URL? { imageURL.flatMap(URL.init(string:)) }
}

public struct FXRatesPayload: Sendable, Equatable, Codable {
    public let base: String
    public let date: Date
    public let rates: [String: Double]

    public init(base: String, date: Date, rates: [String: Double]) {
        self.base = base
        self.date = date
        self.rates = rates
    }
}

public enum EntitlementStatus: String, Sendable, Equatable, CaseIterable, Codable {
    case none
    case active
    case grace
    case expired
    case revoked

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = EntitlementStatus(rawValue: raw) ?? .none
    }
}

public struct EntitlementPayload: Sendable, Equatable, Codable {
    public let spaceId: UUID
    public let status: EntitlementStatus
    public let productId: String?
    public let expiresAt: Date?
    public let updatedAt: Date?

    public init(
        spaceId: UUID,
        status: EntitlementStatus,
        productId: String? = nil,
        expiresAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.spaceId = spaceId
        self.status = status
        self.productId = productId
        self.expiresAt = expiresAt
        self.updatedAt = updatedAt
    }
}

public enum AnalyticsValue: Sendable, Equatable, Codable {
    case string(String)
    case number(Double)
    case flag(Bool)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Bool.self) {
            self = .flag(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else {
            self = .string(try container.decode(String.self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value): try container.encode(value)
        case let .number(value): try container.encode(value)
        case let .flag(value): try container.encode(value)
        }
    }
}

public struct AnalyticsEventPayload: Sendable, Equatable, Codable {
    public let name: String
    public let props: [String: AnalyticsValue]
    public let ts: Date
    public let appVersion: String?
    public let locale: String?

    public init(
        name: String,
        props: [String: AnalyticsValue],
        ts: Date,
        appVersion: String? = nil,
        locale: String? = nil
    ) {
        self.name = name
        self.props = props
        self.ts = ts
        self.appVersion = appVersion
        self.locale = locale
    }
}

struct AnalyticsBatch: Codable, Sendable {
    let events: [AnalyticsEventPayload]
}

struct InviteRequestBody: Encodable, Sendable {
    let spaceId: String
    let shareURL: String
}

struct ParseRequestBody: Encodable, Sendable {
    let url: String
}

struct AppleRevokeBody: Encodable, Sendable {
    let authorizationCode: String?
    let refreshToken: String?
}
