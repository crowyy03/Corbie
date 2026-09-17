import CorbieCore
import Foundation

struct SessionService: Sendable {
    struct Token: Sendable, Equatable, Decodable {
        let token: String
        let expiresAt: Date
        let appleRefreshToken: String?
    }

    struct Body: Sendable, Equatable, Encodable {
        let authorizationCode: String?
    }

    static let path = "session"

    private let configuration: ServerConfiguration
    private let session: URLSession
    private let appVersion: String

    init(
        configuration: ServerConfiguration,
        session: URLSession = URLSessionTransport.makeSession(),
        appVersion: String = AppVersion.current()
    ) {
        self.configuration = configuration
        self.session = session
        self.appVersion = appVersion
    }

    var isConfigured: Bool { configuration.isNotConfigured == false }

    func exchange(appleIdentityToken: String, authorizationCode: String? = nil) async throws -> Token {
        guard isConfigured else {
            throw CorbieError.notConfigured("this build carries no server url, see \(ServerConfiguration.infoPlistKey)")
        }
        guard appleIdentityToken.isEmpty == false else {
            throw CorbieError.auth("apple identity token is empty")
        }
        var request = URLRequest(url: configuration.url(path: SessionService.path))
        request.httpMethod = "POST"
        request.setValue("Bearer \(appleIdentityToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(appVersion, forHTTPHeaderField: "X-App-Version")
        request.httpBody = try SessionService.body(authorizationCode: authorizationCode)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw CorbieError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw CorbieError.network("no http response")
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            throw SessionService.failure(status: http.statusCode, body: data)
        }
        do {
            return try CorbieJSON.decoder.decode(Token.self, from: data)
        } catch {
            throw CorbieError.network("session response is not readable")
        }
    }

    static func body(authorizationCode: String?) throws -> Data {
        let code = authorizationCode.flatMap { $0.isEmpty ? nil : $0 }
        do {
            return try CorbieJSON.encoder.encode(Body(authorizationCode: code))
        } catch {
            throw CorbieError.network("session request is not encodable")
        }
    }

    static func failure(status: Int, body: Data) -> CorbieError {
        let envelope = try? CorbieJSON.decoder.decode(ServerErrorEnvelope.self, from: body)
        let detail = envelope?.message ?? "status \(status)"
        if status == 401 || envelope?.code == .unauthorized {
            return .auth(detail)
        }
        return .network(detail)
    }
}
