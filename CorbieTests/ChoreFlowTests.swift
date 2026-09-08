import CorbieCore
import XCTest
@testable import Corbie

@MainActor
final class ChoreListBuilderViewModelTests: XCTestCase {
    func testRatingWaitsUntilEightChoresAreIn() async throws {
        let fixture = try await ChoreFixture.make()
        let model = fixture.builder(try await fixture.startSet(catalogIds: ["c001", "c002", "c003"]))

        XCTAssertEqual(model.includedCount, 3)
        XCTAssertEqual(model.missingCount, 5)
        XCTAssertFalse(model.canContinue)

        await model.startRating()
        XCTAssertEqual(model.choreSet.status, .building)
        XCTAssertEqual(fixture.analytics.names, [])

        for id in ["c004", "c005", "c006", "c007", "c008"] {
            await model.toggle(try fixture.catalogItem(id))
        }
        XCTAssertEqual(model.includedCount, 8)
        XCTAssertEqual(model.missingCount, 0)
        XCTAssertTrue(model.canContinue)

        await model.startRating()
        XCTAssertEqual(model.choreSet.status, .rating)
        XCTAssertEqual(fixture.analytics.names, ["chore_list_built"])
    }

    func testTurningAChoreOffDropsItBackBelowTheBar() async throws {
        let fixture = try await ChoreFixture.make()
        let ids = ["c001", "c002", "c003", "c004", "c005", "c006", "c007", "c008"]
        let model = fixture.builder(try await fixture.startSet(catalogIds: ids))
        XCTAssertTrue(model.canContinue)

        await model.toggle(try fixture.catalogItem("c001"))

        XCTAssertFalse(model.isIncluded(try fixture.catalogItem("c001")))
        XCTAssertEqual(model.includedCount, 7)
        XCTAssertFalse(model.canContinue)
    }

    func testYourOwnChoreJoinsTheListAndLeavesIt() async throws {
        let fixture = try await ChoreFixture.make()
        let model = fixture.builder(try await fixture.startSet(catalogIds: ["c001"]))

        model.drafts[ChoreGroup.kitchen.rawValue] = "   "
        await model.addCustom(in: .kitchen)
        XCTAssertTrue(model.customItems.isEmpty)

        model.drafts[ChoreGroup.kitchen.rawValue] = "  Feed the sourdough  "
        await model.addCustom(in: .kitchen)

        let custom = try XCTUnwrap(model.customItems.first)
        XCTAssertEqual(custom.title, "Feed the sourdough")
        XCTAssertTrue(custom.isIncluded)
        XCTAssertEqual(model.drafts[ChoreGroup.kitchen.rawValue], "")
        XCTAssertEqual(model.includedCount, 2)

        await model.setFrequency(.monthly, of: custom)
        XCTAssertEqual(model.customItems.first?.frequency, .monthly)

        await model.remove(try XCTUnwrap(model.customItems.first))
        XCTAssertTrue(model.customItems.isEmpty)
        XCTAssertEqual(model.includedCount, 1)
    }

    func testAChoreKeepsTheFrequencyYouGiveIt() async throws {
        let fixture = try await ChoreFixture.make()
        let model = fixture.builder(try await fixture.startSet(catalogIds: ["c001", "c002"]))
        let dishes = try fixture.catalogItem("c001")
        XCTAssertEqual(model.frequency(of: dishes), .daily)

        await model.setFrequency(.weekly, of: dishes)

        XCTAssertEqual(model.frequency(of: dishes), .weekly)
    }
}

@MainActor
final class ChoreRatingViewModelTests: XCTestCase {
    func testTheDeckReadsEverySwipeDirection() {
        XCTAssertEqual(ChoreSwipe.verdict(for: CGSize(width: -120, height: 6)), .hate)
        XCTAssertEqual(ChoreSwipe.verdict(for: CGSize(width: 120, height: -6)), .fine)
        XCTAssertEqual(ChoreSwipe.verdict(for: CGSize(width: 12, height: -140)), .like)
        XCTAssertNil(ChoreSwipe.verdict(for: CGSize(width: 20, height: -20)))
        XCTAssertNil(ChoreSwipe.verdict(for: .zero))
    }

