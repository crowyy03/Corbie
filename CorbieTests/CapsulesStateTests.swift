import CorbieCore
import XCTest
@testable import Corbie

final class CapsulesStateTests: XCTestCase {
    private let author = UUID()
    private let recipient = UUID()
    private let now = Date(timeIntervalSince1970: 1_757_000_000)

    func testSealedForTheAuthorAndWaitingForTheRecipient() {
        let capsule = makeCapsule(opensAt: now.addingTimeInterval(86_400))
        XCTAssertEqual(CapsuleRowState.make(capsule: capsule, viewerMemberId: author, now: now), .sealed)
        XCTAssertEqual(CapsuleRowState.make(capsule: capsule, viewerMemberId: recipient, now: now), .waiting)
        XCTAssertEqual(CapsuleRowState.make(capsule: capsule, viewerMemberId: nil, now: now), .waiting)
    }

    func testReadyOnceTheDatePassesAndOpenedForWhoeverRead() {
        let capsule = makeCapsule(opensAt: now, openedByMemberIds: [recipient], openedAt: now)
        XCTAssertEqual(CapsuleRowState.make(capsule: capsule, viewerMemberId: recipient, now: now), .opened)
        XCTAssertEqual(CapsuleRowState.make(capsule: capsule, viewerMemberId: author, now: now), .ready)
    }

    func testTheAuthorLosesTheRightToEditOnTheOpeningDate() {
        let capsule = makeCapsule(opensAt: now)
        XCTAssertEqual(CapsuleRowState.make(capsule: capsule, viewerMemberId: author, now: now), .ready)
        XCTAssertFalse(capsule.isEditable(at: now))
        XCTAssertTrue(makeCapsule(opensAt: now.addingTimeInterval(60)).isEditable(at: now))
    }

    func testSectionsAndHighlighting() {
        XCTAssertEqual(CapsuleRowState.waiting.section, .coming)
        XCTAssertEqual(CapsuleRowState.sealed.section, .coming)
        XCTAssertEqual(CapsuleRowState.ready.section, .toOpen)
        XCTAssertEqual(CapsuleRowState.opened.section, .opened)
        XCTAssertTrue(CapsuleRowState.waiting.isHighlighted)
        XCTAssertTrue(CapsuleRowState.ready.isHighlighted)
        XCTAssertFalse(CapsuleRowState.sealed.isHighlighted)
        XCTAssertFalse(CapsuleRowState.opened.isHighlighted)
    }

    func testReadByBothNeedsTwoReaders() {
        XCTAssertFalse(makeCapsule(opensAt: now, openedByMemberIds: [recipient], openedAt: now).isReadByBoth)
        let both = makeCapsule(opensAt: now, openedByMemberIds: [recipient, author], openedAt: now)
        XCTAssertTrue(both.isReadByBoth)
    }

    func testTheRemainingCharactersKeyResolvesThroughTheCatalog() {
        let many = String(localized: "capsules.editor.body.left \(2)")
        XCTAssertNotEqual(many, "capsules.editor.body.left %lld")
        XCTAssertTrue(many.contains("2"), many)
        XCTAssertNotEqual(String(localized: "capsules.editor.body.left \(1)"), many)
    }

    private func makeCapsule(
        opensAt: Date,
        openedByMemberIds: [UUID] = [],
        openedAt: Date? = nil
    ) -> CapsuleDTO {
        CapsuleDTO(
            id: UUID(),
            authorMemberId: author,
            recipientMemberId: recipient,
            title: "First year",
            body: "See you on the other side",
            opensAt: opensAt,
            openedAt: openedAt,
            openedByMemberIds: openedByMemberIds
        )
    }
}
