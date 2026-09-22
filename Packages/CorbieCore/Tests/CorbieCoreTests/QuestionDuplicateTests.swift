import CoreData
import Foundation
import Testing
@testable import CorbieCore

@Suite struct QuestionDuplicateTests {
    private static let lowId = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()
    private static let highId = UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF") ?? UUID()
    private static let openLowId = UUID(uuidString: "22222222-2222-2222-2222-222222222222") ?? UUID()
    private static let openHighId = UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE") ?? UUID()

    private let calendar = DomainClock.calendar(locale: "en_US", timeZone: "UTC")

    private struct Written: Sendable {
        let memberId: UUID
        let text: String
        let at: Date
    }

    @Test(arguments: [lowId, highId])
    func aReadSeesThePartnersAnswerAndNudgeOnTheOtherPhonesRow(partnerRowId: UUID) async throws {
        let (world, repository) = try await world()
        let now = date("2026-09-07 08:00")
        let mine = try #require(try await repository.todaysQuestion(spaceId: world.space.id, now: now))
        _ = try await repository.answer(dailyQuestionId: mine.id, memberId: world.me.id, text: "A dog on the tram", at: now)
        try await insertRow(
            id: partnerRowId,
            dayKey: "2026-09-07",
            answers: [Written(memberId: world.partner.id, text: "The bread we burned", at: date("2026-09-07 08:05"))],
            nudge: (world.partner.id, date("2026-09-07 08:06")),
            in: world
        )
        let canonicalId = partnerRowId == Self.lowId ? partnerRowId : mine.id

        let stored = try #require(
            try await repository.storedQuestion(spaceId: world.space.id, viewerMemberId: world.me.id, now: now)
        )
        #expect(stored.id == canonicalId)
        #expect(stored.isRevealed)
        #expect(stored.answer(by: world.partner.id)?.text == "The bread we burned")
        #expect(stored.answer(by: world.me.id)?.text == "A dog on the tram")
        #expect(stored.answers.allSatisfy { $0.dailyQuestionId == canonicalId })
        #expect(stored.nudgedByMemberId == world.partner.id)

        let history = try await repository.history(spaceId: world.space.id, viewerMemberId: world.me.id)
        #expect(history.map(\.id) == [canonicalId])
        #expect(history.first?.answers.count == 2)
        #expect(try world.count(DailyQuestion.entityName) == 2)

