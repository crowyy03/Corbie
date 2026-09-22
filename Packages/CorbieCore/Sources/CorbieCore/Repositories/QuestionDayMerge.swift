import CoreData
import Foundation

struct QuestionDayMerge {
    let canonical: DailyQuestion
    let duplicates: [DailyQuestion]
    let answers: [QuestionAnswer]
    let extraAnswers: [QuestionAnswer]
    let nudgedByMemberId: UUID?
    let nudgedAt: Date?

    init?(rows: some Sequence<DailyQuestion>) {
        let ordered = rows.sorted { QuestionDayMerge.key($0.id) < QuestionDayMerge.key($1.id) }
        guard let canonical = ordered.first else { return nil }
        self.canonical = canonical
        duplicates = Array(ordered.dropFirst())
        var kept: [QuestionAnswer] = []
        var extra: [QuestionAnswer] = []
        for sameMember in Dictionary(grouping: ordered.flatMap(\.answers), by: \.memberId).values {
            let ranked = sameMember.sorted(by: QuestionDayMerge.outranks)
            kept.append(contentsOf: ranked.prefix(1))
            extra.append(contentsOf: ranked.dropFirst())
        }
        answers = kept
        extraAnswers = extra
        let lastNudge = ordered.reduce(nil) { latest, row -> DailyQuestion? in
            guard let nudgedAt = row.nudgedAt else { return latest }
            guard let latest, let latestAt = latest.nudgedAt, latestAt >= nudgedAt else { return row }
            return latest
        }
        nudgedByMemberId = lastNudge?.nudgedByMemberId
        nudgedAt = lastNudge?.nudgedAt
    }

    static func day(of question: DailyQuestion) -> QuestionDayMerge? {
        guard let dayKey = question.dayKey, let space = question.space else {
            return QuestionDayMerge(rows: [question])
        }
        return QuestionDayMerge(rows: space.questions.filter { $0.dayKey == dayKey })
    }

    static func days(of questions: some Sequence<DailyQuestion>) -> [QuestionDayMerge] {
        var byDay: [String: [DailyQuestion]] = [:]
        var withoutDay: [[DailyQuestion]] = []
        for question in questions {
            if let dayKey = question.dayKey {
                byDay[dayKey, default: []].append(question)
            } else {
                withoutDay.append([question])
            }
        }
        return (Array(byDay.values) + withoutDay).compactMap { QuestionDayMerge(rows: $0) }
    }

    var dayKey: String? { canonical.dayKey }

    func dto(viewerMemberId: UUID?, memberCount: Int) -> DailyQuestionDTO {
        DailyQuestionDTO(
            canonical,
            answers: answers,
            nudgedByMemberId: nudgedByMemberId,
            nudgedAt: nudgedAt,
            viewerMemberId: viewerMemberId,
            memberCount: memberCount
        )
    }

    func needsWrite(deletingDuplicates: Bool) -> Bool {
        if deletingDuplicates, duplicates.isEmpty == false { return true }
        return extraAnswers.isEmpty == false
            || answers.contains { $0.dailyQuestion != canonical }
            || carriesNewerNudge
    }

    @discardableResult
    func apply(deletingDuplicates: Bool, in context: NSManagedObjectContext) -> Int {
        let folded = duplicates.filter { deletingDuplicates || $0.answers.isEmpty == false }.count
        for answer in extraAnswers {
            context.delete(answer)
        }
        for answer in answers where answer.dailyQuestion != canonical {
            answer.dailyQuestion = canonical
        }
        if carriesNewerNudge {
            canonical.nudgedByMemberId = nudgedByMemberId
            canonical.nudgedAt = nudgedAt
        }
        if deletingDuplicates {
            for duplicate in duplicates {
                context.delete(duplicate)
            }
        }
        context.processPendingChanges()
        return folded
    }

    private var carriesNewerNudge: Bool {
        guard nudgedAt != nil else { return false }
        return canonical.nudgedAt != nudgedAt || canonical.nudgedByMemberId != nudgedByMemberId
    }

    private static func outranks(_ first: QuestionAnswer, _ second: QuestionAnswer) -> Bool {
        let firstWritten = first.createdAt ?? .distantPast
        let secondWritten = second.createdAt ?? .distantPast
        if firstWritten != secondWritten {
            return firstWritten > secondWritten
        }
        return key(first.id) > key(second.id)
    }

    private static func key(_ id: UUID?) -> String {
        id?.uuidString ?? ""
    }
}