    func testEachGestureStoresItsOwnVerdict() async throws {
        let fixture = try await ChoreFixture.make()
        let model = fixture.rating(try await fixture.ratingSet())

        XCTAssertEqual(model.total, 8)
        XCTAssertEqual(model.position, 1)
        XCTAssertFalse(model.canUndo)

        let gestures: [CGSize] = [
            CGSize(width: -120, height: 0),
            CGSize(width: 120, height: 0),
            CGSize(width: 0, height: -120)
        ]
        for gesture in gestures {
            await model.rate(try XCTUnwrap(ChoreSwipe.verdict(for: gesture)))
        }
        await model.rate(.neutral)

        let verdicts = model.queue.prefix(4).map { $0.verdict(of: fixture.me.id) }
        XCTAssertEqual(verdicts, [.hate, .fine, .like, .neutral])
        XCTAssertEqual(model.position, 5)
        XCTAssertFalse(model.isDone)
    }

    func testUndoTakesTheLastVerdictBack() async throws {
        let fixture = try await ChoreFixture.make()
        let model = fixture.rating(try await fixture.ratingSet())
        await model.rate(.hate)
        await model.rate(.like)
        XCTAssertEqual(model.position, 3)

        await model.undo()

        XCTAssertEqual(model.position, 2)
        XCTAssertNil(model.queue[1].verdict(of: fixture.me.id))
        XCTAssertEqual(model.queue[0].verdict(of: fixture.me.id), .hate)
        XCTAssertTrue(model.canUndo)
    }

    func testFinishingTheDeckIsReportedOnce() async throws {
        let fixture = try await ChoreFixture.make()
        let model = fixture.rating(try await fixture.ratingSet())
        for _ in 0 ..< model.total {
            await model.rate(.fine)
        }

        XCTAssertTrue(model.isDone)
        XCTAssertNil(model.current)
        XCTAssertEqual(model.position, model.total)
        XCTAssertEqual(fixture.analytics.names, ["chore_rating_done"])

        await model.undo()
        await model.rate(.hate)
        XCTAssertEqual(fixture.analytics.names, ["chore_rating_done"])
    }

    func testAHalfRatedDeckResumesWhereYouLeftOff() async throws {
        let fixture = try await ChoreFixture.make()
        let started = try await fixture.ratingSet()
        let first = fixture.rating(started)
        await first.rate(.fine)
        await first.rate(.fine)

        let resumed = fixture.rating(first.choreSet)

        XCTAssertEqual(resumed.position, 3)
        XCTAssertTrue(resumed.canUndo)
    }
}

@MainActor
final class ChoreRevealViewModelTests: XCTestCase {
    func testTheBiggestDisagreementBecomesTheTradeCard() async throws {
        let fixture = try await ChoreFixture.make()
        let revealed = try await fixture.revealedSet(
            mine: [.hate, .fine, .fine, .fine, .fine, .fine, .fine, .fine],
            theirs: [.like, .fine, .fine, .fine, .fine, .fine, .fine, .fine]
        )
        let shown = fixture.reveal(revealed).presentation

        XCTAssertEqual(shown.trades.map(\.title), ["Wash the dishes"])
        let dishes = try XCTUnwrap(revealed.includedItems.first { $0.title == "Wash the dishes" })
        XCTAssertEqual(dishes.assignment?.assignedMemberId, fixture.partner.id)
        XCTAssertFalse(fixture.chores(in: shown, kind: .yours).contains("Wash the dishes"))
        XCTAssertTrue(fixture.chores(in: shown, kind: .theirs).contains("Wash the dishes"))
    }

    func testTheTradeCardSpeaksToWhoeverIsLooking() async throws {
        let fixture = try await ChoreFixture.make()
        let revealed = try await fixture.revealedSet(
            mine: [.hate, .fine, .fine, .fine, .fine, .fine, .fine, .fine],
            theirs: [.like, .fine, .fine, .fine, .fine, .fine, .fine, .fine]
        )
        let mine = fixture.reveal(revealed).presentation
        let theirs = ChoreSplitPresentation(
            set: revealed,
            viewerMemberId: fixture.partner.id,
            partnerMemberId: fixture.me.id,
            partnerName: fixture.me.displayName ?? ""
        )

        let card = try XCTUnwrap(mine.trades.first)
        let mirrored = try XCTUnwrap(theirs.trades.first)
        XCTAssertEqual(card.title, mirrored.title)
        XCTAssertNotEqual(card.stamp, mirrored.stamp)
        XCTAssertTrue(card.line.contains(fixture.partner.displayName ?? ""))
        XCTAssertTrue(mirrored.line.contains(fixture.me.displayName ?? ""))
    }

