import Foundation

public struct ServerConfiguration: Sendable, Equatable {
    public static let infoPlistKey = "CORBIE_SERVER_URL"
    public static let defaultProjectRef = "corbie"

    public let functionsBaseURL: URL

    public init(functionsBaseURL: URL) {
        self.functionsBaseURL = functionsBaseURL
    }

    public init?(projectRef: String) {
        let trimmed = projectRef.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        guard trimmed.isEmpty == false,
              trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }),
              let url = URL(string: "https://\(trimmed).supabase.co/functions/v1")
        else { return nil }
        self.init(functionsBaseURL: url)
    }

    public init?(rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        guard trimmed.contains("://") else {
            self.init(projectRef: trimmed)
            return
        }
        guard let url = URL(string: trimmed), url.scheme?.lowercased() == "https", url.host != nil else {
            return nil
        }
        self.init(functionsBaseURL: url)
    }

    public static let fallback = ServerConfiguration(projectRef: defaultProjectRef)
        ?? ServerConfiguration(functionsBaseURL: URL(fileURLWithPath: "/"))

    public static func fromBundle(_ bundle: Bundle = .main) -> ServerConfiguration {
        guard let raw = bundle.object(forInfoDictionaryKey: infoPlistKey) as? String,
              let configuration = ServerConfiguration(rawValue: raw)
        else { return fallback }
        return configuration
    }

    public var isPlaceholder: Bool { self == ServerConfiguration.fallback }

    public func url(path: String, query: [URLQueryItem] = []) -> URL {
        var components = URLComponents(url: functionsBaseURL, resolvingAgainstBaseURL: false)
        var base = components?.path ?? functionsBaseURL.path
        while base.hasSuffix("/") { base.removeLast() }
        let tail = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components?.path = tail.isEmpty ? base : base + "/" + tail
        if query.isEmpty == false {
            components?.queryItems = query
        }
        return components?.url ?? functionsBaseURL
    }
}

public enum AppVersion {
    public static let unknown = "0 (0)"

    public static func current(bundle: Bundle = .main) -> String {
        let short = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        guard let short, let build else { return unknown }
        return "\(short) (\(build))"
    }
}

public typealias AppleTokenProvider = @Sendable () async throws -> String?

public struct RetryPolicy: Sendable, Equatable {
    public var maxRetries: Int
    public var baseDelay: TimeInterval
    public var multiplier: Double
    public var maxDelay: TimeInterval
    public var jitterFraction: Double
    public var maxRetryAfterDelay: TimeInterval

    public init(
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 0.5,
        multiplier: Double = 2,
        maxDelay: TimeInterval = 8,
        jitterFraction: Double = 0.25,
        maxRetryAfterDelay: TimeInterval = 30
    ) {
        self.maxRetries = max(0, maxRetries)
        self.baseDelay = max(0, baseDelay)
        self.multiplier = max(1, multiplier)
        self.maxDelay = max(0, maxDelay)
        self.jitterFraction = min(max(0, jitterFraction), 1)
        self.maxRetryAfterDelay = max(0, maxRetryAfterDelay)
    }

    public static let `default` = RetryPolicy()
    public static let noRetries = RetryPolicy(maxRetries: 0)

    public func delay(forRetry retry: Int, random: Double) -> TimeInterval {
        guard retry > 0 else { return 0 }
        let exponent = pow(multiplier, Double(retry - 1))
        let raw = min(maxDelay, baseDelay * exponent)
        let offset = raw * jitterFraction * (min(max(0, random), 1) * 2 - 1)
        return max(0, raw + offset)
    }
}
