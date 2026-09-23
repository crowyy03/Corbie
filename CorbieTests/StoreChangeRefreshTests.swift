import CorbieCore
import CoreData
import XCTest
@testable import Corbie

@MainActor
final class StoreChangeRefreshTests: XCTestCase {
    private var world: SyncedWorld!

    override func setUp() async throws {
        world = try await SyncedWorld.make()
    }

    override func tearDown() async throws {
        world.close()
        world = nil
    }

    func testTodayShowsATaskThatArrivesFromThePartner() async throws {
        let model = TodayViewModel(
            repositories: world.environment.repositories,
            notifications: world.environment.notifications,
            analytics: world.environment.analytics
        )
        model.startObserving()
        await model.apply(TodayContext(space: world.space, memberId: world.me.id))
        XCTAssertFalse(model.feed.tasksToday.contains { $0.task?.title == "Call the plumber" })

        try await world.fromPartner {
            _ = try await $0.tasks.create(
                TaskDraft(
                    spaceId: self.world.space.id,
                    title: "Call the plumber",
                    assigneeMemberId: self.world.me.id,
                    dueAt: Date(),
                    createdByMemberId: self.world.partner.id
                )
            )
        }

        try await arrives("the task on Today") {
            model.feed.tasksToday.contains { $0.task?.title == "Call the plumber" }
        }
    }

    func testTheTodayChoreCardMovesWhenThePartnerStartsASplit() async throws {
        let model = TodayChoreModel()
        await model.start(world.environment)
        XCTAssertEqual(model.state, .notStarted)

        try await world.fromPartner {
            _ = try await $0.chores.startSet(
                spaceId: self.world.space.id,
                catalogIds: SyncedWorld.eightChores,
                memberId: self.world.partner.id,
                at: Date()
            )
        }

        try await arrives("the started split on the Today card") { model.state != .notStarted }
    }

    func testTheTodayQuestionCardShowsThePartnersAnswer() async throws {
        let model = TodayQuestionModel()
        await model.start(world.environment)
        let question = try XCTUnwrap(model.question)

        try await world.fromPartner {
            _ = try await $0.questions.answer(
                dailyQuestionId: question.id,
                memberId: self.world.partner.id,
                text: "The sea",
                at: Date()
            )
        }

        try await arrives("the partner's answer on the card") {
            model.question?.hasAnswered(self.world.partner.id) == true
        }
    }

    func testTheQuestionScreenShowsThePartnersAnswer() async throws {
        let question = try await world.todaysQuestion()
        let model = QuestionViewModel(question: question, text: QuestionCopy().text(of: question) ?? "question")
        await model.attach(world.environment)

        try await world.fromPartner {
            _ = try await $0.questions.answer(
                dailyQuestionId: question.id,
                memberId: self.world.partner.id,
                text: "The sea",
                at: Date()
            )
        }

        try await arrives("the partner's answer on the question screen") {
            model.question.hasAnswered(self.world.partner.id)
        }
    }

    func testTheQuestionScreenShowsAnAnswerFromThePartnersOwnRowForTheDay() async throws {
        let question = try await world.todaysQuestion()
        let model = QuestionViewModel(question: question, text: QuestionCopy().text(of: question) ?? "question")
        await model.attach(world.environment)

        try await world.partnerRowForToday(like: question, answer: "The mountains")

        try await arrives("the answer written in the partner's own row") {
            model.question.dayKey == question.dayKey && model.question.hasAnswered(self.world.partner.id)
        }
    }

    func testTheQuestionHistoryShowsThePartnersAnswer() async throws {
        let question = try await world.todaysQuestion()
        let model = QuestionHistoryViewModel()
        model.reloadOnStoreChanges(world.environment)
        await model.load(world.environment)

        try await world.fromPartner {
            _ = try await $0.questions.answer(
                dailyQuestionId: question.id,
                memberId: self.world.partner.id,
                text: "The sea",
                at: Date()
            )
        }

        try await arrives("the partner's answer in the history") {
            model.days.contains { $0.id == question.id && $0.hasAnswered(self.world.partner.id) }
        }
    }

