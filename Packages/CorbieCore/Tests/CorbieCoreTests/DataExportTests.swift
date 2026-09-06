import Foundation
import Testing
@testable import CorbieCore

@Suite struct DataExportTests {
    @Test func theExportCountsEverySpaceObjectAndSurvivesARoundTrip() async throws {
        let world = try await TestWorld.make()
        let repositories = world.repositories
        _ = try await repositories.tasks.create(TaskDraft(spaceId: world.space.id, title: "Book the table"))
        _ = try await repositories.tasks.create(
            TaskDraft(spaceId: world.space.id, title: "Pick up the keys", assigneeMemberId: world.me.id)
        )
        _ = try await repositories.wishes.create(
            WishDraft(spaceId: world.space.id, ownerMemberId: world.partner.id, title: "Headphones", price: 199)
        )
        let plan = try await repositories.plans.create(
            PlanDraft(spaceId: world.space.id, title: "Lisbon", targetAmount: 5000, currency: "USD")
        )
        _ = try await repositories.plans.addExpense(
            planId: plan.id,
            draft: PlanExpenseDraft(amount: 120, currency: "USD", addedByMemberId: world.me.id)
        )

        let export = DataExport(controller: world.controller)
        let document = try await export.document(spaceId: world.space.id)

        #expect(document.formatVersion == DataExportDocument.currentFormatVersion)
        #expect(document.members.count == 2)
        #expect(document.tasks.count == 2)
        #expect(document.wishes.count == 1)
        #expect(document.plans.count == 1)
        #expect(document.expenses.count == 1)
        #expect(document.entityCount == 8)

        let data = try await export.data(spaceId: world.space.id)
        let decoded = try DataExport.decoder().decode(DataExportDocument.self, from: data)
        #expect(decoded.entityCount == document.entityCount)
        #expect(decoded.space.id == document.space.id)
        #expect(decoded.tasks.map(\.id) == document.tasks.map(\.id))
        #expect(decoded.expenses.first?.amountInPlanCurrency == 120)
    }

    @Test func theExportWritesAJsonFileNamedAfterTheMoment() async throws {
        let world = try await TestWorld.make(withPartner: false)
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("corbie-export-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let moment = Date(timeIntervalSince1970: 1_757_000_000)

        let url = try await DataExport(controller: world.controller)
            .write(spaceId: world.space.id, to: directory, now: moment)

        #expect(url.lastPathComponent == DataExport.fileName(now: moment))
        #expect(url.pathExtension == "json")
        let payload = try Data(contentsOf: url)
        let object = try JSONSerialization.jsonObject(with: payload) as? [String: Any]
        #expect(object?["formatVersion"] as? Int == DataExportDocument.currentFormatVersion)
    }

    @Test func exportingAnUnknownSpaceFails() async throws {
        let world = try await TestWorld.make(withPartner: false)
        await #expect(throws: CorbieError.self) {
            _ = try await DataExport(controller: world.controller).document(spaceId: UUID())
        }
    }
}