    func testTwoChoresNobodyWantsAreShared() async throws {
        let fixture = try await ChoreFixture.make()
        let revealed = try await fixture.revealedSet(
            mine: [.hate, .hate, .fine, .fine, .fine, .fine, .fine, .fine],
            theirs: [.hate, .hate, .fine, .fine, .fine, .fine, .fine, .fine]
        )
        let shown = fixture.reveal(revealed).presentation

        XCTAssertEqual(
            Set(fixture.chores(in: shown, kind: .rotating)),
            ["Wash the dishes", "Load and empty the dishwasher"]
        )
        XCTAssertTrue(shown.trades.isEmpty)
        XCTAssertEqual(shown.rotatingCount, 2)
    }

    func testTheRevealNeverPutsANumberOnScreen() async throws {
        let fixture = try await ChoreFixture.make()
        let revealed = try await fixture.revealedSet(
            mine: [.hate, .like, .neutral, .fine, .hate, .like, .fine, .neutral],
            theirs: [.like, .hate, .fine, .neutral, .hate, .fine, .like, .neutral]
        )
        let shown = fixture.reveal(revealed).presentation

        XCTAssertFalse(shown.everyLine.isEmpty)
        for line in shown.everyLine {
            XCTAssertFalse(line.contains("%"), line)
            XCTAssertFalse(line.contains(where: \.isNumber), line)
        }
    }

    func testAtMostFourTradeCardsAreShown() async throws {
        let fixture = try await ChoreFixture.make()
        let revealed = try await fixture.revealedSet(
            mine: [.hate, .hate, .hate, .hate, .hate, .hate, .fine, .fine],
            theirs: [.like, .like, .like, .like, .like, .like, .fine, .fine]
        )
        let shown = fixture.reveal(revealed).presentation

        XCTAssertEqual(shown.trades.count, ChoreSplitPresentation.maximumTrades)
    }

    func testApplyingTheSplitFillsTasksAndClosesTheSet() async throws {
        let fixture = try await ChoreFixture.make()
        let model = fixture.reveal(
            try await fixture.revealedSet(
                mine: [.hate, .fine, .like, .fine, .neutral, .fine, .fine, .fine],
                theirs: [.like, .fine, .hate, .fine, .fine, .neutral, .fine, .fine]
            )
        )

        await model.apply()

        XCTAssertEqual(model.choreSet.status, .applied)
        XCTAssertEqual(fixture.analytics.names, ["chore_applied"])
        let tasks = try await fixture.controller.repositories.tasks.tasks(TaskQuery(spaceId: fixture.space.id))
        XCTAssertEqual(tasks.count, 8)
        XCTAssertTrue(tasks.allSatisfy(\.comesFromChoreSplit))
        XCTAssertTrue(tasks.allSatisfy { $0.recurrence != Recurrence.none })
    }
}

@MainActor
final class ChoresViewModelTests: XCTestCase {
    func testStartingASplitFillsTheListFromTheCatalog() async throws {
        let fixture = try await ChoreFixture.make()
        let model = fixture.hub()
        await model.apply(fixture.context)
        XCTAssertEqual(model.state, .notStarted)

        await model.start()

        XCTAssertEqual(model.state, .building)
        XCTAssertEqual(model.openSet?.includedItems.count, ChoreCatalog.bundled.preselectedIds.count)
        XCTAssertEqual(fixture.analytics.names, ["chore_flow_started"])
    }

    func testASplitCanOnlyBeNudgedOncePerDay() async throws {
        let fixture = try await ChoreFixture.make()
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "corbie.tests.chores.\(UUID().uuidString)"))
        let morning = fixture.hub(defaults: defaults, at: fixture.now)

        XCTAssertTrue(morning.canNudge)
        XCTAssertTrue(morning.nudge())
        XCTAssertFalse(morning.canNudge)
        XCTAssertFalse(morning.nudge())

        let tomorrow = fixture.hub(defaults: defaults, at: fixture.now.addingTimeInterval(26 * 3600))
        XCTAssertTrue(tomorrow.canNudge)
    }

    func testASplitStartedAgainKeepsTheChoresYouChoseLastTime() async throws {
        let fixture = try await ChoreFixture.make()
        let revealed = try await fixture.revealedSet(
            mine: [.fine, .fine, .fine, .fine, .fine, .fine, .fine, .fine],
            theirs: [.fine, .fine, .fine, .fine, .fine, .fine, .fine, .fine]
        )
        _ = try await fixture.repository.apply(setId: revealed.id, memberId: fixture.me.id, at: fixture.now)
        let model = fixture.hub()
        await model.apply(fixture.context)
        XCTAssertEqual(model.state, .applied(fixture.now))

        await model.resplit()

        XCTAssertEqual(model.state, .building)
        let fresh = try XCTUnwrap(model.openSet)
        XCTAssertNotEqual(fresh.id, revealed.id)
        XCTAssertEqual(
            Set(fresh.includedItems.map(\.title)),
            Set(revealed.includedItems.map(\.title))
        )
        XCTAssertEqual(fixture.analytics.names, ["chore_resplit"])
    }
}

