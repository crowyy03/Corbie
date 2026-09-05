import Foundation
import Testing
@testable import CorbieCore

@Suite struct NetFXServiceTests {
    private let ratesJSON = #"{"base":"USD","date":"2026-09-05","rates":{"EUR":0.91,"GBP":0.78,"CHF":0.88,"CAD":1.36}}"#

    private func makeDefaults(_ name: String) -> UserDefaults {
        let defaults = UserDefaults(suiteName: "corbie.tests." + name) ?? .standard
        defaults.removePersistentDomain(forName: "corbie.tests." + name)
        return defaults
    }

    private final class Clock: @unchecked Sendable {
        private let lock = NSLock()
        private var value: Date

        init(_ value: Date) { self.value = value }

        var current: Date {
            lock.lock()
            defer { lock.unlock() }
            return value
        }

        func advance(_ seconds: TimeInterval) {
            lock.lock()
            value = value.addingTimeInterval(seconds)
            lock.unlock()
        }
    }

    @Test func aSecondCallInsideTwentyFourHoursReadsTheCache() async throws {
        let name = "fx-cache-hit"
        let defaults = makeDefaults(name)
        defer { defaults.removePersistentDomain(forName: "corbie.tests." + name) }

        let transport = FakeTransport(json: ratesJSON)
        let clock = Clock(NetTestSupport.date("2026-09-05T10:00:00Z"))
        let service = FXService(
            client: NetTestSupport.client(transport: transport),
            defaults: defaults,
            now: { clock.current }
        )

        let first = try await service.rates(base: "USD")
        #expect(first.rates["EUR"] == 0.91)
        #expect(transport.requestCount == 1)

        clock.advance(23 * 60 * 60)
        let second = try await service.rates(base: "usd")
        #expect(second.fetchedAt == first.fetchedAt)
        #expect(transport.requestCount == 1)
    }

    @Test func theCacheExpiresAfterTwentyFourHours() async throws {
        let name = "fx-cache-expiry"
        let defaults = makeDefaults(name)
        defer { defaults.removePersistentDomain(forName: "corbie.tests." + name) }

        let transport = FakeTransport(json: ratesJSON)
        let clock = Clock(NetTestSupport.date("2026-09-05T10:00:00Z"))
        let service = FXService(
            client: NetTestSupport.client(transport: transport),
            defaults: defaults,
            now: { clock.current }
        )

        _ = try await service.rates(base: "USD")
        clock.advance(24 * 60 * 60 + 1)
        let refreshed = try await service.rates(base: "USD")
        #expect(transport.requestCount == 2)
        #expect(refreshed.fetchedAt == clock.current)
    }