    func testTasksShowATaskThatArrivesFromThePartner() async throws {
        let model = TasksViewModel(
            repository: world.environment.repositories.tasks,
            changes: world.environment.repositories.changes,
            notifications: TaskDueNotifications(scheduler: world.environment.notifications),
            analytics: world.environment.analytics
        )
        model.startObserving()
        await model.apply(
            TasksContext(spaceId: world.space.id, memberId: world.me.id, partnerId: world.partner.id)
        )

        try await world.fromPartner {
            _ = try await $0.tasks.create(
                TaskDraft(spaceId: self.world.space.id, title: "Fix the shelf", createdByMemberId: self.world.partner.id)
            )
        }

        try await arrives("the task in Tasks") { model.tasks.contains { $0.title == "Fix the shelf" } }
    }

    func testTheCalendarShowsAnEventThatArrivesFromThePartner() async throws {
        let model = CalendarViewModel()
        model.reloadOnStoreChanges(world.environment)
        await model.load(world.environment)

        try await world.fromPartner {
            _ = try await $0.events.create(
                EventDraft(
                    spaceId: self.world.space.id,
                    title: "Dinner at Ana's",
                    startAt: Date().addingTimeInterval(86_400),
                    createdByMemberId: self.world.partner.id
                )
            )
        }

        try await arrives("the event in the calendar") {
            model.entries.contains { entry in
                if case let .event(event) = entry.source { return event.title == "Dinner at Ana's" }
                return false
            }
        }
    }

    func testAnEventShowsACommentThatArrivesFromThePartner() async throws {
        let event = try await world.environment.repositories.events.create(
            EventDraft(spaceId: world.space.id, title: "Dinner", startAt: Date(), createdByMemberId: world.me.id)
        )
        let model = EventDetailViewModel(eventId: event.id)
        model.reloadOnStoreChanges(world.environment)
        await model.load(world.environment)

        try await world.fromPartner {
            _ = try await $0.events.addComment(eventId: event.id, memberId: self.world.partner.id, text: "I'll bring wine")
        }

        try await arrives("the comment on the event") { model.comments.contains { $0.text == "I'll bring wine" } }
    }

    func testWishesShowAWishThatArrivesFromThePartner() async throws {
        let model = WishesViewModel()
        model.configure(world.environment)
        await model.load()

        try await world.fromPartner {
            _ = try await $0.wishes.create(
                WishDraft(spaceId: self.world.space.id, ownerMemberId: self.world.partner.id, title: "Linen shirt")
            )
        }

        try await arrives("the wish in Wishes") { model.active.contains { $0.title == "Linen shirt" } }
    }

    func testAnOpenWishShowsWhatThePartnerChanged() async throws {
        let wish = try await world.environment.repositories.wishes.create(
            WishDraft(spaceId: world.space.id, ownerMemberId: world.me.id, title: "Linen shirt")
        )
        let model = WishDetailViewModel(wishId: wish.id, wish: wish)
        model.attach(world.environment)
        await model.load()

        try await world.fromPartner {
            var retitled = wish
            retitled.title = "Linen shirt, sand"
            _ = try await $0.wishes.update(retitled, from: wish)
            _ = try await $0.wishes.fulfil(wishId: wish.id)
        }

        try await arrives("the new title and the fulfilment on the open wish") {
            model.wish?.title == "Linen shirt, sand" && model.wish?.isFulfilled == true
        }
    }

    func testAnOpenWishGoesBackWhenThePartnerDeletesIt() async throws {
        let wish = try await world.environment.repositories.wishes.create(
            WishDraft(spaceId: world.space.id, ownerMemberId: world.me.id, title: "Linen shirt")
        )
        let model = WishDetailViewModel(wishId: wish.id, wish: wish)
        model.attach(world.environment)
        await model.load()
        XCTAssertFalse(model.isGone)

        try await world.fromPartner {
            try await $0.wishes.delete(id: wish.id)
        }

        try await arrives("the open wish leaving after the partner deleted it") { model.isGone }
    }

