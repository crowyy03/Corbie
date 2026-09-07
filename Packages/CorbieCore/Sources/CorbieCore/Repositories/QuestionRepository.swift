import Foundation

public protocol QuestionRepository: Sendable {
    func todaysQuestion(spaceId: UUID, viewerMemberId: UUID?, now: Date) async throws -> DailyQuestionDTO?
    func answer(dailyQuestionId: UUID, memberId: UUID, text: String, at date: Date) async throws -> DailyQuestionDTO
    func editAnswer(answerId: UUID, text: String, at date: Date) async throws -> DailyQuestionDTO
    func nudge(dailyQuestionId: UUID, memberId: UUID, at date: Date) async throws -> DailyQuestionDTO
    func history(spaceId: UUID, viewerMemberId: UUID?, search: String?) async throws -> [DailyQuestionDTO]
    func markSeen(memberId: UUID, dayKey: String) async throws -> MemberDTO
}

extension QuestionRepository {
    public func todaysQuestion(spaceId: UUID, now: Date = Date()) async throws -> DailyQuestionDTO? {
        try await todaysQuestion(spaceId: spaceId, viewerMemberId: nil, now: now)
    }

    public func answer(dailyQuestionId: UUID, memberId: UUID, text: String) async throws -> DailyQuestionDTO {
        try await answer(dailyQuestionId: dailyQuestionId, memberId: memberId, text: text, at: Date())
    }

    public func editAnswer(answerId: UUID, text: String) async throws -> DailyQuestionDTO {
        try await editAnswer(answerId: answerId, text: text, at: Date())
    }

    public func history(spaceId: UUID, viewerMemberId: UUID? = nil) async throws -> [DailyQuestionDTO] {
        try await history(spaceId: spaceId, viewerMemberId: viewerMemberId, search: nil)
    }
}