    @Test func aStaleCacheStillAnswersWhenTheServerIsDown() async throws {
        let name = "fx-stale"
        let defaults = makeDefaults(name)
        defer { defaults.removePersistentDomain(forName: "corbie.tests." + name) }

        let clock = Clock(NetTestSupport.date("2026-09-05T10:00:00Z"))
        let good = FakeTransport(json: ratesJSON)
        let warm = FXService(
            client: NetTestSupport.client(transport: good),
            defaults: defaults,
            now: { clock.current }
        )
        _ = try await warm.rates(base: "USD")

        clock.advance(48 * 60 * 60)
        let broken = FakeTransport([.json(#"{"error":"upstream_failed","message":"down"}"#, status: 502)])
        let cold = FXService(
            client: NetTestSupport.client(transport: broken, retry: .noRetries),
            defaults: defaults,
            now: { clock.current }
        )
        let served = try await cold.rates(base: "USD")
        #expect(served.rates["EUR"] == 0.91)
    }

    @Test func anEmptyCachePlusAFailingServerThrows() async throws {
        let name = "fx-cold"
        let defaults = makeDefaults(name)
        defer { defaults.removePersistentDomain(forName: "corbie.tests." + name) }

        let broken = FakeTransport([.json(#"{"error":"upstream_failed","message":"down"}"#, status: 502)])
        let service = FXService(
            client: NetTestSupport.client(transport: broken, retry: .noRetries),
            defaults: defaults
        )
        await #expect(throws: CorbieError.self) {
            _ = try await service.rates(base: "USD")
        }
    }

    @Test func conversionUsesTheRateAndRoundsToTwoDecimals() async throws {
        let name = "fx-convert"
        let defaults = makeDefaults(name)
        defer { defaults.removePersistentDomain(forName: "corbie.tests." + name) }

        let transport = FakeTransport(json: ratesJSON)
        let service = FXService(client: NetTestSupport.client(transport: transport), defaults: defaults)

        let hundred = try await service.convert(amount: Decimal(100), from: "USD", to: "EUR")
        #expect(hundred.rate == 0.91)
        #expect(hundred.converted == Decimal(91))
        #expect(hundred.convertedAmount == 91)
        #expect(hundred.isIdentity == false)

        let odd = try await service.convert(amount: 24.99, from: "usd", to: "eur")
        #expect(odd.converted == Decimal(string: "22.74"))
        #expect(odd.date == NetTestSupport.date("2026-09-05"))
    }

    @Test func theSameCurrencyNeverTouchesTheNetwork() async throws {
        let name = "fx-identity"
        let defaults = makeDefaults(name)
        defer { defaults.removePersistentDomain(forName: "corbie.tests." + name) }

        let transport = FakeTransport(json: ratesJSON)
        let service = FXService(client: NetTestSupport.client(transport: transport), defaults: defaults)
        let same = try await service.convert(amount: Decimal(string: "12.34") ?? 0, from: "EUR", to: "eur")
        #expect(same.rate == 1)
        #expect(same.converted == Decimal(string: "12.34"))
        #expect(same.isIdentity)
        #expect(transport.requestCount == 0)
    }

    @Test func anUnknownTargetCurrencyIsNotFound() async throws {
        let name = "fx-unknown"
        let defaults = makeDefaults(name)
        defer { defaults.removePersistentDomain(forName: "corbie.tests." + name) }

        let transport = FakeTransport(json: ratesJSON)
        let service = FXService(client: NetTestSupport.client(transport: transport), defaults: defaults)
        await #expect(throws: CorbieError.self) {
            _ = try await service.convert(amount: Decimal(10), from: "USD", to: "JPY")
        }
        await #expect(throws: CorbieError.invalidInput("currency must be a 3 letter code")) {
            _ = try await service.convert(amount: Decimal(10), from: "US", to: "EUR")
        }
    }

    @Test func supportedCurrenciesPutTheLocaleCurrencyFirst() {
        let name = "fx-currencies"
        let defaults = makeDefaults(name)
        defer { defaults.removePersistentDomain(forName: "corbie.tests." + name) }

        let service = FXService(client: NetTestSupport.client(transport: FakeTransport(json: ratesJSON)), defaults: defaults)
        #expect(service.supportedCurrencies(for: Locale(identifier: "en_US")) == ["USD", "EUR", "GBP", "CHF", "CAD"])
        #expect(service.supportedCurrencies(for: Locale(identifier: "de_DE")) == ["EUR", "USD", "GBP", "CHF", "CAD"])
        #expect(service.supportedCurrencies(for: Locale(identifier: "pl_PL")) == ["PLN", "USD", "EUR", "GBP", "CHF", "CAD"])
    }

    @Test func moneyFormatsWithTheGivenLocale() {
        let dollars = Money(amount: Decimal(string: "2400") ?? 0, currency: "usd")
        #expect(dollars.currency == "USD")
        #expect(dollars.formatted(locale: Locale(identifier: "en_US")) == "$2,400.00")
        #expect(dollars.doubleAmount == 2400)

        let euros = Money(amount: 91.5, currency: "EUR")
        let german = euros.formatted(locale: Locale(identifier: "de_DE"))
        #expect(german.contains("91,50"))
        #expect(euros.approximate(locale: Locale(identifier: "en_US")).hasPrefix("\u{2248} "))
    }

    @Test func decimalConversionKeepsTheDigitsOfADouble() {
        #expect(FXMath.decimal(from: 24.99) == Decimal(string: "24.99"))
        #expect(FXMath.decimal(from: 0.1) + FXMath.decimal(from: 0.2) == Decimal(string: "0.3"))
        #expect(FXMath.convert(amount: Decimal(string: "19.99") ?? 0, rate: 1.36) == Decimal(string: "27.19"))
    }
}
