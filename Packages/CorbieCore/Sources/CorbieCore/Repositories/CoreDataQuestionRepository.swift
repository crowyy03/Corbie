import CoreData
import Foundation

public struct CoreDataQuestionRepository: QuestionRepository {
    private let access: CoreDataAccess
    private let bank: QuestionBank
    private let locale: Locale

    public init(stack: CoreDataStack, bank: QuestionBank = .bundled, locale: Locale = .current) {
        access = CoreDataAccess(stack: stack)
        self.bank = bank
        self.locale = locale
    }

    public func todaysQuestion(spaceId: UUID, viewerMemberId: UUID?, now: Date) async throws -> DailyQuestionDTO? {
        let bank = bank
        return try await access.write { context in
            let space: Space = try ManagedFetch.require(Space.entityName, id: spaceId, in: context)
            let zone = TimeZone(identifier: space.anchorTimeZone ?? "") ?? .current
            let dayKey = QuestionSelector.dayKey(for: now, timeZone: zone)
            if let day = QuestionDayMerge(rows: space.questions.filter { $0.dayKey == dayKey }) {
                day.apply(deletingDuplicates: false, in: context)
                return day.dto(viewerMemberId: viewerMemberId, memberCount: space.members.count)
            }
            let seed = space.questionSeed == 0
                ? QuestionSelector.seed(forSpaceId: spaceId)
                : UInt64(bitPattern: space.questionSeed)
            guard let selection = QuestionSelector.selection(
                bank: bank,
                seed: seed,
                index: Int(space.questionIndex),
                togetherSince: space.togetherSince,
                now: now
            ) else { return nil }
            let question = DailyQuestion(context: context)
            context.assign(question, toStoreOf: space)
            question.space = space
            question.questionId = selection.questionId
            question.dayKey = dayKey
            question.createdAt = now
            space.questionSeed = Int64(bitPattern: seed)
            space.questionIndex = Int32(selection.nextIndex)
            return DailyQuestionDTO(question, viewerMemberId: viewerMemberId, memberCount: space.members.count)
        }
    }

    public func storedQuestion(spaceId: UUID, viewerMemberId: UUID?, now: Date) async throws -> DailyQuestionDTO? {
        try await access.read { context in
            guard let space: Space = try ManagedFetch.first(Space.entityName, id: spaceId, in: context) else {
                return nil
            }
            let zone = TimeZone(identifier: space.anchorTimeZone ?? "") ?? .current
            let dayKey = QuestionSelector.dayKey(for: now, timeZone: zone)
            let day = QuestionDayMerge(rows: space.questions.filter { $0.dayKey == dayKey })
            return day?.dto(viewerMemberId: viewerMemberId, memberCount: space.members.count)
        }
    }

    public func answer(
        dailyQuestionId: UUID,
        memberId: UUID,
        text: String,
        at date: Date
    ) async throws -> DailyQuestionDTO {
        let body = try CoreDataQuestionRepository.cleaned(text)
        return try await access.write { context in
            let question: DailyQuestion = try ManagedFetch.require(
                DailyQuestion.entityName,
                id: dailyQuestionId,
                in: context
            )
            let day = try CoreDataQuestionRepository.day(of: question)
            guard day.answers.contains(where: { $0.memberId == memberId }) == false else {
                throw CorbieError.invalidInput("this member already answered today")
            }
            let answer = QuestionAnswer(context: context)
            context.assign(answer, toStoreOf: day.canonical)
            answer.dailyQuestion = day.canonical
            answer.memberId = memberId
            answer.text = body
            answer.createdAt = date
            return try CoreDataQuestionRepository.day(of: day.canonical).dto(
                viewerMemberId: memberId,
                memberCount: question.space?.members.count ?? 0
            )
        }
    }

    public func editAnswer(answerId: UUID, text: String, at date: Date) async throws -> DailyQuestionDTO {
        let body = try CoreDataQuestionRepository.cleaned(text)
        return try await access.write { context in
            let answer: QuestionAnswer = try ManagedFetch.require(
                QuestionAnswer.entityName,
                id: answerId,
                in: context
            )
            guard let createdAt = answer.createdAt,
                  date.timeIntervalSince(createdAt) <= DailyQuestionDTO.editWindow else {
                throw CorbieError.invalidInput("an answer can be changed for a day after it was written")
            }
            answer.text = body
            answer.editedAt = date
            guard let question = answer.dailyQuestion else {
                throw CorbieError.notFound("DailyQuestion for answer \(answerId)")
            }
            return try CoreDataQuestionRepository.day(of: question).dto(
                viewerMemberId: answer.memberId,
                memberCount: question.space?.members.count ?? 0
            )
        }
    }

