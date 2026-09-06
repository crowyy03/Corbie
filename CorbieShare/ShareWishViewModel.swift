import CorbieCore
import Foundation
import Observation
import WidgetKit

struct ShareInput: Sendable, Equatable {
    var url: URL?
    var text: String?

    var isEmpty: Bool { url == nil && (text?.isEmpty ?? true) }

    static func firstLink(in text: String?) -> URL? {
        guard let text else { return nil }
        let tokens = text.split(whereSeparator: \.isWhitespace).map(String.init)
        for token in tokens.reversed() {
            if let url = LinkParser.normalize(token) { return url }
        }
        return nil
    }
}

@MainActor
@Observable
final class ShareWishViewModel {
    enum Stage: Equatable {
        case loading
        case noSession
        case readOnly
        case ready
    }

    var title = ""
    var priority: WishPriority = .want
    var isForMe = false

    private(set) var stage: Stage = .loading
    private(set) var isParsing = false
    private(set) var didParseFail = false
    private(set) var didSaveFail = false
    private(set) var link: URL?
    private(set) var partnerName: String?
    private(set) var isSaving = false
    private(set) var didReadInput = false

    @ObservationIgnored private var persistence: PersistenceController?
    @ObservationIgnored private var space: SpaceDTO?
    @ObservationIgnored private var member: MemberDTO?
    @ObservationIgnored private var partnerId: UUID?
    @ObservationIgnored private var imageURL: String?
    @ObservationIgnored private var localImage: Data?
    @ObservationIgnored private var price: Double?
    @ObservationIgnored private var currency: String?
    @ObservationIgnored private var source: WishSource = .manual
    @ObservationIgnored private var didParseSucceed = false

    var hasNothingShared: Bool {
        didReadInput && link == nil && WishText.clean(title).isEmpty
    }

    var canSave: Bool {
        stage == .ready && isSaving == false && (WishText.clean(title).isEmpty == false || link != nil)
    }

    func start(_ input: ShareInput) async {
        didReadInput = true
        link = input.url ?? ShareInput.firstLink(in: input.text)
        if link == nil, let text = input.text {
            title = WishText.clean(text)
        }
        await resolveSession()
        guard stage == .ready, let url = link else { return }
        await parse(url)
    }

    func save() async -> Bool {
        guard let persistence, let space, let member, canSave else { return false }
        isSaving = true
        didSaveFail = false
        defer { isSaving = false }
        let owner = isForMe ? member.id : (partnerId ?? member.id)
        let draft = WishDraft(
            spaceId: space.id,
            ownerMemberId: owner,
            addedByMemberId: member.id,
            title: WishText.clean(title),
            url: link?.absoluteString,
            imageURL: imageURL,
            localImage: localImage,
            price: price,
            currency: price == nil ? nil : currency,
            priority: priority,
            source: source,
            needsParse: link != nil && didParseSucceed == false
        )
        do {
            _ = try await persistence.repositories.wishes.create(draft)
            WidgetReloadRequest.post()
            WidgetCenter.shared.reloadAllTimelines()
            return true
        } catch {
            didSaveFail = true
            return false
        }
    }

    private func resolveSession() async {
        let controller = PersistenceController.cloudKit(author: .share)
        persistence = controller
        guard let appleUserID = MemberIdentity().currentAppleUserID,
              let member = try? await controller.repositories.members.member(appleUserId: appleUserID),
              let space = try? await controller.repositories.spaces.currentSpace(memberId: member.id)
        else {
            stage = .noSession
            return
        }
        self.member = member
        self.space = space
        currency = space.displayCurrency
        let partner = try? await controller.repositories.members.partner(of: member.id, spaceId: space.id)
        partnerId = partner?.id
        partnerName = partner?.displayName
        isForMe = partnerId == nil
        let entitlements = EntitlementService(
            client: APIClient(identity: .shared),
            spaces: controller.repositories.spaces
        )
        let state = await entitlements.cachedState(spaceId: space.id, trialEndsAt: space.trialEndsAt)
        stage = state.isPremium ? .ready : .readOnly
    }

    private func parse(_ url: URL) async {
        isParsing = true
        defer { isParsing = false }
        let parser = LinkParser(client: APIClient(identity: .shared))
        guard let parsed = try? await parser.parse(url: url) else {
            didParseFail = true
            return
        }
        didParseSucceed = true
        link = parsed.canonicalURL
        source = parsed.source
        if WishText.clean(title).isEmpty, let parsedTitle = parsed.title {
            title = parsedTitle
        }
        if let parsedPrice = parsed.price {
            price = parsedPrice
            currency = parsed.currency ?? currency
        }
        imageURL = parsed.imageURL?.absoluteString
        localImage = parsed.imageData
    }
}