    func testPlansShowAPlanAndAListThatArriveFromThePartner() async throws {
        let model = PlansViewModel()
        model.attach(world.environment)
        await model.load()

        try await world.fromPartner {
            _ = try await $0.plans.create(
                PlanDraft(spaceId: self.world.space.id, title: "Lisbon", createdByMemberId: self.world.partner.id)
            )
            _ = try await $0.lists.create(
                ChecklistDraft(spaceId: self.world.space.id, title: "Packing", createdByMemberId: self.world.partner.id)
            )
        }

        try await arrives("the plan and the list in Plans") {
            model.plans.contains { $0.title == "Lisbon" } && model.lists.contains { $0.title == "Packing" }
        }
    }

    func testAPlanShowsAStepThatArrivesFromThePartner() async throws {
        let plan = try await world.environment.repositories.plans.create(
            PlanDraft(spaceId: world.space.id, title: "Lisbon", createdByMemberId: world.me.id)
        )
        let model = PlanDetailViewModel(planId: plan.id)
        model.attach(world.environment)
        await model.load()

        try await world.fromPartner {
            _ = try await $0.plans.addStep(planId: plan.id, draft: PlanStepDraft(title: "Book the flat"))
        }

        try await arrives("the step in the plan") { model.steps.contains { $0.title == "Book the flat" } }
    }

    func testAListShowsAnItemThatArrivesFromThePartner() async throws {
        let list = try await world.environment.repositories.lists.create(
            ChecklistDraft(spaceId: world.space.id, title: "Packing", createdByMemberId: world.me.id)
        )
        let model = ListDetailViewModel(listId: list.id)
        model.attach(world.environment)
        await model.load()

        try await world.fromPartner {
            _ = try await $0.lists.addItem(listId: list.id, draft: ListItemDraft(title: "Sunscreen"))
        }

        try await arrives("the item in the list") { model.items.contains { $0.title == "Sunscreen" } }
    }

    func testCapsulesShowACapsuleThatArrivesFromThePartner() async throws {
        let model = CapsulesViewModel()
        await model.load(world.environment)

        try await world.fromPartner {
            _ = try await $0.capsules.create(
                CapsuleDraft(
                    spaceId: self.world.space.id,
                    authorMemberId: self.world.partner.id,
                    recipientMemberId: self.world.me.id,
                    title: "For next spring",
                    body: "Open it in April",
                    opensAt: Date().addingTimeInterval(90 * 86_400)
                ),
                now: Date()
            )
        }

        try await arrives("the capsule in Capsules") { model.capsules.contains { $0.title == "For next spring" } }
    }

    func testVotesShowAVoteThatArrivesFromThePartner() async throws {
        let model = VotesViewModel()
        await model.load(world.environment)

        try await world.fromPartner {
            _ = try await $0.votes.create(
                VoteDraft(
                    spaceId: self.world.space.id,
                    question: "Where to on Friday",
                    options: ["Cinema", "Home"],
                    createdByMemberId: self.world.partner.id
                )
            )
        }

        try await arrives("the vote in Votes") { model.votes.contains { $0.question == "Where to on Friday" } }
    }

    func testAVoteShowsThePartnersAnswer() async throws {
        let vote = try await world.environment.repositories.votes.create(
            VoteDraft(spaceId: world.space.id, question: "Pizza or sushi", options: ["Pizza", "Sushi"], createdByMemberId: world.me.id)
        )
        let model = VoteViewModel(vote: vote)
        model.attach(world.environment)

        try await world.fromPartner {
            _ = try await $0.votes.respond(voteId: vote.id, memberId: self.world.partner.id, optionIndexes: [1], at: Date())
        }

        try await arrives("the partner's answer on the vote") { model.vote.responses.hasAnswered(self.world.partner.id) }
    }

    func testPeopleShowAPersonThatArrivesFromThePartner() async throws {
        let model = PeopleViewModel()
        model.bind(world.environment)
        await model.load()

        try await world.fromPartner {
            _ = try await $0.people.create(PersonDraft(spaceId: self.world.space.id, name: "Ana"))
        }

        try await arrives("the person in People") { model.people.contains { $0.name == "Ana" } }
    }

    func testAPersonShowsAGiftIdeaThatArrivesFromThePartner() async throws {
        let person = try await world.environment.repositories.people.create(PersonDraft(spaceId: world.space.id, name: "Ana"))
        let model = PersonDetailViewModel(personId: person.id)
        model.bind(world.environment)
        await model.load()

        try await world.fromPartner {
            _ = try await $0.people.addGiftIdea(personId: person.id, draft: GiftIdeaDraft(title: "Ceramic vase"))
        }

        try await arrives("the gift idea on the person") { model.ideas.contains { $0.title == "Ceramic vase" } }
    }

