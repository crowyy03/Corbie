import CorbieCore
import Foundation
import Observation

struct WishEditorRequest: Identifiable {
    let id = UUID()
    var wish: WishDTO?
    var link: String?
}

@MainActor
@Observable
final class WishEditorViewModel {
    enum ParseState: Equatable {
        case idle
        case parsing
        case failed
    }

    var link = ""
    var title = ""
    var priceText = ""
    var currency = "USD"
    var priority: WishPriority = .want
    var note = ""
    var isForMe = false

    private(set) var parseState: ParseState = .idle
    private(set) var localImage: Data?
    private(set) var imageURL: String?
    private(set) var currencies: [String] = []
    private(set) var isSaving = false
    private(set) var isEditing = false

    @ObservationIgnored private var environment: AppEnvironment?
    @ObservationIgnored private var existing: WishDTO?
    @ObservationIgnored private var source: WishSource = .manual
    @ObservationIgnored private var parseTask: Task<Void, Never>?
    @ObservationIgnored private var lastParsedLink: String?
    @ObservationIgnored private var didParseSucceed = false
    @ObservationIgnored private var didConfigure = false

    var canSave: Bool {
        isSaving == false && (WishText.clean(title).isEmpty == false || LinkParser.normalize(link) != nil)
    }

    var screenTitle: String {
        isEditing ? String(localized: "wishes.editor.title.edit") : String(localized: "wishes.editor.title.new")
    }

    func configure(_ environment: AppEnvironment, request: WishEditorRequest) {
        guard didConfigure == false else { return }
        didConfigure = true
        self.environment = environment
        currencies = WishEditorViewModel.currencyOptions(
            spaceCurrency: environment.space?.displayCurrency,
            supported: environment.fx.supportedCurrencies(),
            wishCurrency: request.wish?.currency
        )
        currency = currencies.first ?? "USD"
        if let wish = request.wish {
            existing = wish
            isEditing = true
            link = wish.url ?? ""
            lastParsedLink = link.isEmpty ? nil : link
            title = wish.title
            if let price = wish.price { priceText = WishPricing.text(from: price) }
            currency = WishPricing.currencyCode(wish.currency) ?? currency
            priority = wish.priority
            note = wish.note ?? ""
            localImage = wish.localImage
            imageURL = wish.imageURL
            source = wish.source
            isForMe = environment.isCurrentMember(wish.ownerMemberId)
            didParseSucceed = wish.needsParse == false
        } else {
            isForMe = environment.isPaired == false
            link = request.link ?? ""
            if link.isEmpty == false { linkChanged() }
        }
    }

    func linkChanged() {
        parseTask?.cancel()
        parseState = .idle
        guard let url = LinkParser.normalize(link) else {
            source = existing?.source ?? .manual
            return
        }
        guard url.absoluteString != lastParsedLink else { return }
        didParseSucceed = false
        parseTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard Task.isCancelled == false else { return }
            await self?.parse(url)
        }
    }

    func setPhoto(_ data: Data?) {
        guard let data else {
            localImage = nil
            return
        }
        guard let downsampled = ImageDownsampler.downsample(data) else {
            environment?.report(CorbieError.invalidInput("this photo could not be read"))
            return
        }
        localImage = downsampled.data
    }

    func save() async -> Bool {
        guard let environment, let space = environment.space, let me = environment.currentMember else { return false }
        guard canSave else { return false }
        isSaving = true
        defer { isSaving = false }
        parseTask?.cancel()

        let owner = isForMe ? me.id : (environment.partner?.id ?? me.id)
        let canonicalLink = LinkParser.normalize(link)?.absoluteString
        let needsParse = canonicalLink != nil && didParseSucceed == false
        let price = WishPricing.amount(from: priceText)
        let cleanTitle = WishText.clean(title)
        let cleanNote = WishText.clean(note).isEmpty ? nil : WishText.clean(note)

        do {
            if var wish = existing {
                wish.ownerMemberId = owner
                wish.title = cleanTitle
                wish.url = canonicalLink
                wish.imageURL = imageURL
                wish.localImage = localImage
                wish.price = price
                wish.currency = price == nil ? nil : currency
                wish.priority = priority
                wish.note = cleanNote
                wish.source = source
                wish.needsParse = needsParse
                _ = try await environment.repositories.wishes.update(wish)
            } else {
                let draft = WishDraft(
                    spaceId: space.id,
                    ownerMemberId: owner,
                    addedByMemberId: me.id,
                    title: cleanTitle,
                    url: canonicalLink,
                    imageURL: imageURL,
                    localImage: localImage,
                    price: price,
                    currency: price == nil ? nil : currency,
                    priority: priority,
                    note: cleanNote,
                    source: source,
                    needsParse: needsParse
                )
                _ = try await environment.repositories.wishes.create(draft)
                environment.analytics.record(.wishCreated(source: source))
            }
            return true
        } catch {
            environment.report(error)
            return false
        }
    }

    nonisolated static func currencyOptions(
        spaceCurrency: String?,
        supported: [String],
        wishCurrency: String?
    ) -> [String] {
        var codes: [String] = []
        for candidate in [spaceCurrency, wishCurrency] {
            guard let code = WishPricing.currencyCode(candidate), codes.contains(code) == false else { continue }
            codes.append(code)
        }
        for code in supported.compactMap(WishPricing.currencyCode) where codes.contains(code) == false {
            codes.append(code)
        }
        return codes.isEmpty ? ["USD"] : codes
    }

    private func parse(_ url: URL) async {
        guard let environment else { return }
        lastParsedLink = url.absoluteString
        parseState = .parsing
        do {
            let parsed = try await environment.linkParser.parse(url: url)
            apply(parsed)
            parseState = .idle
            didParseSucceed = true
        } catch {
            parseState = .failed
        }
    }

    private func apply(_ parsed: ParsedLink) {
        link = parsed.canonicalURL.absoluteString
        lastParsedLink = link
        source = parsed.source
        if WishText.clean(title).isEmpty, let parsedTitle = parsed.title {
            title = parsedTitle
        }
        if WishText.clean(priceText).isEmpty, let price = parsed.price {
            priceText = WishPricing.text(from: price)
            if let code = WishPricing.currencyCode(parsed.currency) {
                if currencies.contains(code) == false { currencies.append(code) }
                currency = code
            }
        }
        if let image = parsed.imageURL {
            imageURL = image.absoluteString
        }
        if localImage == nil, let data = parsed.imageData {
            localImage = data
        }
    }
}
