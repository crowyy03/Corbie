import Foundation
import Testing
@testable import CorbieCore

@Suite struct NetAPIClientConfigurationTests {
    @Test func projectRefBecomesTheFunctionsBaseURL() throws {
        let configuration = try #require(ServerConfiguration(projectRef: "AbcDef123"))
        #expect(configuration.functionsBaseURL.absoluteString == "https://abcdef123.supabase.co/functions/v1")
        #expect(configuration.url(path: "invite").absoluteString == "https://abcdef123.supabase.co/functions/v1/invite")
    }

    @Test func rawValueAcceptsAFullURLAndRejectsPlainHTTP() throws {
        let full = try #require(ServerConfiguration(rawValue: "https://api.corbie.app/functions/v1/"))
        #expect(full.url(path: "fx", query: [URLQueryItem(name: "base", value: "USD")]).absoluteString
            == "https://api.corbie.app/functions/v1/fx?base=USD")
        #expect(ServerConfiguration(rawValue: "http://api.corbie.app") == nil)
        #expect(ServerConfiguration(rawValue: "  ") == nil)
    }

    @Test func bundleWithoutTheKeyFallsBackToTheCompiledDefault() {
        let configuration = ServerConfiguration.fromBundle(Bundle(for: BundleAnchor.self))
        #expect(configuration == ServerConfiguration.fallback)
        #expect(configuration.isPlaceholder)
    }

    @Test func retryDelayGrowsAndStaysInsideTheJitterBand() {
        let policy = RetryPolicy(maxRetries: 3, baseDelay: 0.5, multiplier: 2, maxDelay: 8, jitterFraction: 0.25)
        #expect(policy.delay(forRetry: 1, random: 0.5) == 0.5)
        #expect(policy.delay(forRetry: 2, random: 0.5) == 1)
        #expect(policy.delay(forRetry: 3, random: 0.5) == 2)
        #expect(policy.delay(forRetry: 1, random: 0) == 0.375)
        #expect(policy.delay(forRetry: 1, random: 1) == 0.625)
        #expect(policy.delay(forRetry: 20, random: 0.5) == 8)
    }

    @Test func retryAfterReadsSecondsAndHTTPDates() {
        let seconds = HTTPResponse(status: 429, headers: ["Retry-After": "12"])
        #expect(APIClient.retryAfterSeconds(seconds) == 12)
        let now = NetTestSupport.date("2026-09-05T10:00:00Z")
        let stamped = HTTPResponse(status: 429, headers: ["retry-after": "Sat, 05 Sep 2026 10:00:30 GMT"])
        #expect(APIClient.retryAfterSeconds(stamped, now: now) == 30)
        #expect(APIClient.retryAfterSeconds(HTTPResponse(status: 429)) == nil)
    }
}

final class BundleAnchor {}

@Suite struct NetAPIClientEndpointTests {
    @Test func createInviteSendsTheAppleTokenAndDecodesTheCode() async throws {
        let transport = FakeTransport(
            json: #"{"code":"K7M2QX","expiresAt":"2026-09-05T12:15:00Z"}"#,
            status: 201
        )
        let client = NetTestSupport.client(transport: transport)
        let space = UUID()
        let invite = try await client.createInvite(
            spaceId: space,
            shareURL: URL(string: "https://www.icloud.com/share/abc")!
        )
        #expect(invite.code == "K7M2QX")
        #expect(invite.expiresAt == NetTestSupport.date("2026-09-05T12:15:00Z"))

        let request = try #require(transport.lastRequest)
        #expect(request.method == .post)
        #expect(request.url.absoluteString.hasSuffix("/invite"))
        #expect(request.header("Authorization") == "Bearer apple-token")
        #expect(request.header("X-App-Version") == "1.0 (12)")
        #expect(request.header("Content-Type") == "application/json")
        #expect(request.header("X-Anon-Id") == nil)

        let body = try #require(request.body)
        let decoded = try #require(try JSONSerialization.jsonObject(with: body) as? [String: String])
        #expect(decoded["spaceId"] == space.uuidString.lowercased())
        #expect(decoded["shareURL"] == "https://www.icloud.com/share/abc")
    }