    public func nudge(dailyQuestionId: UUID, memberId: UUID, at date: Date) async throws -> DailyQuestionDTO {
        try await access.write { context in
            let question: DailyQuestion = try ManagedFetch.require(
                DailyQuestion.entityName,
                id: dailyQuestionId,
                in: context
            )
            let memberCount = question.space?.members.count ?? 0
            let day = try CoreDataQuestionRepository.day(of: question)
            guard day.dto(viewerMemberId: memberId, memberCount: memberCount).canNudge(as: memberId) else {
                throw CorbieError.invalidInput("there is nothing to nudge about today")
            }
            day.canonical.nudgedByMemberId = memberId
            day.canonical.nudgedAt = date
            return try CoreDataQuestionRepository.day(of: day.canonical).dto(
                viewerMemberId: memberId,
                memberCount: memberCount
            )
        }
    }

    public func history(spaceId: UUID, viewerMemberId: UUID?, search: String?) async throws -> [DailyQuestionDTO] {
        let bank = bank
        let locale = locale
        return try await access.read { context in
            let space: Space? = try ManagedFetch.first(Space.entityName, id: spaceId, in: context)
            let memberCount = space?.members.count ?? 0
            let questions: [DailyQuestion] = try ManagedFetch.all(
                DailyQuestion.entityName,
                predicate: ManagedFetch.spaceRelation(spaceId),
                in: context
            )
            let all = QuestionDayMerge.days(of: questions)
                .sorted { ($0.dayKey ?? "") > ($1.dayKey ?? "") }
                .map { $0.dto(viewerMemberId: viewerMemberId, memberCount: memberCount) }
            guard let needle = search?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                  needle.isEmpty == false else { return all }
            return all.filter { question in
                let questionText = bank.entry(id: question.questionId)?.text(for: locale) ?? ""
                if questionText.lowercased().contains(needle) { return true }
                return question.answers.contains { ($0.text ?? "").lowercased().contains(needle) }
            }
        }
    }

    public func markSeen(memberId: UUID, dayKey: String) async throws -> MemberDTO {
        try await access.write { context in
            let member: Member = try ManagedFetch.require(Member.entityName, id: memberId, in: context)
            member.lastQuestionSeenDayKey = dayKey
            return MemberDTO(member)
        }
    }

    public func markRevealRead(memberId: UUID, dayKey: String) async throws -> MemberDTO {
        try await access.write { context in
            let member: Member = try ManagedFetch.require(Member.entityName, id: memberId, in: context)
            let stored = member.revealReadDays
            let read = stored.adding(dayKey)
            if read != stored { member.revealReadDays = read }
            return MemberDTO(member)
        }
    }

    public func consolidateDuplicates(spaceId: UUID, now: Date) async throws -> QuestionConsolidation {
        do {
            let isPending = try await access.read { context in
                try CoreDataQuestionRepository.consolidationDays(spaceId: spaceId, now: now, in: context)
                    .contains { $0.day.needsWrite(deletingDuplicates: $0.deletesDuplicates) }
            }
            guard isPending else { return .nothing }
            let result = try await access.write { context in
                try CoreDataQuestionRepository.consolidate(spaceId: spaceId, now: now, in: context)
            }
            if result.rows > 0 {
                SyncLog.logger.notice(
                    "question consolidation merged \(result.rows, privacy: .public) rows over \(result.days, privacy: .public) days"
                )
            }
            return result
        } catch {
            SyncLog.logger.error("question consolidation failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    static func consolidate(spaceId: UUID, now: Date, in context: NSManagedObjectContext) throws -> QuestionConsolidation {
        var rows = 0
        var days = 0
        for (day, deletesDuplicates) in try consolidationDays(spaceId: spaceId, now: now, in: context)
        where day.needsWrite(deletingDuplicates: deletesDuplicates) {
            let folded = day.apply(deletingDuplicates: deletesDuplicates, in: context)
            rows += folded
            days += folded > 0 ? 1 : 0
        }
        return QuestionConsolidation(rows: rows, days: days)
    }

    private static func firstOpenDayKey(now: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        return QuestionSelector.dayKey(for: yesterday, timeZone: timeZone)
    }

    private static func consolidationDays(
        spaceId: UUID,
        now: Date,
        in context: NSManagedObjectContext
    ) throws -> [(day: QuestionDayMerge, deletesDuplicates: Bool)] {
        guard let space: Space = try ManagedFetch.first(Space.entityName, id: spaceId, in: context) else { return [] }
        let zone = TimeZone(identifier: space.anchorTimeZone ?? "") ?? .current
        let firstOpenDay = firstOpenDayKey(now: now, timeZone: zone)
        return QuestionDayMerge.days(of: space.questions).map { day in
            (day, day.dayKey.map { $0 < firstOpenDay } ?? false)
        }
    }

    private static func cleaned(_ text: String) throws -> String {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard body.isEmpty == false else {
            throw CorbieError.invalidInput("an answer cannot be empty")
        }
        return String(body.prefix(QuestionAnswerDTO.maxLength))
    }

    private static func day(of question: DailyQuestion) throws -> QuestionDayMerge {
        guard let day = QuestionDayMerge.day(of: question) else {
            throw CorbieError.notFound("DailyQuestion \(question.id?.uuidString ?? "")")
        }
        return day
    }
}