    func testTheUsHubCountsWhatArrivesFromThePartner() async throws {
        let model = UsHubViewModel()
        model.reloadOnStoreChanges(world.environment)
        await model.load(world.environment)
        XCTAssertEqual(model.peopleCount, 0)

        try await world.fromPartner {
            _ = try await $0.people.create(PersonDraft(spaceId: self.world.space.id, name: "Ana"))
        }

        try await arrives("the person counted on Us") { model.peopleCount == 1 }
    }

    func testFreeTimeFollowsThePartnersBusyTimes() async throws {
        let me = try await world.environment.repositories.members.setSharesBusyTimes(memberId: world.me.id, shares: true)
        let partner = try await world.environment.repositories.members.setSharesBusyTimes(
            memberId: world.partner.id,
            shares: true
        )
        let environment = AppEnvironment.previewSignedIn(
            persistence: world.app,
            space: world.space,
            member: me,
            partner: partner,
            transport: OfflineTransport()
        )
        let model = FreeTimeViewModel(calendarAccess: { .granted })
        await model.open(environment)
        guard case .slots = model.state else {
            return XCTFail("with nobody busy the week should be open, got \(model.state)")
        }

        try await world.fromPartner {
            _ = try await $0.busyIntervals.replace(
                spaceId: self.world.space.id,
                memberId: self.world.partner.id,
                source: .corbie,
                intervals: [BusyIntervalDraft(startAt: Date().addingTimeInterval(-3600), endAt: Date().addingTimeInterval(9 * 86_400))],
                at: Date()
            )
        }

        try await arrives("the partner's busy week in free time") { model.state == .noSlots }
    }

    func testTheChoreSplitMovesWhenThePartnerStartsIt() async throws {
        let model = ChoresViewModel(
            repository: world.environment.repositories.chores,
            changes: world.environment.repositories.changes,
            analytics: world.environment.analytics
        )
        await model.apply(ChoresContext(spaceId: world.space.id, memberId: world.me.id, partnerId: world.partner.id))
        XCTAssertTrue(model.sets.isEmpty)

        try await world.fromPartner {
            _ = try await $0.chores.startSet(
                spaceId: self.world.space.id,
                catalogIds: SyncedWorld.eightChores,
                memberId: self.world.partner.id,
                at: Date()
            )
        }

        try await arrives("the partner's split in the chore flow") { model.sets.isEmpty == false }
    }

    func testTheChoreHistoryShowsASplitThePartnerApplied() async throws {
        let model = ChoreHistoryViewModel()
        model.attach(world.environment)
        await model.load()

        try await world.fromPartner { try await self.world.applySplit(in: $0) }

        try await arrives("the applied split in the history") { model.sets.isEmpty == false }
    }

    func testTasksStopOfferingTheSplitOnceThePartnerAppliedOne() async throws {
        let model = ChoreSplitOfferModel()
        model.attach(world.environment)
        await model.load()
        XCTAssertTrue(model.isOffered)

        try await world.fromPartner { try await self.world.applySplit(in: $0) }

        try await arrives("the split offer gone from Tasks") { model.isOffered == false }
    }

    func testTheSessionPicksUpAPartnerWhoJoinedElsewhere() async throws {
        let alone = try await SyncedWorld.make(paired: false)
        defer { alone.close() }
        let watcher = Task { await PartnerChangeWatcher().observe(alone.environment) }
        defer { watcher.cancel() }
        XCTAssertNil(alone.environment.partner)

        try await alone.fromPartner {
            _ = try await $0.members.upsertCurrentMember(
                appleUserId: "tests.partner",
                spaceId: alone.space.id,
                draft: MemberDraft(displayName: "Sofia", colorKey: MemberColorSlot.rose.rawValue),
                theme: .sand
            )
        }

        try await arrives("the partner in the session") { alone.environment.partner?.displayName == "Sofia" }
    }