@MainActor
private struct ChoreFixture {
    let controller: PersistenceController
    let space: SpaceDTO
    let me: MemberDTO
    let partner: MemberDTO
    let analytics = ChoreAnalyticsLog()
    let now = Date(timeIntervalSince1970: 1_757_000_000)

    static let eightChores = ["c001", "c002", "c003", "c004", "c005", "c006", "c007", "c008"]

    static func make() async throws -> ChoreFixture {
        let controller = PersistenceController.inMemory()
        let repositories = controller.repositories
        let stamp = Date(timeIntervalSince1970: 1_757_000_000)
        let space = try await repositories.spaces.create(displayCurrency: "USD", creatorMemberId: nil, now: stamp)
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
        return ChoreFixture(controller: controller, space: space, me: me, partner: partner)
    }

    var repository: any ChoreRepository { controller.repositories.chores }

    var context: ChoresContext {
        ChoresContext(
            spaceId: space.id,
            memberId: me.id,
            partnerId: partner.id,
            partnerName: partner.displayName ?? ""
        )
    }

    func catalogItem(_ id: String) throws -> ChoreCatalogItem {
        try XCTUnwrap(ChoreCatalog.bundled.item(id: id), "the catalog has no chore \(id)")
    }

    func startSet(catalogIds: [String]) async throws -> ChoreSetDTO {
        try await repository.startSet(spaceId: space.id, catalogIds: catalogIds, memberId: me.id, at: now)
    }

    func ratingSet() async throws -> ChoreSetDTO {
        let built = try await startSet(catalogIds: ChoreFixture.eightChores)
        return try await repository.startRating(setId: built.id)
    }

    func revealedSet(mine: [ChoreVerdict], theirs: [ChoreVerdict]) async throws -> ChoreSetDTO {
        var latest = try await ratingSet()
        for (index, item) in latest.includedItems.enumerated() {
            latest = try await repository.rate(itemId: item.id, memberId: me.id, verdict: mine[index], at: now)
        }
        for (index, item) in latest.includedItems.enumerated() {
            latest = try await repository.rate(itemId: item.id, memberId: partner.id, verdict: theirs[index], at: now)
        }
        return try await repository.reveal(setId: latest.id, at: now)
    }

    func chores(in presentation: ChoreSplitPresentation, kind: ChoreShareKind) -> [String] {
        presentation.lists.first { $0.id == kind.rawValue }?.chores ?? []
    }

    func builder(_ set: ChoreSetDTO) -> ChoreListBuilderViewModel {
        ChoreListBuilderViewModel(
            set: set,
            repository: repository,
            memberId: me.id,
            analytics: analytics,
            locale: Locale(identifier: "en_US")
        )
    }

    func rating(_ set: ChoreSetDTO) -> ChoreRatingViewModel {
        let stamp = now
        return ChoreRatingViewModel(
            set: set,
            repository: repository,
            memberId: me.id,
            analytics: analytics,
            now: { stamp }
        )
    }

    func reveal(_ set: ChoreSetDTO) -> ChoreRevealViewModel {
        let stamp = now
        return ChoreRevealViewModel(
            set: set,
            repository: repository,
            context: context,
            analytics: analytics,
            now: { stamp }
        )
    }

    func hub(defaults: UserDefaults = .corbieShared, at moment: Date? = nil) -> ChoresViewModel {
        let stamp = moment ?? now
        return ChoresViewModel(
            repository: repository,
            analytics: analytics,
            defaults: defaults,
            now: { stamp }
        )
    }
}

private final class ChoreAnalyticsLog: AnalyticsRecording, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [String] = []

    var names: [String] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    func record(_ event: AnalyticsEvent) {
        lock.lock()
        recorded.append(event.name)
        lock.unlock()
    }
}