        await #expect(throws: CorbieError.self) {
            _ = try await repository.answer(
                dailyQuestionId: partnerRowId,
                memberId: world.me.id,
                text: "again",
                at: now
            )
        }
    }

    @Test func todaysWritePathMovesTheAnswersButKeepsTheOtherRowUntilTheDayIsOver() async throws {
        let (world, repository) = try await world()
        try await insertRow(id: Self.highId, dayKey: "2026-09-07", answers: [
            Written(memberId: world.partner.id, text: "The bread we burned", at: date("2026-09-07 08:05"))
        ], in: world)
        try await insertRow(id: Self.lowId, dayKey: "2026-09-07", answers: [], in: world)

        let today = try #require(
            try await repository.todaysQuestion(spaceId: world.space.id, viewerMemberId: world.me.id, now: date("2026-09-07 09:00"))
        )

        #expect(today.id == Self.lowId)
        #expect(today.hasAnswered(world.partner.id))
        #expect(try answerParents(in: world) == [Self.lowId])
        #expect(try world.count(DailyQuestion.entityName) == 2)
    }

    @Test func consolidationFoldsPastDaysAndOpenDaysAndIsIdempotent() async throws {
        let (world, repository, directory) = try await diskWorld()
        defer { try? FileManager.default.removeItem(at: directory) }
        try await insertRow(id: Self.lowId, dayKey: "2026-09-01", answers: [
            Written(memberId: world.me.id, text: "Soup", at: date("2026-09-01 08:00"))
        ], in: world)
        try await insertRow(id: Self.highId, dayKey: "2026-09-01", answers: [
            Written(memberId: world.partner.id, text: "Rain", at: date("2026-09-01 08:30"))
        ], in: world)
        let untouched = UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID()
        try await insertRow(id: untouched, dayKey: "2026-09-03", answers: [
            Written(memberId: world.me.id, text: "Tea", at: date("2026-09-03 08:00"))
        ], in: world)
        let openLow = Self.openLowId
        let openHigh = Self.openHighId
        try await insertRow(id: openLow, dayKey: "2026-09-07", answers: [], in: world)
        try await insertRow(id: openHigh, dayKey: "2026-09-07", answers: [
            Written(memberId: world.partner.id, text: "Maps", at: date("2026-09-07 07:00"))
        ], in: world)
        let now = date("2026-09-07 09:00")
        let before = try historyToken(in: world)

        let first = try await repository.consolidateDuplicates(spaceId: world.space.id, now: now)

        #expect(first == QuestionConsolidation(rows: 2, days: 2))
        #expect(try rowIds(in: world) == [Self.lowId, untouched, openLow, openHigh].sortedByString())
        #expect(try answerParents(in: world) == [Self.lowId, Self.lowId, untouched, openLow].sortedByString())
        let changed = try historyChanges(after: before, in: world)
        #expect(changed.count > 0)
        #expect(changed.liveIds.contains(untouched) == false)

        let afterFirst = try historyToken(in: world)
        let second = try await repository.consolidateDuplicates(spaceId: world.space.id, now: now)
        #expect(second == .nothing)
        #expect(try historyChanges(after: afterFirst, in: world).count == 0)

        let nextWeek = try await repository.consolidateDuplicates(spaceId: world.space.id, now: date("2026-09-14 09:00"))
        #expect(nextWeek == QuestionConsolidation(rows: 1, days: 1))
        #expect(try rowIds(in: world) == [Self.lowId, untouched, openLow].sortedByString())
        let history = try await repository.history(spaceId: world.space.id, viewerMemberId: world.me.id)
        #expect(history.map(\.dayKey) == ["2026-09-07", "2026-09-03", "2026-09-01"])
        #expect(history.first?.hasAnswered(world.partner.id) == true)
        #expect(history.last?.answers.count == 2)
    }

    @Test func consolidationKeepsOneAnswerPerMemberTheLatestOne() async throws {
        let (world, repository) = try await world()
        try await insertRow(id: Self.lowId, dayKey: "2026-09-01", answers: [
            Written(memberId: world.me.id, text: "Written again on the row I was shown", at: date("2026-09-01 09:00")),
            Written(memberId: world.partner.id, text: "Rain", at: date("2026-09-01 08:30"))
        ], in: world)
        try await insertRow(id: Self.highId, dayKey: "2026-09-01", answers: [
            Written(memberId: world.me.id, text: "First try on my own row", at: date("2026-09-01 08:00")),
            Written(memberId: world.partner.id, text: "Rain", at: date("2026-09-01 08:30"))
        ], in: world)

        let result = try await repository.consolidateDuplicates(spaceId: world.space.id, now: date("2026-09-07 09:00"))

        #expect(result == QuestionConsolidation(rows: 1, days: 1))
        let day = try #require(try await repository.history(spaceId: world.space.id, viewerMemberId: world.me.id).first)
        #expect(day.answers.count == 2)
        #expect(day.answer(by: world.me.id)?.text == "Written again on the row I was shown")
        #expect(day.answer(by: world.partner.id)?.text == "Rain")
        #expect(try world.count(QuestionAnswer.entityName) == 2)
    }

    @Test func twoContextsConsolidatingAtOnceConverge() async throws {
        let (world, _) = try await world()
        try await insertRow(id: Self.lowId, dayKey: "2026-09-01", answers: [
            Written(memberId: world.me.id, text: "Soup", at: date("2026-09-01 08:00"))
        ], in: world)
        try await insertRow(id: Self.highId, dayKey: "2026-09-01", answers: [
            Written(memberId: world.partner.id, text: "Rain", at: date("2026-09-01 08:30")),
            Written(memberId: world.me.id, text: "Soup again", at: date("2026-09-01 08:40"))
        ], in: world)
        try await insertRow(id: Self.openHighId, dayKey: "2026-09-07", answers: [
            Written(memberId: world.partner.id, text: "Maps", at: date("2026-09-07 07:00"))
        ], in: world)
        try await insertRow(id: Self.openLowId, dayKey: "2026-09-07", answers: [], in: world)
        let now = date("2026-09-07 09:00")
        let spaceId = world.space.id
        let phone = world.controller.stack.newBackgroundContext()
        let otherPhone = world.controller.stack.newBackgroundContext()

        let firstResult = try phone.performAndWait {
            try CoreDataQuestionRepository.consolidate(spaceId: spaceId, now: now, in: phone)
        }
        let secondResult = try otherPhone.performAndWait {
            try CoreDataQuestionRepository.consolidate(spaceId: spaceId, now: now, in: otherPhone)
        }
        try phone.performAndWait { try phone.save() }
        try otherPhone.performAndWait { try otherPhone.save() }

        #expect(firstResult == secondResult)
        #expect(try rowIds(in: world) == [Self.lowId, Self.openLowId, Self.openHighId].sortedByString())
        #expect(try answerParents(in: world) == [Self.lowId, Self.lowId, Self.openLowId].sortedByString())
        let repository = CoreDataQuestionRepository(stack: world.controller.stack, bank: bank())
        let history = try await repository.history(spaceId: spaceId, viewerMemberId: world.me.id)
        #expect(history.first(where: { $0.dayKey == "2026-09-01" })?.answer(by: world.me.id)?.text == "Soup again")
        #expect(history.first(where: { $0.dayKey == "2026-09-01" })?.answer(by: world.partner.id)?.text == "Rain")
        #expect(try await repository.consolidateDuplicates(spaceId: spaceId, now: now) == .nothing)
    }

    private func world() async throws -> (TestWorld, CoreDataQuestionRepository) {
        let world = try await TestWorld.make()
        try await anchor(world.space, in: world.controller)
        return (world, CoreDataQuestionRepository(stack: world.controller.stack, bank: bank()))
    }

    private func diskWorld() async throws -> (TestWorld, CoreDataQuestionRepository, URL) {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("corbie-questions-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let controller = PersistenceController(stack: CoreDataStack(storesIn: directory))
        let repositories = controller.repositories
        let space = try await repositories.spaces.create(displayCurrency: "USD")
        let me = try await repositories.members.upsertCurrentMember(
            appleUserId: "apple-me",
            spaceId: space.id,
            draft: MemberDraft(displayName: "Ilya", colorKey: MemberColorSlot.creatorDefault.rawValue),
            theme: .sand
        ).member
        let partner = try await repositories.members.upsertCurrentMember(
            appleUserId: "apple-partner",
            spaceId: space.id,
            draft: MemberDraft(displayName: "Sofia", colorKey: MemberColorSlot.partnerDefault.rawValue),
            theme: .sand
        ).member
        try await anchor(space, in: controller)
        let world = TestWorld(controller: controller, space: space, me: me, partner: partner)
        return (world, CoreDataQuestionRepository(stack: controller.stack, bank: bank()), directory)
    }

    private func anchor(_ space: SpaceDTO, in controller: PersistenceController) async throws {
        var anchored = space
        anchored.anchorTimeZone = "UTC"
        anchored.togetherSince = date("2020-01-01")
        try await OtherContext.overwrite(anchored, in: controller)
    }

    private func bank() -> QuestionBank {
        QuestionBank(entries: (1...30).map { index in
            QuestionBankEntry(
                id: String(format: "q%04d", index),
                theme: .everyday,
                stage: .any,
                tone: .light,
                text: ["en": "What made you laugh today \(index)"]
            )
        })
    }

    private func date(_ value: String) -> Date {
        DomainClock.date(value, in: calendar)
    }

    private func insertRow(
        id: UUID,
        dayKey: String,
        answers: [Written],
        nudge: (UUID, Date)? = nil,
        in world: TestWorld
    ) async throws {
        let spaceId = world.space.id
        let nudgedBy = nudge?.0
        let nudgedAt = nudge?.1
        let context = world.controller.stack.newBackgroundContext()
        try await context.perform {
            let space: Space = try ManagedFetch.require(Space.entityName, id: spaceId, in: context)
            let question = DailyQuestion(context: context)
            context.assign(question, toStoreOf: space)
            question.id = id
            question.space = space
            question.questionId = "q0001"
            question.dayKey = dayKey
            question.nudgedByMemberId = nudgedBy
            question.nudgedAt = nudgedAt
            for written in answers {
                let answer = QuestionAnswer(context: context)
                context.assign(answer, toStoreOf: space)
                answer.dailyQuestion = question
                answer.memberId = written.memberId
                answer.text = written.text
                answer.createdAt = written.at
            }
            try context.save()
        }
    }

    private func rowIds(in world: TestWorld) throws -> [UUID] {
        let context = world.controller.stack.newBackgroundContext()
        return try context.performAndWait {
            let rows: [DailyQuestion] = try ManagedFetch.all(DailyQuestion.entityName, in: context)
            return rows.compactMap(\.id).sortedByString()
        }
    }

    private func answerParents(in world: TestWorld) throws -> [UUID] {
        let context = world.controller.stack.newBackgroundContext()
        return try context.performAndWait {
            let answers: [QuestionAnswer] = try ManagedFetch.all(QuestionAnswer.entityName, in: context)
            return answers.compactMap { $0.dailyQuestion?.id }.sortedByString()
        }
    }

    private func historyToken(in world: TestWorld) throws -> NSPersistentHistoryToken? {
        world.controller.stack.container.persistentStoreCoordinator.currentPersistentHistoryToken(fromStores: nil)
    }

    private func historyChanges(
        after token: NSPersistentHistoryToken?,
        in world: TestWorld
    ) throws -> (count: Int, liveIds: Set<UUID>) {
        let context = world.controller.stack.newBackgroundContext()
        return try context.performAndWait {
            let result = try context.execute(NSPersistentHistoryChangeRequest.fetchHistory(after: token))
            let transactions = (result as? NSPersistentHistoryResult)?.result as? [NSPersistentHistoryTransaction] ?? []
            let changes = transactions.flatMap { $0.changes ?? [] }
            let liveIds = changes.compactMap { change -> UUID? in
                switch try? context.existingObject(with: change.changedObjectID) {
                case let question as DailyQuestion: return question.id
                case let answer as QuestionAnswer: return answer.id
                default: return nil
                }
            }
            return (changes.count, Set(liveIds))
        }
    }
}

private extension Array where Element == UUID {
    func sortedByString() -> [UUID] {
        sorted { $0.uuidString < $1.uuidString }
    }
}