    func testEveryScreenThatReadsStoredDataIsCovered() throws {
        let thisFile = URL(fileURLWithPath: #filePath)
        let features = thisFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Corbie/Features")
        let tests = try String(contentsOf: thisFile, encoding: .utf8)
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: features, includingPropertiesForKeys: nil))
        var readers: Set<String> = []
        for case let file as URL in enumerator where file.pathExtension == "swift" {
            let source = try String(contentsOf: file, encoding: .utf8)
            guard source.contains("repositories.") || source.range(of: #"\w+Repository\b"#, options: .regularExpression) != nil
            else { continue }
            readers.insert(String(file.path.dropFirst(features.path.count + 1)))
        }

        let unclassified = readers.subtracting(StoreChangeCoverage.all.keys).sorted()
        XCTAssertEqual(
            unclassified,
            [],
            "decide whether these refresh on synced changes and add them to StoreChangeCoverage"
        )
        let vanished = Set(StoreChangeCoverage.all.keys).subtracting(readers).sorted()
        XCTAssertEqual(vanished, [], "these no longer read stored data, drop them from StoreChangeCoverage")
        for (file, coverage) in StoreChangeCoverage.all {
            guard case let .refreshes(test) = coverage else { continue }
            XCTAssertTrue(
                tests.contains("func \(test)("),
                "\(file) is marked as refreshing but \(test) does not exist"
            )
        }
    }

    private func arrives(
        _ what: String,
        timeout: TimeInterval = 8,
        _ condition: () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTFail("the screen never showed \(what) after the synced change")
    }
}

enum StoreChangeCoverage {
    case refreshes(test: String)
    case snapshot(reason: String)

    static let editsACopy = snapshot(reason: "an editor: it edits a copy and writes only the fields it changed")

