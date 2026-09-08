import CorbieCore
import XCTest
@testable import Corbie

final class ChoreSplitStateTests: XCTestCase {
    private let viewerId = UUID()
    private let partnerId = UUID()
    private let now = Date(timeIntervalSince1970: 1_757_000_000)

    func testWithoutASetNothingHasStarted() {
        XCTAssertEqual(state(of: []), .notStarted)
    }

    func testAListStillBeingBuiltSaysSo() {
        XCTAssertEqual(state(of: [set(status: .building)]), .building)
    }

    func testTheStateNamesWhoeverStillHasToRate() {
        XCTAssertEqual(state(of: [set(status: .rating, rated: [])]), .yourTurnToRate)
        XCTAssertEqual(state(of: [set(status: .rating, rated: [partnerId])]), .yourTurnToRate)
        XCTAssertEqual(state(of: [set(status: .rating, rated: [viewerId])]), .waitingForPartner)
        XCTAssertEqual(state(of: [set(status: .rating, rated: [viewerId, partnerId])]), .readyToReveal)
    }

    func testASoloSpaceKeepsWaitingAfterYouAreDone() {
        let alone = ChoreSplitState.make(
            sets: [set(status: .rating, rated: [viewerId])],
            viewerMemberId: viewerId,
            partnerMemberId: nil,
            now: now
        )
        XCTAssertEqual(alone, .waitingForPartner)
    }

    func testOnlyRatingAndRevealWaitForTheViewer() {
        XCTAssertTrue(ChoreSplitState.yourTurnToRate.waitsForViewer)
        XCTAssertTrue(ChoreSplitState.readyToReveal.waitsForViewer)
        for other in [ChoreSplitState.notStarted, .building, .waitingForPartner, .revealed, .applied(now)] {
            XCTAssertFalse(other.waitsForViewer, "\(other)")
        }
    }

    func testASplitOlderThanSixMonthsAsksToBeRedone() {
        let applied = set(status: .applied, appliedAt: now)
        XCTAssertEqual(state(of: [applied]), .applied(now))

        let later = ChoreSplitState.make(
            sets: [applied],
            viewerMemberId: viewerId,
            partnerMemberId: partnerId,
            now: now.addingTimeInterval(ChoreSetDTO.resplitAfter)
        )
        XCTAssertEqual(later, .needsResplit(now))
    }

    func testTheNewestSetIsTheOneThatCounts() {
        let sets = [set(status: .building), set(status: .applied, appliedAt: now)]
        XCTAssertEqual(state(of: sets), .building)
    }

    private func state(of sets: [ChoreSetDTO]) -> ChoreSplitState {
        ChoreSplitState.make(sets: sets, viewerMemberId: viewerId, partnerMemberId: partnerId, now: now)
    }

    private func set(
        status: ChoreSetStatus,
        rated: [UUID] = [],
        appliedAt: Date? = nil
    ) -> ChoreSetDTO {
        ChoreSetDTO(
            id: UUID(),
            status: status,
            createdAt: now,
            appliedAt: appliedAt,
            items: (0 ..< ChoreSetDTO.minimumIncludedItems).map {
                ChoreItemDTO(id: UUID(), title: "chore \($0)", sortIndex: $0)
            },
            ratedMemberIds: rated
        )
    }
}

final class ChoreReminderPlannerTests: XCTestCase {
    private let viewerId = UUID()
    private let partnerId = UUID()

    func testThePartnerFinishingFirstEarnsANotice() throws {
        let plan = try XCTUnwrap(
            ChoreReminderPlanner.plan(
                sets: [set(rated: [partnerId])],
                viewerMemberId: viewerId,
                partnerMemberId: partnerId,
                partnerName: "Sofia",
                alreadyToldAbout: nil
            )
        )
        XCTAssertEqual(plan.partnerName, "Sofia")
    }

    func testNobodyIsToldTwiceAboutTheSameSplit() {
        let waiting = set(rated: [partnerId])
        XCTAssertNil(
            ChoreReminderPlanner.plan(
                sets: [waiting],
                viewerMemberId: viewerId,
                partnerMemberId: partnerId,
                partnerName: "Sofia",
                alreadyToldAbout: waiting.id.uuidString
            )
        )
    }

    func testThereIsNothingToSayWhileThePartnerIsStillRating() {
        XCTAssertNil(plan(for: [set(rated: [])]))
        XCTAssertNil(plan(for: [set(rated: [viewerId])]))
        XCTAssertNil(plan(for: [set(rated: [viewerId, partnerId])]))
        XCTAssertNil(plan(for: [set(status: .building, rated: [partnerId])]))
        XCTAssertNil(plan(for: []))
    }

    private func plan(for sets: [ChoreSetDTO]) -> ChoreReminderPlan? {
        ChoreReminderPlanner.plan(
            sets: sets,
            viewerMemberId: viewerId,
            partnerMemberId: partnerId,
            partnerName: "Sofia",
            alreadyToldAbout: nil
        )
    }

    private func set(status: ChoreSetStatus = .rating, rated: [UUID]) -> ChoreSetDTO {
        ChoreSetDTO(
            id: UUID(),
            status: status,
            items: (0 ..< ChoreSetDTO.minimumIncludedItems).map {
                ChoreItemDTO(id: UUID(), title: "chore \($0)", sortIndex: $0)
            },
            ratedMemberIds: rated
        )
    }
}

final class ChoreCopyTests: XCTestCase {
    private let copy = ChoreCopy(
        locale: Locale(identifier: "en_US"),
        calendar: Calendar(identifier: .gregorian)
    )

    func testEveryStateHasItsOwnLine() throws {
        let lines = [
            ChoreSplitState.notStarted,
            .building,
            .yourTurnToRate,
            .waitingForPartner,
            .readyToReveal,
            .revealed,
            .applied(Date(timeIntervalSince1970: 1_757_000_000)),
            .needsResplit(Date(timeIntervalSince1970: 1_757_000_000))
        ].map { copy.stateLine($0, partnerName: "Sofia") }

        XCTAssertEqual(Set(lines).count, lines.count)
        XCTAssertTrue(lines.allSatisfy { $0.isEmpty == false })
        XCTAssertTrue(try XCTUnwrap(lines.dropFirst(3).first).contains("Sofia"))
    }

    func testTheFourVerdictsReadDifferently() {
        let titles = ChoreVerdict.allCases.map(copy.verdictTitle)
        XCTAssertEqual(Set(titles).count, ChoreVerdict.allCases.count)
    }

    func testTheSixFrequenciesReadDifferently() {
        let names = ChoreFrequency.allCases.map(copy.frequency)
        XCTAssertEqual(Set(names).count, ChoreFrequency.allCases.count)
    }
}
