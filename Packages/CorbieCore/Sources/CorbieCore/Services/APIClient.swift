import Foundation

public struct APIClient: Sendable {
    public enum Path {
        public static let invite = "invite"
        public static let inviteRedeem = "invite-redeem"
        public static let parse = "parse"
        public static let fx = "fx"
        public static let entitlement = "entitlement"
        public static let events = "events"
        public static let appleRevoke = "apple-revoke"
    }

    public let configuration: ServerConfiguration

    private let transport: any HTTPTransport
    private let appVersion: String
    private let anonId: @Sendable () -> String?
    private let appleToken: AppleTokenProvider
    private let retry: RetryPolicy
    private let sleeper: any RetrySleeper
    private let jitter: @Sendable () -> Double

    public init(
        configuration: ServerConfiguration = .fromBundle(),
        transport: any HTTPTransport = URLSessionTransport(),
        appVersion: String = AppVersion.current(),
        anonId: @escaping @Sendable () -> String? = { nil },
        appleToken: @escaping AppleTokenProvider = { nil },
        retry: RetryPolicy = .default,
        sleeper: any RetrySleeper = TaskRetrySleeper(),
        jitter: @escaping @Sendable () -> Double = { Double.random(in: 0 ... 1) }
    ) {
        self.configuration = configuration
        self.transport = transport
        self.appVersion = appVersion
        self.anonId = anonId
        self.appleToken = appleToken
        self.retry = retry
        self.sleeper = sleeper
        self.jitter = jitter
    }

    public init(
        configuration: ServerConfiguration = .fromBundle(),
        transport: any HTTPTransport = URLSessionTransport(),
        identity: AnonymousIdentity,
        appVersion: String = AppVersion.current(),
        appleToken: @escaping AppleTokenProvider = { nil },
        retry: RetryPolicy = .default
    ) {
        self.init(
            configuration: configuration,
            transport: transport,
            appVersion: appVersion,
            anonId: { identity.current },
            appleToken: appleToken,
            retry: retry
        )
    }

    public func createInvite(spaceId: UUID, shareURL: URL) async throws -> InviteCode {
        let body = InviteRequestBody(spaceId: spaceId.uuidString.lowercased(), shareURL: shareURL.absoluteString)
        let response = try await send(
            method: .post,
            path: Path.invite,
            body: try encode(body),
            authenticated: true,
            anonymous: false
        )
        return try decode(InviteCode.self, from: response)
    }

    public func redeemInvite(code: String) async throws -> InviteShare {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard normalized.isEmpty == false else {
            throw APIError.invalidRequest("invite code is empty")
        }
        let response = try await send(
            method: .get,
            path: "\(Path.inviteRedeem)/\(normalized)",
            authenticated: false,
            anonymous: false
        )
        return try decode(InviteShare.self, from: response)
    }

    public func parse(url: URL) async throws -> ParsedLinkPayload {
        let response = try await send(
            method: .post,
            path: Path.parse,
            body: try encode(ParseRequestBody(url: url.absoluteString)),
            authenticated: false,
            anonymous: true
        )
        return try decode(ParsedLinkPayload.self, from: response)
    }

    public func fxRates(base: String) async throws -> FXRatesPayload {
        let code = base.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard code.count == 3 else {
            throw APIError.invalidRequest("base must be a 3 letter code")
        }
        let response = try await send(
            method: .get,
            path: Path.fx,
            query: [URLQueryItem(name: "base", value: code)],
            authenticated: false,
            anonymous: true
        )
        return try decode(FXRatesPayload.self, from: response)
    }

    public func entitlement(spaceId: UUID) async throws -> EntitlementPayload {
        let response = try await send(
            method: .get,
            path: "\(Path.entitlement)/\(spaceId.uuidString.lowercased())",
            authenticated: true,
            anonymous: false
        )
        return try decode(EntitlementPayload.self, from: response)
    }