    static let all: [String: StoreChangeCoverage] = [
        "Today/TodayViewModel.swift": .refreshes(test: "testTodayShowsATaskThatArrivesFromThePartner"),
        "Today/TodayView.swift": .snapshot(reason: "builds the Today models and the quick editors"),
        "Chores/TodayChoreModel.swift": .refreshes(test: "testTheTodayChoreCardMovesWhenThePartnerStartsASplit"),
        "Question/TodayQuestionModel.swift": .refreshes(test: "testTheTodayQuestionCardShowsThePartnersAnswer"),
        "Question/QuestionViewModel.swift": .refreshes(test: "testTheQuestionScreenShowsAnAnswerFromThePartnersOwnRowForTheDay"),
        "Question/QuestionHistoryViewModel.swift": .refreshes(test: "testTheQuestionHistoryShowsThePartnersAnswer"),
        "Question/QuestionRevealTracking.swift": .snapshot(reason: "writes that the reveal was read, shows nothing"),
        "Tasks/TasksViewModel.swift": .refreshes(test: "testTasksShowATaskThatArrivesFromThePartner"),
        "Tasks/TasksView.swift": .snapshot(reason: "reads one task by id to open a route"),
        "Tasks/TaskEditorView.swift": editsACopy,
        "Tasks/TaskEditorViewModel.swift": editsACopy,
        "Calendar/CalendarViewModel.swift": .refreshes(test: "testTheCalendarShowsAnEventThatArrivesFromThePartner"),
        "Calendar/EventDetailViewModel.swift": .refreshes(test: "testAnEventShowsACommentThatArrivesFromThePartner"),
        "Calendar/EventEditorViewModel.swift": editsACopy,
        "Calendar/CalendarImportViewModel.swift": .snapshot(reason: "a one-off import from the device calendar"),
        "Wishes/WishesViewModel.swift": .refreshes(test: "testWishesShowAWishThatArrivesFromThePartner"),
        "Wishes/WishEditorViewModel.swift": editsACopy,
        "Wishes/WishDetailViewModel.swift": .refreshes(test: "testAnOpenWishShowsWhatThePartnerChanged"),
        "Wishes/WishActions.swift": .snapshot(reason: "fulfils or deletes a wish for the list and the detail, shows nothing"),
        "Plans/PlansViewModel.swift": .refreshes(test: "testPlansShowAPlanAndAListThatArriveFromThePartner"),
        "Plans/PlanDetailViewModel.swift": .refreshes(test: "testAPlanShowsAStepThatArrivesFromThePartner"),
        "Plans/PlanEditorViewModel.swift": editsACopy,
        "Plans/PlanStepEditorViewModel.swift": editsACopy,
        "Plans/ExpenseEditorViewModel.swift": editsACopy,
        "Plans/Lists/ListDetailViewModel.swift": .refreshes(test: "testAListShowsAnItemThatArrivesFromThePartner"),
        "Plans/Lists/ListEditorViewModel.swift": editsACopy,
        "Plans/Lists/ListItemEditorViewModel.swift": editsACopy,
        "Capsules/CapsulesViewModel.swift": .refreshes(test: "testCapsulesShowACapsuleThatArrivesFromThePartner"),
        "Capsules/CapsuleEditorViewModel.swift": editsACopy,
        "Capsules/CapsuleOpenViewModel.swift": .snapshot(
            reason: "the opening of one capsule; the list behind it refreshes"
        ),
        "Votes/VotesViewModel.swift": .refreshes(test: "testVotesShowAVoteThatArrivesFromThePartner"),
        "Votes/VoteViewModel.swift": .refreshes(test: "testAVoteShowsThePartnersAnswer"),
        "Votes/VoteEditorViewModel.swift": editsACopy,
        "People/PeopleViewModel.swift": .refreshes(test: "testPeopleShowAPersonThatArrivesFromThePartner"),
        "People/PersonDetailViewModel.swift": .refreshes(test: "testAPersonShowsAGiftIdeaThatArrivesFromThePartner"),
        "People/PersonEditorViewModel.swift": editsACopy,
        "People/PersonDateEditorViewModel.swift": editsACopy,
        "People/GiftIdeaEditorViewModel.swift": editsACopy,
        "People/PeopleRadar.swift": .snapshot(reason: "a helper the people screens call on every reload"),
        "Us/UsHubViewModel.swift": .refreshes(test: "testTheUsHubCountsWhatArrivesFromThePartner"),
        "FreeTime/FreeTimeViewModel.swift": .refreshes(test: "testFreeTimeFollowsThePartnersBusyTimes"),
        "FreeTime/BusyTimesSharing.swift": .snapshot(reason: "writes this phone's busy times, shows nothing"),
        "Chores/ChoresViewModel.swift": .refreshes(test: "testTheChoreSplitMovesWhenThePartnerStartsIt"),
        "Chores/ChoreHistoryViewModel.swift": .refreshes(test: "testTheChoreHistoryShowsASplitThePartnerApplied"),
        "Chores/ChoreSplitOfferModel.swift": .refreshes(test: "testTasksStopOfferingTheSplitOnceThePartnerAppliedOne"),
        "Chores/ChoresView.swift": .snapshot(reason: "builds the flow models; ChoresViewModel refreshes the flow"),
        "Chores/ChoreListBuilderViewModel.swift": editsACopy,
        "Chores/ChoreRatingViewModel.swift": .snapshot(
            reason: "rates its own queue; ChoresViewModel moves the flow on when the partner's ratings arrive"
        ),
        "Chores/ChoreRevealViewModel.swift": .snapshot(
            reason: "shows a split both already rated; ChoresViewModel moves the flow on once it is applied"
        ),
        "Pairing/PartnerChangeWatcher.swift": .refreshes(test: "testTheSessionPicksUpAPartnerWhoJoinedElsewhere"),
        "Pairing/PartnerDepartureWatcher.swift": .snapshot(
            reason: "checks on the server whether the partner left, after changes from elsewhere; shows nothing"
        ),
        "Pairing/JoinViewModel.swift": .snapshot(reason: "the join flow, it waits for the space itself"),
        "Pairing/SpaceContentProbe.swift": .snapshot(reason: "a one-off check during a join"),
        "Onboarding/OnboardingViewModel.swift": .snapshot(
            reason: "creates the space and the profile once; its invite step follows the stored partner on its own"
        ),
        "Settings/SettingsViewModel.swift": .snapshot(
            reason: "reads the session, which PartnerChangeWatcher refreshes on every stored change"
        ),
        "Settings/SettingsNotificationsViewModel.swift": .snapshot(
            reason: "this member's notification switches, only edited here"
        ),
        "Settings/NotificationBacklog.swift": .snapshot(reason: "schedules notifications, shows nothing"),
    ]
}

