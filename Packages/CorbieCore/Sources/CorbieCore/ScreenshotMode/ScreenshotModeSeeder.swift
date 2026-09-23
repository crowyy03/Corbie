#if DEBUG
import Foundation

public struct ScreenshotModeDemoImages: Sendable {
    public static let directoryName = "DemoAssets"
    public static let fileExtensions = ["jpg", "jpeg", "png", "heic"]
    public static let none = ScreenshotModeDemoImages(directory: nil)

    private let directory: URL?

    public init(directory: URL?) {
        self.directory = directory
    }

    public static func bundled(in bundle: Bundle = .main) -> ScreenshotModeDemoImages {
        ScreenshotModeDemoImages(
            directory: bundle.resourceURL?.appendingPathComponent(directoryName, isDirectory: true)
        )
    }

    public func data(named name: String) -> Data? {
        guard let directory else { return nil }
        for fileExtension in ScreenshotModeDemoImages.fileExtensions {
            let file = directory.appendingPathComponent(name).appendingPathExtension(fileExtension)
            if let data = try? Data(contentsOf: file), data.isEmpty == false {
                return data
            }
        }
        return nil
    }

    public func downsampled(named name: String) -> Data? {
        data(named: name).flatMap { ImageDownsampler.downsample($0)?.data }
    }
}

public struct ScreenshotModeSeedResult: Sendable {
    public let space: SpaceDTO
    public let me: MemberDTO
    public let partner: MemberDTO
    public let tasks: [TaskDTO]
    public let wishes: [WishDTO]
    public let plans: [PlanDTO]
    public let choreSet: ChoreSetDTO
    public let capsules: [CapsuleDTO]
    public let question: DailyQuestionDTO
}

public struct ScreenshotModeSeeder: Sendable {
    public let today: Date
    public let calendar: Calendar
    public let images: ScreenshotModeDemoImages
    private let theme: CorbieTheme = .sand

    public init(today: Date, calendar: Calendar = .current, images: ScreenshotModeDemoImages = .none) {
        self.today = today
        self.calendar = calendar
        self.images = images
    }

    public func seed(into controller: PersistenceController) async throws -> ScreenshotModeSeedResult {
        let repositories = controller.repositories
        let created = try await repositories.spaces.create(
            displayCurrency: ScreenshotModeDemo.currency,
            creatorMemberId: nil,
            now: today
        )
        let me = try await repositories.members.upsertCurrentMember(
            appleUserId: ScreenshotModeDemo.meAppleUserId,
            spaceId: created.id,
            draft: MemberDraft(displayName: ScreenshotModeDemo.meName, colorKey: ScreenshotModeDemo.meColor.rawValue),
            theme: theme
        ).member
        let birthday = partnerBirthday
        let partner = try await repositories.members.upsertCurrentMember(
            appleUserId: ScreenshotModeDemo.partnerAppleUserId,
            spaceId: created.id,
            draft: MemberDraft(
                displayName: ScreenshotModeDemo.partnerName,
                colorKey: ScreenshotModeDemo.partnerColor.rawValue,
                birthdayMonth: birthday.month,
                birthdayDay: birthday.day
            ),
            theme: theme
        ).member
        let people = People(me: me, partner: partner)
        _ = try await repositories.spaces.setCreatorIfUnset(spaceId: created.id, memberId: me.id)
        _ = try await repositories.spaces.setTogetherSince(spaceId: created.id, togetherSince)
        _ = try await repositories.spaces.setSubscription(
            spaceId: created.id,
            status: .active,
            expiresAt: calendar.date(byAdding: .day, value: ScreenshotModeDemo.subscriptionDays, to: today),
            payerMemberId: me.id
        )

        let tasks = try await seedTasks(repositories, spaceId: created.id, people: people)
        let wishes = try await seedWishes(repositories, spaceId: created.id, people: people)
        let plans = try await seedPlans(repositories, spaceId: created.id, people: people)
        let choreSet = try await seedChores(repositories, spaceId: created.id, people: people)
        let capsules = try await seedCapsules(repositories, spaceId: created.id, people: people)
        let question = try await seedQuestion(controller, spaceId: created.id, people: people)
        _ = try await repositories.members.markUsVisited(memberId: me.id, at: max(today, Date()))

        let space = try await repositories.spaces.space(id: created.id) ?? created
        let storedMe = try await repositories.members.member(id: me.id) ?? me
        let storedPartner = try await repositories.members.member(id: partner.id) ?? partner
        return ScreenshotModeSeedResult(
            space: space,
            me: storedMe,
            partner: storedPartner,
            tasks: tasks,
            wishes: wishes,
            plans: plans,
            choreSet: choreSet,
            capsules: capsules,
            question: question
        )
    }

