import CorbieCore
import Foundation
import Observation

enum GiftIdeaEditorMode: Identifiable {
    case new
    case existing(GiftIdeaDTO)

    var id: String {
        switch self {
        case .new: return "new"
        case let .existing(idea): return idea.id.uuidString
        }
    }

    var idea: GiftIdeaDTO? {
        switch self {
        case .new: return nil
        case let .existing(idea): return idea
        }
    }
}

@MainActor
@Observable
final class GiftIdeaEditorViewModel {
    enum LinkState: Equatable {
        case idle
        case loading
        case failed
    }

    var title: String
    var link: String
    var priceText: String
    var currency: String
    var note: String
    private(set) var linkState: LinkState = .idle
    private(set) var isSaving = false

    @ObservationIgnored let personId: UUID
    @ObservationIgnored let mode: GiftIdeaEditorMode
    @ObservationIgnored private var environment: AppEnvironment?
    @ObservationIgnored private var parsedLink: String?

    init(personId: UUID, mode: GiftIdeaEditorMode) {
        self.personId = personId
        self.mode = mode
        let idea = mode.idea
        title = idea?.title ?? ""
        link = idea?.url ?? ""
        priceText = idea?.price.map { $0.formatted(.number.precision(.fractionLength(0...2))) } ?? ""
        currency = idea?.currency ?? ""
        note = idea?.note ?? ""
        parsedLink = idea?.url
    }

    func bind(_ environment: AppEnvironment) {
        self.environment = environment
        if currency.isEmpty {
            currency = environment.space?.displayCurrency ?? Locale.current.currency?.identifier ?? "USD"
        }
    }

    var currencies: [String] {
        var codes = environment?.fx.supportedCurrencies() ?? FXService.baseCurrencies
        if codes.contains(currency) == false, currency.isEmpty == false {
            codes.insert(currency, at: 0)
        }
        return codes
    }

    var isParsing: Bool { linkState == .loading }

    var hasFailedLink: Bool { linkState == .failed }

    var canSave: Bool {
        isSaving == false
            && isParsing == false
            && title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    func parseLinkIfNeeded() async {
        guard let environment else { return }
        let raw = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard raw.isEmpty == false, raw != parsedLink else { return }
        guard LinkParser.normalize(raw) != nil else {
            linkState = .failed
            return
        }
        linkState = .loading
        do {
            let parsed = try await environment.linkParser.parse(rawURL: raw)
            link = parsed.canonicalURL.absoluteString
            parsedLink = link
            if let parsedTitle = parsed.title, title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                title = parsedTitle
            }
            if let price = parsed.price, priceText.isEmpty {
                priceText = price.formatted(.number.precision(.fractionLength(0...2)))
            }
            if let parsedCurrency = parsed.currency {
                currency = parsedCurrency
            }
            linkState = parsed.title == nil && parsed.price == nil ? .failed : .idle
        } catch {
            parsedLink = raw
            linkState = .failed
        }
    }

    func save() async -> Bool {
        guard let environment else { return false }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTitle.isEmpty == false else { return false }
        isSaving = true
        defer { isSaving = false }
        let price = GiftIdeaEditorViewModel.price(from: priceText)
        do {
            switch mode {
            case .new:
                _ = try await environment.repositories.people.addGiftIdea(
                    personId: personId,
                    draft: GiftIdeaDraft(
                        title: trimmedTitle,
                        url: trimmed(link),
                        price: price,
                        currency: price == nil ? nil : currency,
                        note: trimmed(note)
                    )
                )
            case .existing(var idea):
                idea.title = trimmedTitle
                idea.url = trimmed(link)
                idea.price = price
                idea.currency = price == nil ? nil : currency
                idea.note = trimmed(note)
                _ = try await environment.repositories.people.updateGiftIdea(idea)
            }
            return true
        } catch {
            environment.report(error)
            return false
        }
    }

    static func price(from text: String, locale: Locale = .current) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        if let value = try? Double(trimmed, format: .number.locale(locale)) { return value }
        return Double(trimmed)
    }

    private func trimmed(_ value: String) -> String? {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }
}