    @Test func anAuthenticatedCallWithoutATokenNeverReachesTheNetwork() async throws {
        let transport = FakeTransport(json: "{}")
        let client = NetTestSupport.client(transport: transport, appleToken: nil)
        await #expect(throws: APIError.self) {
            _ = try await client.entitlement(spaceId: UUID())
        }
        #expect(transport.requestCount == 0)
        do {
            _ = try await client.entitlement(spaceId: UUID())
        } catch let failure as APIError {
            #expect(failure.kind == .missingAppleToken)
            #expect(failure.isUnauthorized)
            #expect(failure.corbieError == CorbieError.auth("no apple identity token"))
        }
    }

    @Test func redeemInviteUppercasesTheCodeAndSurfacesRedeemed() async throws {
        let transport = FakeTransport([
            .json(#"{"error":"redeemed","message":"This code has already been used"}"#, status: 410)
        ])
        let client = NetTestSupport.client(transport: transport)
        do {
            _ = try await client.redeemInvite(code: " k7m2qx ")
            Issue.record("expected a failure")
        } catch let failure as APIError {
            #expect(failure.status == 410)
            #expect(failure.isRedeemed)
            #expect(failure.isExpired == false)
            #expect(failure.envelope?.message == "This code has already been used")
            #expect(failure.corbieError == CorbieError.network("410 redeemed: This code has already been used"))
        }
        let request = try #require(transport.lastRequest)
        #expect(request.method == .get)
        #expect(request.url.absoluteString.hasSuffix("/invite-redeem/K7M2QX"))
        #expect(request.header("Authorization") == nil)
    }

    @Test func redeemInviteDecodesTheShareURL() async throws {
        let transport = FakeTransport(
            json: #"{"shareURL":"https://www.icloud.com/share/abc","spaceId":"1c2b8e3a-4d5f-4a6b-8c7d-9e0f1a2b3c4d"}"#
        )
        let client = NetTestSupport.client(transport: transport)
        let share = try await client.redeemInvite(code: "K7M2QX")
        #expect(share.shareLink?.host == "www.icloud.com")
        #expect(share.spaceId.uuidString.lowercased() == "1c2b8e3a-4d5f-4a6b-8c7d-9e0f1a2b3c4d")
    }

    @Test func parseAlwaysDecodesWithNullFields() async throws {
        let transport = FakeTransport(
            json: #"{"canonicalURL":"https://www.amazon.com/dp/B0","source":"amazon","title":null,"price":null,"currency":null,"imageURL":null,"author":null}"#
        )
        let client = NetTestSupport.client(transport: transport)
        let payload = try await client.parse(url: URL(string: "https://www.amazon.com/dp/B0?tag=x")!)
        #expect(payload.source == "amazon")
        #expect(payload.title == nil)
        #expect(payload.price == nil)
        #expect(payload.imageLink == nil)
        let request = try #require(transport.lastRequest)
        #expect(request.header("X-Anon-Id") == "6f1e4a1e-0d5f-4e0e-9a54-1a5c1a2b3c4d")
        #expect(request.header("Authorization") == nil)
    }

    @Test func fxDecodesADayOnlyDate() async throws {
        let transport = FakeTransport(json: #"{"base":"USD","date":"2026-09-05","rates":{"EUR":0.91,"GBP":0.78}}"#)
        let client = NetTestSupport.client(transport: transport)
        let payload = try await client.fxRates(base: "usd")
        #expect(payload.base == "USD")
        #expect(payload.date == NetTestSupport.date("2026-09-05"))
        #expect(payload.rates["EUR"] == 0.91)
        let request = try #require(transport.lastRequest)
        #expect(request.url.absoluteString.hasSuffix("/fx?base=USD"))
    }

    @Test func entitlementReadsStatusNoneForAnUnknownSpace() async throws {
        let space = UUID()
        let transport = FakeTransport(
            json: #"{"spaceId":"\#(space.uuidString.lowercased())","status":"none","productId":null,"expiresAt":null,"updatedAt":"2026-09-05T10:00:00.123Z"}"#
        )
        let client = NetTestSupport.client(transport: transport)
        let payload = try await client.entitlement(spaceId: space)
        #expect(payload.status == .none)
        #expect(payload.productId == nil)
        #expect(payload.updatedAt == NetTestSupport.date("2026-09-05T10:00:00.123Z"))
        let request = try #require(transport.lastRequest)
        #expect(request.url.absoluteString.hasSuffix("/entitlement/\(space.uuidString.lowercased())"))
    }

    @Test func entitlementFallsBackToNoneForAnUnknownStatus() throws {
        let raw = Data(#"{"spaceId":"1c2b8e3a-4d5f-4a6b-8c7d-9e0f1a2b3c4d","status":"paused"}"#.utf8)
        let payload = try CorbieJSON.decoder.decode(EntitlementPayload.self, from: raw)
        #expect(payload.status == .none)
    }

    @Test func eventsPostsTheBatchAndRefusesMoreThanFifty() async throws {
        let transport = FakeTransport([.empty(202)])
        let client = NetTestSupport.client(transport: transport)
        let payload = AnalyticsEventPayload(
            name: "task_created",
            props: ["assignee": .string("partner")],
            ts: NetTestSupport.date("2026-09-05T10:00:00Z"),
            appVersion: "1.0 (12)",
            locale: "en_US"
        )
        try await client.events([payload])
        #expect(transport.requestCount == 1)
        #expect(transport.lastRequest?.header("X-Anon-Id") == "6f1e4a1e-0d5f-4e0e-9a54-1a5c1a2b3c4d")
        #expect(NetTestSupport.decodeBatch(transport.lastRequest).count == 1)

        try await client.events([])
        #expect(transport.requestCount == 1)

        do {
            try await client.events(Array(repeating: payload, count: 51))
            Issue.record("expected a failure")
        } catch let failure as APIError {
            #expect(failure.kind == .invalidRequest)
        }
        #expect(transport.requestCount == 1)
    }

    @Test func appleRevokeNeedsOneOfTheTwoTokens() async throws {
        let transport = FakeTransport([.empty(204)])
        let client = NetTestSupport.client(transport: transport)
        try await client.revokeAppleAccount(authorizationCode: "code")
        #expect(transport.requestCount == 1)
        #expect(transport.lastRequest?.header("Authorization") == "Bearer apple-token")
        do {
            try await client.revokeAppleAccount()
            Issue.record("expected a failure")
        } catch let failure as APIError {
            #expect(failure.kind == .invalidRequest)
        }
    }

    @Test func aBrokenBodyIsADecodingFailure() async throws {
        let transport = FakeTransport(json: "not json")
        let client = NetTestSupport.client(transport: transport)
        do {
            _ = try await client.fxRates(base: "USD")
            Issue.record("expected a failure")
        } catch let failure as APIError {
            #expect(failure.kind == .decoding)
            #expect(failure.corbieError.errorDescription != nil)
        }
    }
}

@Suite struct NetAPIClientRetryTests {
    @Test func serverFailuresAreRetriedThreeTimes() async throws {
        let transport = FakeTransport([.empty(500)])
        let sleeper = RecordingSleeper()
        let client = NetTestSupport.client(transport: transport, sleeper: sleeper)
        do {
            _ = try await client.fxRates(base: "USD")
            Issue.record("expected a failure")
        } catch let failure as APIError {
            #expect(failure.status == 500)
        }
        #expect(transport.requestCount == 4)
        #expect(sleeper.delays == [0.5, 1, 2])
    }

    @Test func aRetriedCallSucceedsOnTheThirdAttempt() async throws {
        let transport = FakeTransport([
            .empty(502),
            .empty(500),
            .json(#"{"base":"USD","date":"2026-09-05","rates":{"EUR":0.91}}"#)
        ])
        let sleeper = RecordingSleeper()
        let client = NetTestSupport.client(transport: transport, sleeper: sleeper)
        let payload = try await client.fxRates(base: "USD")
        #expect(payload.rates["EUR"] == 0.91)
        #expect(transport.requestCount == 3)
        #expect(sleeper.delays.count == 2)
    }

    @Test func clientFailuresAreNeverRetried() async throws {
        for status in [400, 401, 404, 405, 410] {
            let transport = FakeTransport([.json(#"{"error":"invalid_request","message":"no"}"#, status: status)])
            let sleeper = RecordingSleeper()
            let client = NetTestSupport.client(transport: transport, sleeper: sleeper)
            do {
                _ = try await client.parse(url: URL(string: "https://example.com")!)
                Issue.record("expected a failure")
            } catch let failure as APIError {
                #expect(failure.status == status)
            }
            #expect(transport.requestCount == 1)
            #expect(sleeper.delays.isEmpty)
        }
    }

    @Test func networkFailuresAreRetriedAndCancellationIsNot() async throws {
        let flaky = FakeTransport([.urlFailure(.timedOut), .urlFailure(.networkConnectionLost), .empty(202)])
        let sleeper = RecordingSleeper()
        let client = NetTestSupport.client(transport: flaky, sleeper: sleeper)
        try await client.events([
            AnalyticsEventPayload(name: "app_open", props: [:], ts: Date(), appVersion: nil, locale: nil)
        ])
        #expect(flaky.requestCount == 3)
        #expect(sleeper.delays.count == 2)

        let cancelled = FakeTransport([.urlFailure(.cancelled)])
        let quiet = RecordingSleeper()
        let second = NetTestSupport.client(transport: cancelled, sleeper: quiet)
        await #expect(throws: APIError.self) {
            _ = try await second.parse(url: URL(string: "https://example.com")!)
        }
        #expect(cancelled.requestCount == 1)
        #expect(quiet.delays.isEmpty)
    }

    @Test func aNonURLErrorFromTheTransportIsNotRetried() async throws {
        let transport = FakeTransport([.otherFailure])
        let sleeper = RecordingSleeper()
        let client = NetTestSupport.client(transport: transport, sleeper: sleeper)
        do {
            _ = try await client.parse(url: URL(string: "https://example.com")!)
            Issue.record("expected a failure")
        } catch let failure as APIError {
            #expect(failure.kind == .transport)
        }
        #expect(transport.requestCount == 1)
    }

    @Test func rateLimitedWaitsOnlyWhenTheServerSaysHowLong() async throws {
        let polite = FakeTransport([
            .json(#"{"error":"rate_limited","message":"slow down"}"#, status: 429, headers: ["Retry-After": "2"]),
            .json(#"{"base":"USD","date":"2026-09-05","rates":{"EUR":0.91}}"#)
        ])
        let sleeper = RecordingSleeper()
        let client = NetTestSupport.client(transport: polite, sleeper: sleeper)
        _ = try await client.fxRates(base: "USD")
        #expect(polite.requestCount == 2)
        #expect(sleeper.delays == [2])

        let silent = FakeTransport([.json(#"{"error":"rate_limited","message":"slow down"}"#, status: 429)])
        let quiet = RecordingSleeper()
        let second = NetTestSupport.client(transport: silent, sleeper: quiet)
        do {
            _ = try await second.fxRates(base: "USD")
            Issue.record("expected a failure")
        } catch let failure as APIError {
            #expect(failure.isRateLimited)
            #expect(failure.retryAfter == nil)
            #expect(failure.code == .rateLimited)
        }
        #expect(silent.requestCount == 1)
        #expect(quiet.delays.isEmpty)
    }

    @Test func aRetryAfterBeyondTheCapIsReportedInsteadOfSlept() async throws {
        let transport = FakeTransport([
            .json(#"{"error":"rate_limited","message":"slow down"}"#, status: 429, headers: ["Retry-After": "3600"])
        ])
        let sleeper = RecordingSleeper()
        let client = NetTestSupport.client(transport: transport, sleeper: sleeper)
        do {
            _ = try await client.fxRates(base: "USD")
            Issue.record("expected a failure")
        } catch let failure as APIError {
            #expect(failure.retryAfter == 3600)
        }
        #expect(transport.requestCount == 1)
        #expect(sleeper.delays.isEmpty)
    }
}
