import CorbieCore
import XCTest
@testable import Corbie

final class PlanEditorEditsTests: XCTestCase {
    private let lisbonEnd = Date(timeIntervalSince1970: 1_800_000_000)

    private func lisbon() -> PlanDTO {
        PlanDTO(
            id: UUID(),
            title: "Lisbon",
            type: .trip,
            targetAmount: 2000,
            currency: "USD",
            savedAmount: 300,
            endAt: lisbonEnd,
            note: "window seats"
        )
    }

    @MainActor
    func testAnUntouchedEditorHandsBackTheLoadedPlan() {
        let loaded = lisbon()
        let model = PlanEditorViewModel(plan: loaded)

        XCTAssertEqual(model.updated(loaded), loaded)
        XCTAssertNil(model.editedSavedAmount)
    }

    @MainActor
    func testTheSavedFigureLeavesThroughItsOwnPath() {
        let loaded = lisbon()
        let model = PlanEditorViewModel(plan: loaded)
        model.title = "Lisbon in May"
        model.savedAmount = 450

        let edited = model.updated(loaded)

        XCTAssertEqual(edited.title, "Lisbon in May")
        XCTAssertEqual(edited.savedAmount, 300)
        XCTAssertEqual(edited.status, loaded.status)
        XCTAssertEqual(model.editedSavedAmount, 450)
    }

    @MainActor
    func testMovingOneDateWritesTheRangeTheFormShows() {
        let loaded = lisbon()
        let model = PlanEditorViewModel(plan: loaded)
        let later = lisbonEnd.addingTimeInterval(86_400)
        model.endAt = later

        let edited = model.updated(loaded)

        XCTAssertEqual(edited.startAt, lisbonEnd)
        XCTAssertEqual(edited.endAt, later)
        XCTAssertEqual(edited.targetAmount, 2000)
    }
}