    var togetherSince: Date {
        calendar.date(from: ScreenshotModeDemo.togetherSince) ?? today
    }

    var partnerBirthday: (month: Int?, day: Int?) {
        let date = calendar.date(byAdding: .day, value: ScreenshotModeDemo.partnerBirthdayInDays, to: today) ?? today
        let parts = calendar.dateComponents([.month, .day], from: date)
        return (parts.month, parts.day)
    }

    func startOfDay(inDays offset: Int) -> Date {
        let shifted = calendar.date(byAdding: .day, value: offset, to: today) ?? today
        return calendar.startOfDay(for: shifted)
    }

    func daysAgo(_ days: Int) -> Date {
        calendar.date(byAdding: .day, value: -days, to: today) ?? today
    }

    func nextOpening(of day: DateComponents) -> Date {
        var matching = day
        matching.hour = NotificationScheduler.capsuleOpenHour
        matching.minute = 0
        matching.second = 0
        return calendar.nextDate(after: today, matching: matching, matchingPolicy: .nextTime) ?? today
    }

    func todayAt(_ time: DateComponents) -> Date {
        calendar.date(
            bySettingHour: time.hour ?? 0,
            minute: time.minute ?? 0,
            second: 0,
            of: today
        ) ?? today
    }

    private struct People {
        let me: MemberDTO
        let partner: MemberDTO

        func id(_ who: ScreenshotModeDemo.Who) -> UUID {
            who == .alex ? me.id : partner.id
        }
    }

    private func seedTasks(_ repositories: Repositories, spaceId: UUID, people: People) async throws -> [TaskDTO] {
        var result: [TaskDTO] = []
        for seed in ScreenshotModeDemo.tasks {
            let created = try await repositories.tasks.create(
                TaskDraft(
                    spaceId: spaceId,
                    title: seed.title,
                    dueAt: startOfDay(inDays: seed.dueInDays),
                    createdByMemberId: people.id(seed.createdBy)
                )
            )
            guard let taker = seed.taker else {
                result.append(created)
                continue
            }
            result.append(try await repositories.tasks.take(taskId: created.id, memberId: people.id(taker), at: today))
        }
        return result
    }

    private func seedWishes(_ repositories: Repositories, spaceId: UUID, people: People) async throws -> [WishDTO] {
        var result: [WishDTO] = []
        for seed in ScreenshotModeDemo.wishes.reversed() {
            result.insert(
                try await repositories.wishes.create(
                    WishDraft(
                        spaceId: spaceId,
                        ownerMemberId: people.partner.id,
                        addedByMemberId: people.partner.id,
                        title: seed.title,
                        localImage: images.downsampled(named: seed.imageName),
                        price: seed.price,
                        currency: ScreenshotModeDemo.currency,
                        priority: seed.priority
                    )
                ),
                at: 0
            )
        }
        return result
    }

