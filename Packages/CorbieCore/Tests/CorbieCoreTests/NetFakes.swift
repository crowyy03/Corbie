import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
@testable import CorbieCore

enum FakeOutcome: Sendable {
    case response(HTTPResponse)
    case urlFailure(URLError.Code)
    case otherFailure

    static func json(_ text: String, status: Int = 200, headers: [String: String] = [:]) -> FakeOutcome {
        .response(HTTPResponse(status: status, headers: headers, body: Data(text.utf8)))
    }

    static func empty(_ status: Int, headers: [String: String] = [:]) -> FakeOutcome {
        .response(HTTPResponse(status: status, headers: headers))
    }

    static func binary(_ data: Data, status: Int = 200) -> FakeOutcome {
        .response(HTTPResponse(status: status, body: data))
    }
}

struct FakeTransportFailure: Error {}

final class FakeTransport: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var outcomes: [FakeOutcome]
    private var recorded: [HTTPRequest] = []
    private let delay: TimeInterval

    init(_ outcomes: [FakeOutcome], delay: TimeInterval = 0) {
        self.outcomes = outcomes.isEmpty ? [.empty(500)] : outcomes
        self.delay = delay
    }

    convenience init(json: String, status: Int = 200, headers: [String: String] = [:]) {
        self.init([.json(json, status: status, headers: headers)])
    }

    var requests: [HTTPRequest] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    var requestCount: Int { requests.count }

    var lastRequest: HTTPRequest? { requests.last }

    private func nextOutcome(for request: HTTPRequest) -> FakeOutcome {
        lock.lock()
        defer { lock.unlock() }
        recorded.append(request)
        return outcomes.count > 1 ? outcomes.removeFirst() : outcomes[0]
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        switch nextOutcome(for: request) {
        case let .response(response):
            return response
        case let .urlFailure(code):
            throw URLError(code)
        case .otherFailure:
            throw FakeTransportFailure()
        }
    }
}

final class RecordingSleeper: RetrySleeper, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [TimeInterval] = []

    var delays: [TimeInterval] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    private func note(_ duration: TimeInterval) {
        lock.lock()
        recorded.append(duration)
        lock.unlock()
    }

    func sleep(for duration: TimeInterval) async throws {
        note(duration)
    }
}

final class RecordingAnalytics: AnalyticsRecording, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [AnalyticsEvent] = []

    var events: [AnalyticsEvent] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    var names: [String] { events.map(\.name) }

    func record(_ event: AnalyticsEvent) {
        lock.lock()
        recorded.append(event)
        lock.unlock()
    }
}

struct StubLocalEntitlements: LocalEntitlementProviding {
    let value: LocalEntitlement?

    init(_ value: LocalEntitlement?) {
        self.value = value
    }

    func currentEntitlement() async -> LocalEntitlement? { value }
}

enum NetTestSupport {
    static func client(
        transport: FakeTransport,
        sleeper: RetrySleeper = RecordingSleeper(),
        appleToken: String? = "apple-token",
        anonId: String? = "6f1e4a1e-0d5f-4e0e-9a54-1a5c1a2b3c4d",
        retry: RetryPolicy = .default
    ) -> APIClient {
        APIClient(
            configuration: ServerConfiguration(projectRef: "testref") ?? .fallback,
            transport: transport,
            appVersion: "1.0 (12)",
            anonId: { anonId },
            appleToken: { appleToken },
            retry: retry,
            sleeper: sleeper,
            jitter: { 0.5 }
        )
    }

    static func defaults(_ name: String = UUID().uuidString) -> UserDefaults {
        UserDefaults(suiteName: "corbie.tests." + name) ?? .standard
    }

    static func removeDefaults(_ defaults: UserDefaults, name: String) {
        defaults.removePersistentDomain(forName: "corbie.tests." + name)
    }

    static func date(_ iso: String) -> Date {
        CorbieJSON.date(from: iso) ?? Date(timeIntervalSince1970: 0)
    }

    static func pngImage(width: Int, height: Int) -> Data {
        let space = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return Data() }
        context.setFillColor(CGColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        for index in 0 ..< 40 {
            let shade = Double(index) / 40
            context.setFillColor(CGColor(red: shade, green: 1 - shade, blue: 0.5, alpha: 1))
            context.fill(
                CGRect(
                    x: index * width / 40,
                    y: index * height / 80,
                    width: width / 40,
                    height: height / 2
                )
            )
        }
        guard let image = context.makeImage() else { return Data() }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output as CFMutableData,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else { return Data() }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return Data() }
        return output as Data
    }

    static func decodeBatch(_ request: HTTPRequest?) -> [AnalyticsEventPayload] {
        guard let body = request?.body,
              let batch = try? CorbieJSON.decoder.decode(AnalyticsBatch.self, from: body)
        else { return [] }
        return batch.events
    }
}
