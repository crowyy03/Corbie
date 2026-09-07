import Foundation
import Testing
@testable import CorbieCore

@Suite struct QuestionRepositoryTests {
    private let calendar = DomainClock.calendar(locale: "en_US", timeZone: "UTC")

    private func bank(_ count: Int) -> QuestionBank {
        QuestionBank(entries: (1...count).map { index in
            QuestionBankEntry(
                id: String(format: "q%04d", index),
                theme: .everyday,
                stage: .any,
                tone: .light,
                text: ["en": "What made you laugh today \(index)"]
            )
        })
    }

    private func world(anchor: String = "UTC") async throws -> (TestWorld, CoreDataQuestionRepository) {
        let world = try await TestWorld.make()
        var space = world.space
        space.anchorTimeZone = anchor
        space.togetherSince = DomainClock.date("2020-01-01", in: calendar)
        _ = try await world.repositories.spaces.update(space)
        let repository = CoreDataQuestionRepository(
            stack: world.controller.stack,
            bank: bank(30),
            locale: Locale(identifier: "en_US")
        )
        return (world, repository)
    }

    @Test func theFirstOpenOfTheDayCreatesTheQuestionAndTheSecondFindsIt() async throws {
        let (world, repository) = try await world()
        let now = DomainClock.date("2026-09-07 08:00", in: calendar)
        let first = try #require(try await repository.todaysQuestion(spaceId: world.space.id, now: now))
        #expect(first.dayKey == "2026-09-07")
        #expect(first.answers.isEmpty)
        let later = DomainClock.date("2026-09-07 23:00", in: calendar)
        let second = try #require(try await repository.todaysQuestion(spaceId: world.space.id, now: later))
        #expect(second.id == first.id)
        #expect(second.questionId == first.questionId)
        #expect(try world.count(DailyQuestion.entityName) == 1)
    }