    private func seedPlans(_ repositories: Repositories, spaceId: UUID, people: People) async throws -> [PlanDTO] {
        var result: [PlanDTO] = []
        for seed in ScreenshotModeDemo.plans {
            let plan = try await repositories.plans.create(
                PlanDraft(
                    spaceId: spaceId,
                    title: seed.title,
                    type: seed.type,
                    targetAmount: seed.target ?? 0,
                    currency: ScreenshotModeDemo.currency,
                    isOpenEnded: seed.target == nil,
                    createdByMemberId: people.me.id
                )
            )
            for contribution in seed.contributions {
                _ = try await repositories.plans.addExpense(
                    planId: plan.id,
                    draft: PlanExpenseDraft(
                        amount: contribution.amount,
                        currency: ScreenshotModeDemo.currency,
                        date: daysAgo(contribution.daysAgo),
                        addedByMemberId: people.id(contribution.addedBy)
                    )
                )
            }
            result.append(try await repositories.plans.plan(id: plan.id) ?? plan)
        }
        return result
    }

    private func seedChores(_ repositories: Repositories, spaceId: UUID, people: People) async throws -> ChoreSetDTO {
        let chores = repositories.chores
        let started = try await chores.startSet(
            spaceId: spaceId,
            catalogIds: ScreenshotModeDemo.chores.map(\.catalogId),
            memberId: people.me.id,
            at: daysAgo(ScreenshotModeDemo.choreSplitStartedDaysAgo)
        )
        _ = try await chores.startRating(setId: started.id)
        let ratedAt = daysAgo(ScreenshotModeDemo.choreSplitRevealedDaysAgo + 1)
        for seed in ScreenshotModeDemo.chores {
            guard let item = started.items.first(where: { $0.catalogId == seed.catalogId }) else {
                throw CorbieError.notFound("chore \(seed.catalogId)")
            }
            _ = try await chores.rate(itemId: item.id, memberId: people.me.id, verdict: seed.alex, at: ratedAt)
            _ = try await chores.rate(itemId: item.id, memberId: people.partner.id, verdict: seed.nora, at: ratedAt)
        }
        _ = try await chores.reveal(setId: started.id, at: daysAgo(ScreenshotModeDemo.choreSplitRevealedDaysAgo))
        return try await chores.set(id: started.id, viewerMemberId: people.me.id) ?? started
    }

    private func seedCapsules(_ repositories: Repositories, spaceId: UUID, people: People) async throws -> [CapsuleDTO] {
        var result: [CapsuleDTO] = []
        for seed in ScreenshotModeDemo.capsules {
            let author = people.id(seed.author)
            let recipient = author == people.me.id ? people.partner.id : people.me.id
            result.append(
                try await repositories.capsules.create(
                    CapsuleDraft(
                        spaceId: spaceId,
                        authorMemberId: author,
                        recipientMemberId: recipient,
                        title: seed.title,
                        body: seed.body,
                        opensAt: nextOpening(of: seed.opensOn)
                    ),
                    now: today
                )
            )
        }
        return result
    }

    private func seedQuestion(
        _ controller: PersistenceController,
        spaceId: UUID,
        people: People
    ) async throws -> DailyQuestionDTO {
        let bank = QuestionBank(entries: QuestionBank.bundled.entries.filter { $0.id == ScreenshotModeDemo.questionId })
        let questions = CoreDataQuestionRepository(stack: controller.stack, bank: bank)
        let asked = try await questions.todaysQuestion(spaceId: spaceId, viewerMemberId: people.me.id, now: today)
        guard let asked else {
            throw CorbieError.notFound("question \(ScreenshotModeDemo.questionId)")
        }
        _ = try await questions.answer(
            dailyQuestionId: asked.id,
            memberId: people.partner.id,
            text: ScreenshotModeDemo.partnerAnswer,
            at: todayAt(ScreenshotModeDemo.partnerAnsweredAt)
        )
        let answered = try await questions.answer(
            dailyQuestionId: asked.id,
            memberId: people.me.id,
            text: ScreenshotModeDemo.myAnswer,
            at: todayAt(ScreenshotModeDemo.myAnswerAt)
        )
        _ = try await questions.markSeen(memberId: people.me.id, dayKey: answered.dayKey)
        _ = try await questions.markRevealRead(memberId: people.me.id, dayKey: answered.dayKey)
        return answered
    }
}
#endif