    public func events(_ batch: [AnalyticsEventPayload]) async throws {
        guard batch.isEmpty == false else { return }
        guard batch.count <= Analytics.maxEventsPerBatch else {
            throw APIError.invalidRequest("a batch holds at most \(Analytics.maxEventsPerBatch) events")
        }
        _ = try await send(
            method: .post,
            path: Path.events,
            body: try encode(AnalyticsBatch(events: batch)),
            authenticated: false,
            anonymous: true
        )
    }

    public func revokeAppleAccount(authorizationCode: String? = nil, refreshToken: String? = nil) async throws {
        guard authorizationCode != nil || refreshToken != nil else {
            throw APIError.invalidRequest("authorizationCode or refreshToken is required")
        }
        _ = try await send(
            method: .post,
            path: Path.appleRevoke,
            body: try encode(AppleRevokeBody(authorizationCode: authorizationCode, refreshToken: refreshToken)),
            authenticated: true,
            anonymous: false
        )
    }

    private func send(
        method: HTTPMethod,
        path: String,
        query: [URLQueryItem] = [],
        body: Data? = nil,
        authenticated: Bool,
        anonymous: Bool
    ) async throws -> HTTPResponse {
        var headers = ["X-App-Version": appVersion, "Accept": "application/json"]
        if body != nil {
            headers["Content-Type"] = "application/json"
        }
        if anonymous, let id = anonId() {
            headers["X-Anon-Id"] = id
        }
        if authenticated {
            let token: String?
            do {
                token = try await appleToken()
            } catch {
                throw APIError.missingAppleToken
            }
            guard let token, token.isEmpty == false else { throw APIError.missingAppleToken }
            headers["Authorization"] = "Bearer \(token)"
        }
        let request = HTTPRequest(
            method: method,
            url: configuration.url(path: path, query: query),
            headers: headers,
            body: body
        )
        return try await perform(request)
    }

    private func perform(_ request: HTTPRequest) async throws -> HTTPResponse {
        var attemptsUsed = 0
        while true {
            let response: HTTPResponse
            do {
                response = try await transport.send(request)
            } catch is CancellationError {
                throw APIError.transport(CancellationError())
            } catch {
                guard shouldRetry(error), attemptsUsed < retry.maxRetries else {
                    throw APIError.transport(error)
                }
                attemptsUsed += 1
                try await sleeper.sleep(for: retry.delay(forRetry: attemptsUsed, random: jitter()))
                continue
            }

            if response.isSuccess { return response }

            let retryAfter = APIClient.retryAfterSeconds(response)
            if response.isRateLimited {
                if let retryAfter,
                   retryAfter <= retry.maxRetryAfterDelay,
                   attemptsUsed < retry.maxRetries {
                    attemptsUsed += 1
                    try await sleeper.sleep(for: retryAfter)
                    continue
                }
                throw APIError.server(status: response.status, body: response.body, retryAfter: retryAfter)
            }

            if response.isServerFailure, attemptsUsed < retry.maxRetries {
                attemptsUsed += 1
                try await sleeper.sleep(for: retry.delay(forRetry: attemptsUsed, random: jitter()))
                continue
            }

            throw APIError.server(status: response.status, body: response.body, retryAfter: retryAfter)
        }
    }

    private func shouldRetry(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .cancelled, .badURL, .unsupportedURL, .appTransportSecurityRequiresSecureConnection,
             .userAuthenticationRequired, .fileDoesNotExist:
            return false
        default:
            return true
        }
    }

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        do {
            return try CorbieJSON.encoder.encode(value)
        } catch {
            throw APIError.invalidRequest(String(describing: error))
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from response: HTTPResponse) throws -> T {
        do {
            return try CorbieJSON.decoder.decode(type, from: response.body)
        } catch {
            throw APIError.decoding(error)
        }
    }

    static func retryAfterSeconds(_ response: HTTPResponse, now: Date = Date()) -> TimeInterval? {
        guard let raw = response.header("Retry-After")?.trimmingCharacters(in: .whitespacesAndNewlines),
              raw.isEmpty == false
        else { return nil }
        if let seconds = TimeInterval(raw) { return max(0, seconds) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        guard let date = formatter.date(from: raw) else { return nil }
        return max(0, date.timeIntervalSince(now))
    }
}
