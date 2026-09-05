import Foundation

public struct Money: Sendable, Equatable, Hashable, Codable {
    public let amount: Decimal
    public let currency: String

    public init(amount: Decimal, currency: String) {
        self.amount = amount
        self.currency = currency.uppercased()
    }

    public init(amount: Double, currency: String) {
        self.init(amount: FXMath.decimal(from: amount), currency: currency)
    }

    public var doubleAmount: Double { NSDecimalNumber(decimal: amount).doubleValue }

    public func formatted(locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = currency
        let number = NSDecimalNumber(decimal: amount)
        return formatter.string(from: number) ?? "\(number) \(currency)"
    }

    public func approximate(locale: Locale = .current) -> String {
        "\u{2248} " + formatted(locale: locale)
    }
}

public struct FXRates: Sendable, Equatable, Codable {
    public let base: String
    public let date: Date
    public let rates: [String: Double]
    public let fetchedAt: Date

    public init(base: String, date: Date, rates: [String: Double], fetchedAt: Date) {
        self.base = base.uppercased()
        self.date = date
        self.rates = rates
        self.fetchedAt = fetchedAt
    }

    public init(payload: FXRatesPayload, fetchedAt: Date) {
        self.init(base: payload.base, date: payload.date, rates: payload.rates, fetchedAt: fetchedAt)
    }

    public func rate(to currency: String) -> Double? {
        let code = currency.uppercased()
        if code == base { return 1 }
        return rates[code]
    }

    public func isFresh(at moment: Date, ttl: TimeInterval) -> Bool {
        let age = moment.timeIntervalSince(fetchedAt)
        return age >= 0 && age < ttl
    }
}

public struct FXConversion: Sendable, Equatable {
    public let amount: Decimal
    public let from: String
    public let to: String
    public let rate: Double
    public let converted: Decimal
    public let date: Date

    public init(amount: Decimal, from: String, to: String, rate: Double, converted: Decimal, date: Date) {
        self.amount = amount
        self.from = from.uppercased()
        self.to = to.uppercased()
        self.rate = rate
        self.converted = converted
        self.date = date
    }

    public var money: Money { Money(amount: converted, currency: to) }
    public var convertedAmount: Double { NSDecimalNumber(decimal: converted).doubleValue }
    public var isIdentity: Bool { from == to }
}

public enum FXMath {
    public static let scale: Int16 = 2

    public static func decimal(from value: Double) -> Decimal {
        Decimal(string: String(value)) ?? Decimal(value)
    }

    public static func convert(amount: Decimal, rate: Double) -> Decimal {
        var product = amount * decimal(from: rate)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &product, Int(scale), .plain)
        return rounded
    }
}

final class FXDefaults: @unchecked Sendable {
    private let defaults: UserDefaults

    init(_ defaults: UserDefaults) {
        self.defaults = defaults
    }

    func data(forKey key: String) -> Data? { defaults.data(forKey: key) }
    func set(_ value: Data, forKey key: String) { defaults.set(value, forKey: key) }
    func remove(forKey key: String) { defaults.removeObject(forKey: key) }
}

public struct FXService: Sendable {
    public static let cacheTTL: TimeInterval = 24 * 60 * 60
    public static let cacheKeyPrefix = "corbie.fx.rates."
    public static let baseCurrencies = ["USD", "EUR", "GBP", "CHF", "CAD"]

    private let client: APIClient
    private let defaults: FXDefaults
    private let ttl: TimeInterval
    private let now: @Sendable () -> Date

    public init(
        client: APIClient,
        defaults: UserDefaults = .corbieShared,
        ttl: TimeInterval = FXService.cacheTTL,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.client = client
        self.defaults = FXDefaults(defaults)
        self.ttl = ttl
        self.now = now
    }

    public func rates(base: String) async throws -> FXRates {
        let code = base.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard code.count == 3 else {
            throw CorbieError.invalidInput("currency must be a 3 letter code")
        }
        let moment = now()
        if let cached = cachedRates(base: code), cached.isFresh(at: moment, ttl: ttl) {
            return cached
        }
        do {
            let payload = try await client.fxRates(base: code)
            let fresh = FXRates(payload: payload, fetchedAt: moment)
            store(fresh)
            return fresh
        } catch let failure as APIError {
            if let cached = cachedRates(base: code) { return cached }
            throw failure.corbieError
        }
    }

    public func convert(amount: Decimal, from: String, to: String) async throws -> FXConversion {
        let source = from.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let target = to.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard source.count == 3, target.count == 3 else {
            throw CorbieError.invalidInput("currency must be a 3 letter code")
        }
        if source == target {
            return FXConversion(
                amount: amount,
                from: source,
                to: target,
                rate: 1,
                converted: amount,
                date: now()
            )
        }
        let table = try await rates(base: source)
        guard let rate = table.rate(to: target) else {
            throw CorbieError.notFound("no rate from \(source) to \(target)")
        }
        return FXConversion(
            amount: amount,
            from: source,
            to: target,
            rate: rate,
            converted: FXMath.convert(amount: amount, rate: rate),
            date: table.date
        )
    }

    public func convert(amount: Double, from: String, to: String) async throws -> FXConversion {
        try await convert(amount: FXMath.decimal(from: amount), from: from, to: to)
    }

    public func supportedCurrencies(for locale: Locale = .current) -> [String] {
        var codes = FXService.baseCurrencies
        guard let local = FXService.currencyCode(for: locale)?.uppercased() else { return codes }
        codes.removeAll { $0 == local }
        codes.insert(local, at: 0)
        return codes
    }

    public func cachedRates(base: String) -> FXRates? {
        let key = FXService.cacheKeyPrefix + base.uppercased()
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? CorbieJSON.decoder.decode(FXRates.self, from: data)
    }

    public func clearCache(base: String) {
        defaults.remove(forKey: FXService.cacheKeyPrefix + base.uppercased())
    }

    private func store(_ rates: FXRates) {
        guard let data = try? CorbieJSON.encoder.encode(rates) else { return }
        defaults.set(data, forKey: FXService.cacheKeyPrefix + rates.base)
    }

    static func currencyCode(for locale: Locale) -> String? {
        locale.currency?.identifier
    }
}
