import Foundation
import Testing
@testable import CorbieCore

@Suite struct DomainQuestionSelectorTests {
    private func bank(_ count: Int, stage: QuestionStage = .any) -> QuestionBank {
        QuestionBank(entries: (1...count).map { index in
            QuestionBankEntry(
                id: String(format: "q%04d", index),
                theme: .everyday,
                stage: stage,
                tone: .light,
                text: ["en": "Question \(index)"]
            )
        })
    }

    private func run(_ bank: QuestionBank, days: Int, seed: UInt64, togetherSince: Date? = nil) -> [String] {
        var index = 0
        var shown: [String] = []
        for day in 0..<days {
            let now = Date(timeIntervalSince1970: TimeInterval(day) * 86_400)
            guard let selection = QuestionSelector.selection(
                bank: bank,
                seed: seed,
                index: index,
                togetherSince: togetherSince,
                now: now
            ) else { continue }
            shown.append(selection.questionId)
            index = selection.nextIndex
        }
        return shown
    }

    @Test func bothPartnersReadTheSameDayFromTheSpaceAnchorZone() throws {
        let moment = Date(timeIntervalSince1970: 1_788_818_400)
        let anchor = try #require(TimeZone(identifier: "Europe/Moscow"))
        #expect(QuestionSelector.dayKey(for: moment, timeZone: anchor) == "2026-09-08")
        let newYork = try #require(TimeZone(identifier: "America/New_York"))
        #expect(QuestionSelector.dayKey(for: moment, timeZone: newYork) == "2026-09-07")
    }

    @Test func theSeedComesFromTheSpaceIdAndNeverChanges() {
        let spaceId = UUID(uuidString: "5F1E4A1E-0D5F-4E0E-9A54-1A5C1A2B3C4D") ?? UUID()
        let seed = QuestionSelector.seed(forSpaceId: spaceId)
        #expect(QuestionSelector.seed(forSpaceId: spaceId) == seed)
        #expect(QuestionSelector.seed(forSpaceId: UUID()) != seed)
    }

    @Test func theOrderIsAShuffleThatKeepsEveryQuestion() {
        let ids = bank(50).questionIds
        let ordered = QuestionSelector.order(ids, seed: 12_345)
        #expect(Set(ordered) == Set(ids))
        #expect(ordered.count == ids.count)
        #expect(ordered != ids)
        #expect(QuestionSelector.order(ids, seed: 12_345) == ordered)
        #expect(QuestionSelector.order(ids, seed: 12_346) != ordered)
    }

    @Test func aMonthOfDaysBringsAMonthOfDifferentQuestions() {
        let shown = run(bank(1000), days: 30, seed: 99)
        #expect(shown.count == 30)
        #expect(Set(shown).count == 30)
    }

    @Test func nothingRepeatsUntilTheWholeBankIsUsed() {
        let shown = run(bank(40), days: 41, seed: 7)
        #expect(Set(shown.prefix(40)).count == 40)
        #expect(shown[40] == shown[0])
    }

    @Test func aYoungCoupleNeverSeesTheLaterStages() {
        let entries = (1...20).map { index -> QuestionBankEntry in
            QuestionBankEntry(
                id: String(format: "q%04d", index),
                theme: .everyday,
                stage: index.isMultiple(of: 2) ? .twoYears : .any,
                tone: .light,
                text: ["en": "Question \(index)"]
            )
        }
        let together = Date(timeIntervalSince1970: 0)
        let shown = run(QuestionBank(entries: entries), days: 10, seed: 3, togetherSince: together)
        let staged = Set(entries.filter { $0.stage == .twoYears }.map(\.id))
        #expect(shown.contains { staged.contains($0) } == false)
        #expect(shown.count == 10)
    }

    @Test func aStageOnlyOpensOnceTheCoupleIsOldEnough() {
        let now = Date(timeIntervalSince1970: 1_788_818_400)
        let calendar = Calendar.utc
        let sevenMonths = calendar.date(byAdding: .month, value: -7, to: now)
        #expect(QuestionStage.sixMonths.suits(togetherSince: sevenMonths, now: now))
        #expect(QuestionStage.twoYears.suits(togetherSince: sevenMonths, now: now) == false)
        #expect(QuestionStage.any.suits(togetherSince: nil, now: now))
        #expect(QuestionStage.sixMonths.suits(togetherSince: nil, now: now) == false)
    }

    @Test func anEmptyBankAsksNothing() {
        #expect(
            QuestionSelector.selection(
                bank: QuestionBank(entries: []),
                seed: 1,
                index: 0,
                togetherSince: nil,
                now: Date()
            ) == nil
        )
    }

    @Test func aBankWithNothingForThisStageAsksNothing() {
        let selection = QuestionSelector.selection(
            bank: bank(5, stage: .twoYears),
            seed: 1,
            index: 0,
            togetherSince: nil,
            now: Date()
        )
        #expect(selection == nil)
    }
}
