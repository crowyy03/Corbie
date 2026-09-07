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
            if let existing = CoreDataQuestionRepository.merged(dayKey: dayKey, in: space, context: context) {
                return DailyQuestionDTO(existing, viewerMemberId: viewerMemberId, memberCount: space.members.count)
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
            guard question.answers.contains(where: { $0.memberId == memberId }) == false else {
                throw CorbieError.invalidInput("this member already answered today")
            }
            let answer = QuestionAnswer(context: context)
            context.assign(answer, toStoreOf: question)
            answer.dailyQuestion = question
            answer.memberId = memberId
            answer.text = body
            answer.createdAt = date
            return DailyQuestionDTO(
                question,
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
            return DailyQuestionDTO(
                question,
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
            let dto = DailyQuestionDTO(question, viewerMemberId: memberId, memberCount: memberCount)
            guard dto.canNudge(as: memberId) else {
                throw CorbieError.invalidInput("there is nothing to nudge about today")
            }
            question.nudgedByMemberId = memberId
            question.nudgedAt = date
            return DailyQuestionDTO(question, viewerMemberId: memberId, memberCount: memberCount)
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
                sort: [NSSortDescriptor(key: "dayKey", ascending: false)],
                in: context
            )
            let all = questions.map {
                DailyQuestionDTO($0, viewerMemberId: viewerMemberId, memberCount: memberCount)
            }
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

    private static func cleaned(_ text: String) throws -> String {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard body.isEmpty == false else {
            throw CorbieError.invalidInput("an answer cannot be empty")
        }
        return String(body.prefix(QuestionAnswerDTO.maxLength))
    }

    private static func merged(dayKey: String, in space: Space, context: NSManagedObjectContext) -> DailyQuestion? {
        let sameDay = space.questions
            .filter { $0.dayKey == dayKey }
            .sorted { ($0.id?.uuidString ?? "") < ($1.id?.uuidString ?? "") }
        guard let keeper = sameDay.first else { return nil }
        for duplicate in sameDay.dropFirst() {
            for answer in duplicate.answers {
                let alreadyAnswered = keeper.answers.contains { $0.memberId == answer.memberId }
                if alreadyAnswered {
                    context.delete(answer)
                } else {
                    answer.dailyQuestion = keeper
                }
            }
            context.delete(duplicate)
        }
        context.processPendingChanges()
        return keeper
    }
}
