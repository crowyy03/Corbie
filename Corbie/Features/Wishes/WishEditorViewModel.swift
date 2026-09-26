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
    var currency = SupportedCurrencies.defaultCode
    var priority: WishPriority = .want
    var note = ""
    var isForMe = false

    private(set) var parseState: ParseState = .idle
    private(set) var priceLeftOut: PriceLeftOut?
    private(set) var localImage: Data?
    private(set) var imageURL: String?
    let currencies = SupportedCurrencies.codes
    private(set) var isSaving = false
    private(set) var isEditing = false

    @ObservationIgnored private var environment: AppEnvironment?
    @ObservationIgnored private var existing: WishDTO?
    @ObservationIgnored private var loadedIsForMe = false
    @ObservationIgnored private var source: WishSource = .manual
    @ObservationIgnored private var parseTask: Task<Void, Never>?
    @ObservationIgnored private var settledLink: String?
    @ObservationIgnored private var didParseSucceed = false
    @ObservationIgnored private var didConfigure = false

    var canSave: Bool {
        isSaving == false && (WishText.clean(title).isEmpty == false || linkInField != nil)
    }

    var priceHint: String? {
        guard WishText.clean(priceText).isEmpty, let priceLeftOut else { return nil }
        switch priceLeftOut {
        case .unsupportedCurrency(let code):
            return String(format: String(localized: "wishes.editor.price.hint.unsupported"), code)
        case .unknownCurrency:
            return String(localized: "wishes.editor.price.hint.unknown")
        }
    }

    var screenTitle: String {
        isEditing ? String(localized: "wishes.editor.title.edit") : String(localized: "wishes.editor.title.new")
    }

    func configure(_ environment: AppEnvironment, request: WishEditorRequest) {
        guard didConfigure == false else { return }
        didConfigure = true
        self.environment = environment
        currency = environment.space?.displayCurrency ?? SupportedCurrencies.defaultCode
        if let wish = request.wish {
            existing = wish
            isEditing = true
            link = wish.url ?? ""
            settledLink = linkInField?.absoluteString
            title = wish.title
            if let price = wish.price { priceText = WishPricing.text(from: price) }
            if let code = wish.currency, currencies.contains(code) { currency = code }
            priority = wish.priority
            note = wish.note ?? ""
            localImage = wish.localImage
            imageURL = wish.imageURL
            source = wish.source
            isForMe = environment.isCurrentMember(wish.ownerMemberId)
            loadedIsForMe = isForMe
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
        let url = linkInField
        if let url, url.absoluteString == settledLink { return }
        settledLink = nil
        priceLeftOut = nil
        didParseSucceed = false
        guard let url else {
            source = existing?.source ?? .manual
            return
        }
        parseTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard Task.isCancelled == false else { return }
            await self?.parse(url)
        }
    }

    func linkSubmitted() {
        guard parseState != .parsing, didParseSucceed == false else { return }
        settledLink = nil
        linkChanged()
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
        let canonicalLink = linkInField?.absoluteString
        let needsParse = canonicalLink != nil && didParseSucceed == false
        let price = WishPricing.amount(from: priceText)
        let cleanTitle = WishText.clean(title)
        let cleanNote = WishText.clean(note).isEmpty ? nil : WishText.clean(note)

        do {
            if let original = existing {
                var wish = original
                if isForMe != loadedIsForMe {
                    wish.ownerMemberId = owner
                }
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
                _ = try await environment.repositories.wishes.update(wish, from: original)
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

    private var linkInField: URL? {
        LinkParser.firstLink(in: link)
    }

    private func parse(_ url: URL) async {
        guard let environment else { return }
        parseState = .parsing
        do {
            let parsed = try await environment.linkParser.parse(url: url)
            guard Task.isCancelled == false else { return }
            guard parsed.isEmpty == false else {
                parseState = .failed
                WishLinkLog.readEmpty(url, parsed: parsed, reader: .editor)
                environment.toasts.show(message: String(localized: "wishes.editor.link.empty"))
                return
            }
            apply(parsed)
            parseState = .idle
            didParseSucceed = true
        } catch {
            guard Task.isCancelled == false else { return }
            parseState = .failed
            WishLinkLog.failed(url, error: error, reader: .editor)
            environment.report(error)
        }
    }

    private func apply(_ parsed: ParsedLink) {
        link = parsed.canonicalURL.absoluteString
        settledLink = linkInField?.absoluteString
        source = parsed.source
        priceLeftOut = parsed.priceLeftOut
        if WishText.clean(title).isEmpty, let parsedTitle = parsed.title {
            title = parsedTitle
        }
        if WishText.clean(priceText).isEmpty, let price = parsed.price {
            priceText = WishPricing.text(from: price)
            if let code = parsed.currency, currencies.contains(code) {
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