@MainActor
private struct SyncedWorld {
    static let eightChores = ["c001", "c002", "c003", "c004", "c005", "c006", "c007", "c008"]

    let directory: URL
    let suiteName: String
    let app: PersistenceController
    let partnerSide: PersistenceController
    let environment: AppEnvironment
    let space: SpaceDTO
    let me: MemberDTO
    let partner: MemberDTO

    static func make(paired: Bool = true) async throws -> SyncedWorld {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("corbie-refresh-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let suiteName = "corbie-refresh-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let app = PersistenceController(stack: CoreDataStack(storesIn: directory, author: .app, historyDefaults: defaults))
        let partnerSide = PersistenceController(stack: CoreDataStack(storesIn: directory, author: .widgets))
        let repositories = app.repositories
        let space = try await repositories.spaces.create(displayCurrency: "USD", creatorMemberId: nil, now: Date())
        let me = try await repositories.members.upsertCurrentMember(
            appleUserId: "tests.me",
            spaceId: space.id,
            draft: MemberDraft(displayName: "Ilya", colorKey: MemberColorSlot.teal.rawValue),
            theme: .sand
        ).member
        let partner = try await repositories.members.upsertCurrentMember(
            appleUserId: "tests.partner",
            spaceId: space.id,
            draft: MemberDraft(displayName: "Sofia", colorKey: MemberColorSlot.rose.rawValue),
            theme: .sand
        ).member
        if paired == false {
            try await repositories.members.delete(id: partner.id)
        }
        let environment = AppEnvironment.previewSignedIn(
            persistence: app,
            space: space,
            member: me,
            partner: paired ? partner : nil,
            transport: OfflineTransport()
        )
        try environment.identity.setAppleUserID("tests.me")
        return SyncedWorld(
            directory: directory,
            suiteName: suiteName,
            app: app,
            partnerSide: partnerSide,
            environment: environment,
            space: space,
            me: me,
            partner: partner
        )
    }

    func fromPartner(_ write: @escaping (Repositories) async throws -> Void) async throws {
        try await write(partnerSide.repositories)
        _ = try app.stack.processHistory()
    }

    func partnerRowForToday(like question: DailyQuestionDTO, answer text: String) async throws {
        let context = partnerSide.stack.newBackgroundContext()
        let spaceId = space.id
        let partnerId = partner.id
        try await context.perform {
            let request = NSFetchRequest<Space>(entityName: Space.entityName)
            request.predicate = NSPredicate(format: "id == %@", spaceId as NSUUID)
            guard let space = try context.fetch(request).first, let store = space.objectID.persistentStore else {
                throw CorbieError.notFound(Space.entityName)
            }
            let row = DailyQuestion(context: context)
            context.assign(row, to: store)
            row.id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")
            row.questionId = question.questionId
            row.dayKey = question.dayKey
            row.space = space
            let answer = QuestionAnswer(context: context)
            context.assign(answer, to: store)
            answer.memberId = partnerId
            answer.text = text
            answer.dailyQuestion = row
            try context.save()
        }
        _ = try app.stack.processHistory()
    }

    func todaysQuestion() async throws -> DailyQuestionDTO {
        let question = try await environment.repositories.questions.todaysQuestion(
            spaceId: space.id,
            viewerMemberId: me.id,
            now: Date()
        )
        return try XCTUnwrap(question, "the bank gave no question for today")
    }

    func applySplit(in repositories: Repositories) async throws {
        let chores = repositories.chores
        let built = try await chores.startSet(
            spaceId: space.id,
            catalogIds: SyncedWorld.eightChores,
            memberId: partner.id,
            at: Date()
        )
        var latest = try await chores.startRating(setId: built.id)
        for item in latest.includedItems {
            latest = try await chores.rate(itemId: item.id, memberId: me.id, verdict: .like, at: Date())
            latest = try await chores.rate(itemId: item.id, memberId: partner.id, verdict: .hate, at: Date())
        }
        let revealed = try await chores.reveal(setId: latest.id, at: Date())
        _ = try await chores.apply(setId: revealed.id, memberId: partner.id, at: Date())
    }

    func close() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: directory)
    }
}

private struct OfflineTransport: HTTPTransport {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        throw URLError(.notConnectedToInternet)
    }
}
