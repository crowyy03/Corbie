#if DEBUG
import Foundation

public enum ScreenshotModeDemo {
    public struct TaskSeed: Sendable, Equatable {
        public let title: String
        public let taker: Who?
        public let dueInDays: Int
        public let createdBy: Who
    }

    public struct WishSeed: Sendable, Equatable {
        public let title: String
        public let price: Double
        public let priority: WishPriority
        public let imageName: String
    }

    public struct ContributionSeed: Sendable, Equatable {
        public let amount: Double
        public let daysAgo: Int
        public let addedBy: Who
    }

    public struct PlanSeed: Sendable, Equatable {
        public let title: String
        public let type: PlanType
        public let target: Double?
        public let contributions: [ContributionSeed]

        public var total: Double { contributions.reduce(0) { $0 + $1.amount } }
    }

    public struct ChoreSeed: Sendable, Equatable {
        public let catalogId: String
        public let alex: ChoreVerdict
        public let nora: ChoreVerdict
    }

    public struct CapsuleSeed: Sendable, Equatable {
        public let author: Who
        public let title: String
        public let body: String
        public let opensOn: DateComponents
    }

    public enum Who: String, Sendable, Equatable {
        case alex
        case nora
    }

    public static let meName = "Alex"
    public static let partnerName = "Nora"
    public static let meAppleUserId = "screenshot-mode.alex"
    public static let partnerAppleUserId = "screenshot-mode.nora"
    public static let meColor = MemberColorSlot.teal
    public static let partnerColor = MemberColorSlot.rose
    public static let currency = "USD"
    public static let togetherSince = DateComponents(year: 2023, month: 4, day: 20, hour: 12)
    public static let partnerBirthdayInDays = 12
    public static let subscriptionDays = 365

    public static let tasks: [TaskSeed] = [
        TaskSeed(title: "Book the vet", taker: .alex, dueInDays: 0, createdBy: .alex),
        TaskSeed(title: "Pick up the parcel", taker: .nora, dueInDays: 1, createdBy: .nora),
        TaskSeed(title: "Change the light bulbs", taker: nil, dueInDays: 0, createdBy: .nora),
        TaskSeed(title: "Call about the boiler", taker: nil, dueInDays: 1, createdBy: .alex),
        TaskSeed(title: "Renew the car insurance", taker: nil, dueInDays: 3, createdBy: .alex),
        TaskSeed(title: "Return the library books", taker: nil, dueInDays: 4, createdBy: .nora)
    ]

    public static let wishes: [WishSeed] = [
        WishSeed(title: "Wool coat", price: 240, priority: .must, imageName: "wool-coat"),
        WishSeed(title: "Ceramics class", price: 85, priority: .want, imageName: "ceramics-class"),
        WishSeed(
            title: "Noise-cancelling headphones",
            price: 299,
            priority: .want,
            imageName: "noise-cancelling-headphones"
        ),
        WishSeed(title: "Linen bedding set", price: 180, priority: .want, imageName: "linen-bedding-set")
    ]

    public static let plans: [PlanSeed] = [
        PlanSeed(
            title: "Japan, October",
            type: .trip,
            target: 5000,
            contributions: [
                ContributionSeed(amount: 1000, daysAgo: 58, addedBy: .alex),
                ContributionSeed(amount: 800, daysAgo: 31, addedBy: .nora),
                ContributionSeed(amount: 600, daysAgo: 6, addedBy: .alex)
            ]
        ),
        PlanSeed(
            title: "New sofa",
            type: .purchase,
            target: 900,
            contributions: [
                ContributionSeed(amount: 400, daysAgo: 24, addedBy: .nora),
                ContributionSeed(amount: 280, daysAgo: 3, addedBy: .alex)
            ]
        ),
        PlanSeed(
            title: "Rainy day",
            type: .other,
            target: nil,
            contributions: [
                ContributionSeed(amount: 500, daysAgo: 26, addedBy: .alex),
                ContributionSeed(amount: 300, daysAgo: 19, addedBy: .nora),
                ContributionSeed(amount: 240, daysAgo: 11, addedBy: .alex),
                ContributionSeed(amount: 200, daysAgo: 2, addedBy: .nora)
            ]
        )
    ]

    public static let dishes = "c001"
    public static let trash = "c005"
    public static let bathroom = "c010"
    public static let ironing = "c018"
    public static let fridge = "c006"
    public static let cooking = "c003"
    public static let vacuum = "c008"
    public static let groceries = "c019"

    public static let chores: [ChoreSeed] = [
        ChoreSeed(catalogId: dishes, alex: .hate, nora: .fine),
        ChoreSeed(catalogId: trash, alex: .fine, nora: .hate),
        ChoreSeed(catalogId: bathroom, alex: .hate, nora: .hate),
        ChoreSeed(catalogId: ironing, alex: .hate, nora: .hate),
        ChoreSeed(catalogId: fridge, alex: .hate, nora: .hate),
        ChoreSeed(catalogId: cooking, alex: .like, nora: .fine),
        ChoreSeed(catalogId: vacuum, alex: .neutral, nora: .like),
        ChoreSeed(catalogId: groceries, alex: .like, nora: .like)
    ]

    public static let choreSplitStartedDaysAgo = 3
    public static let choreSplitRevealedDaysAgo = 1

    public static let capsules: [CapsuleSeed] = [
        CapsuleSeed(
            author: .nora,
            title: "For February 14",
            body: "You still fold the map the wrong way. I still like watching you try.",
            opensOn: DateComponents(month: 2, day: 14)
        ),
        CapsuleSeed(
            author: .alex,
            title: "For our anniversary",
            body: "Another year of you stealing the warm side of the bed. Keep it.",
            opensOn: DateComponents(month: 4, day: 20)
        )
    ]

    public static let questionId = "q0102"
    public static let partnerAnswer = "Dishes. Warm water, a podcast, and nobody asks me anything."
    public static let myAnswer = "Cooking, as long as someone else chops the onions."
    public static let partnerAnsweredAt = DateComponents(hour: 8, minute: 5)
    public static let myAnswerAt = DateComponents(hour: 8, minute: 40)
}
#endif