    @Test func aNewDayBringsANewQuestion() async throws {
        let (world, repository) = try await world()
        let today = try #require(
            try await repository.todaysQuestion(
                spaceId: world.space.id,
                now: DomainClock.date("2026-09-07 08:00", in: calendar)
            )
        )
        let tomorrow = try #require(
            try await repository.todaysQuestion(
                spaceId: world.space.id,
                now: DomainClock.date("2026-09-08 08:00", in: calendar)
            )
        )
        #expect(tomorrow.dayKey == "2026-09-08")
        #expect(tomorrow.questionId != today.questionId)
        let space = try #require(try await world.repositories.spaces.space(id: world.space.id))
        #expect(space.questionIndex == 2)
        #expect(space.questionSeed != 0)
    }

    @Test func theAnchorZoneDecidesWhichDayItIs() async throws {
        let (world, repository) = try await world(anchor: "Europe/Moscow")
        let question = try #require(
            try await repository.todaysQuestion(
                spaceId: world.space.id,
                now: DomainClock.date("2026-09-07 22:30", in: calendar)
            )
        )
        #expect(question.dayKey == "2026-09-08")
    }

    @Test func theOtherAnswerStaysHiddenUntilYouHaveWrittenYourOwn() async throws {
        let (world, repository) = try await world()
        let now = DomainClock.date("2026-09-07 08:00", in: calendar)
        let question = try #require(try await repository.todaysQuestion(spaceId: world.space.id, now: now))
        let afterMine = try await repository.answer(
            dailyQuestionId: question.id,
            memberId: world.me.id,
            text: "A dog on the tram",
            at: now
        )
        #expect(afterMine.isRevealed == false)
        #expect(afterMine.answer(by: world.me.id)?.text == "A dog on the tram")

        let seenByPartner = try #require(
            try await repository.todaysQuestion(spaceId: world.space.id, viewerMemberId: world.partner.id, now: now)
        )
        #expect(seenByPartner.hasAnswered(world.me.id))
        #expect(seenByPartner.answer(by: world.me.id)?.isHidden == true)

        let afterBoth = try await repository.answer(
            dailyQuestionId: question.id,
            memberId: world.partner.id,
            text: "The bread we burned",
            at: now
        )
        #expect(afterBoth.isRevealed)
        #expect(afterBoth.answers.count == 2)
        #expect(afterBoth.answers.allSatisfy { $0.isHidden == false })
    }

    @Test func youAnswerOnceAndThenEditForADay() async throws {
        let (world, repository) = try await world()
        let now = DomainClock.date("2026-09-07 08:00", in: calendar)
        let question = try #require(try await repository.todaysQuestion(spaceId: world.space.id, now: now))
        let written = try await repository.answer(
            dailyQuestionId: question.id,
            memberId: world.me.id,
            text: "  A dog on the tram  ",
            at: now
        )
        let mine = try #require(written.answer(by: world.me.id))
        #expect(mine.text == "A dog on the tram")

        await #expect(throws: CorbieError.self) {
            _ = try await repository.answer(
                dailyQuestionId: question.id,
                memberId: world.me.id,
                text: "again",
                at: now
            )
        }
        await #expect(throws: CorbieError.self) {
            _ = try await repository.answer(
                dailyQuestionId: question.id,
                memberId: world.me.id,
                text: "   ",
                at: now
            )
        }

        let edited = try await repository.editAnswer(
            answerId: mine.id,
            text: "A dog riding the tram",
            at: DomainClock.date("2026-09-07 20:00", in: calendar)
        )
        #expect(edited.answer(by: world.me.id)?.text == "A dog riding the tram")
        #expect(edited.answer(by: world.me.id)?.isEdited == true)

        await #expect(throws: CorbieError.self) {
            _ = try await repository.editAnswer(
                answerId: mine.id,
                text: "too late",
                at: DomainClock.date("2026-09-09 09:00", in: calendar)
            )
        }
    }

    @Test func anAnswerIsCutToItsLimit() async throws {
        let (world, repository) = try await world()
        let now = DomainClock.date("2026-09-07 08:00", in: calendar)
        let question = try #require(try await repository.todaysQuestion(spaceId: world.space.id, now: now))
        let long = String(repeating: "a", count: QuestionAnswerDTO.maxLength + 40)
        let written = try await repository.answer(
            dailyQuestionId: question.id,
            memberId: world.me.id,
            text: long,
            at: now
        )
        #expect(written.answer(by: world.me.id)?.text?.count == QuestionAnswerDTO.maxLength)
    }

    @Test func youCanNudgeOnceAfterYouHaveAnswered() async throws {
        let (world, repository) = try await world()
        let now = DomainClock.date("2026-09-07 08:00", in: calendar)
        let question = try #require(try await repository.todaysQuestion(spaceId: world.space.id, now: now))

        await #expect(throws: CorbieError.self) {
            _ = try await repository.nudge(dailyQuestionId: question.id, memberId: world.me.id, at: now)
        }

        _ = try await repository.answer(
            dailyQuestionId: question.id,
            memberId: world.me.id,
            text: "A dog on the tram",
            at: now
        )
        let nudged = try await repository.nudge(dailyQuestionId: question.id, memberId: world.me.id, at: now)
        #expect(nudged.nudgedByMemberId == world.me.id)
        #expect(nudged.canNudge(as: world.me.id) == false)

        await #expect(throws: CorbieError.self) {
            _ = try await repository.nudge(dailyQuestionId: question.id, memberId: world.me.id, at: now)
        }
    }

    @Test func historyRunsBackwardsAndSearchesBothSides() async throws {
        let (world, repository) = try await world()
        for day in 5...7 {
            let now = DomainClock.date("2026-09-0\(day) 08:00", in: calendar)
            let question = try #require(try await repository.todaysQuestion(spaceId: world.space.id, now: now))
            _ = try await repository.answer(
                dailyQuestionId: question.id,
                memberId: world.me.id,
                text: day == 6 ? "The bread we burned" : "Nothing much",
                at: now
            )
        }
        let history = try await repository.history(spaceId: world.space.id, viewerMemberId: world.me.id)
        #expect(history.map(\.dayKey) == ["2026-09-07", "2026-09-06", "2026-09-05"])

        let found = try await repository.history(
            spaceId: world.space.id,
            viewerMemberId: world.me.id,
            search: "bread"
        )
        #expect(found.map(\.dayKey) == ["2026-09-06"])

        let byQuestion = try await repository.history(
            spaceId: world.space.id,
            viewerMemberId: world.me.id,
            search: "laugh"
        )
        #expect(byQuestion.count == 3)
    }

    @Test func historyKeepsTheOtherAnswerHiddenOnADayYouSkipped() async throws {
        let (world, repository) = try await world()
        let now = DomainClock.date("2026-09-07 08:00", in: calendar)
        let question = try #require(try await repository.todaysQuestion(spaceId: world.space.id, now: now))
        _ = try await repository.answer(
            dailyQuestionId: question.id,
            memberId: world.partner.id,
            text: "The bread we burned",
            at: now
        )
        let history = try await repository.history(spaceId: world.space.id, viewerMemberId: world.me.id)
        #expect(history.first?.isRevealed == false)
        #expect(history.first?.answers.first?.isHidden == true)
    }

    @Test func theBadgeRemembersTheDayYouLastLooked() async throws {
        let (world, repository) = try await world()
        let member = try await repository.markSeen(memberId: world.me.id, dayKey: "2026-09-07")
        #expect(member.lastQuestionSeenDayKey == "2026-09-07")
    }

    @Test func withoutABankThereIsNoQuestionAndNoCrash() async throws {
        let world = try await TestWorld.make()
        let repository = CoreDataQuestionRepository(stack: world.controller.stack, bank: QuestionBank(entries: []))
        let question = try await repository.todaysQuestion(
            spaceId: world.space.id,
            now: DomainClock.date("2026-09-07 08:00", in: calendar)
        )
        #expect(question == nil)
        #expect(try world.count(DailyQuestion.entityName) == 0)
    }
}
