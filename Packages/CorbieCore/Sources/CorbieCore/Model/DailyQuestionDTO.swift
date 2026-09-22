import Foundation

public struct DailyQuestionDTO: Sendable, Codable, Identifiable, Equatable {
    public static let editWindow: TimeInterval = 24 * 60 * 60

    public let id: UUID
    public var spaceId: UUID?
    public var questionId: String
    public var dayKey: String
    public var nudgedByMemberId: UUID?
    public var nudgedAt: Date?
    public var createdAt: Date?
    public var answers: [QuestionAnswerDTO]
    public var isRevealed: Bool

    public init(
        id: UUID,
        spaceId: UUID? = nil,
        questionId: String = "",
        dayKey: String = "",
        nudgedByMemberId: UUID? = nil,
        nudgedAt: Date? = nil,
        createdAt: Date? = nil,
        answers: [QuestionAnswerDTO] = [],
        isRevealed: Bool = false
    ) {
        self.id = id
        self.spaceId = spaceId
        self.questionId = questionId
        self.dayKey = dayKey
        self.nudgedByMemberId = nudgedByMemberId
        self.nudgedAt = nudgedAt
        self.createdAt = createdAt
        self.answers = answers
        self.isRevealed = isRevealed
    }

    public init(_ question: DailyQuestion, viewerMemberId: UUID?, memberCount: Int) {
        self.init(
            question,
            answers: Array(question.answers),
            nudgedByMemberId: question.nudgedByMemberId,
            nudgedAt: question.nudgedAt,
            viewerMemberId: viewerMemberId,
            memberCount: memberCount
        )
    }

    init(
        _ question: DailyQuestion,
        answers: [QuestionAnswer],
        nudgedByMemberId: UUID?,
        nudgedAt: Date?,
        viewerMemberId: UUID?,
        memberCount: Int
    ) {
        let questionId = question.id ?? UUID()
        let answered = Set(answers.compactMap(\.memberId))
        let revealed = memberCount >= 2 && answered.count >= memberCount
        let ordered = answers.sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
        self.init(
            id: questionId,
            spaceId: question.space?.id,
            questionId: question.questionId ?? "",
            dayKey: question.dayKey ?? "",
            nudgedByMemberId: nudgedByMemberId,
            nudgedAt: nudgedAt,
            createdAt: question.createdAt,
            answers: ordered.map { answer in
                let isOwn = answer.memberId != nil && answer.memberId == viewerMemberId
                var dto = QuestionAnswerDTO(answer, hidingText: revealed == false && isOwn == false)
                dto.dailyQuestionId = questionId
                return dto
            },
            isRevealed: revealed
        )
    }

    public func answer(by memberId: UUID?) -> QuestionAnswerDTO? {
        guard let memberId else { return nil }
        return answers.first { $0.memberId == memberId }
    }

    public func hasAnswered(_ memberId: UUID?) -> Bool { answer(by: memberId) != nil }

    public func canEdit(_ answer: QuestionAnswerDTO, at date: Date) -> Bool {
        guard let createdAt = answer.createdAt else { return false }
        return date.timeIntervalSince(createdAt) <= DailyQuestionDTO.editWindow
    }

    public func canNudge(as memberId: UUID?) -> Bool {
        guard let memberId, isRevealed == false, hasAnswered(memberId) else { return false }
        return nudgedAt == nil || nudgedByMemberId != memberId
    }
}
