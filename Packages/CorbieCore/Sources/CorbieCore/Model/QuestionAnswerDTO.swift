import Foundation

public struct QuestionAnswerDTO: Sendable, Codable, Identifiable, Equatable {
    public static let maxLength = 500

    public let id: UUID
    public var dailyQuestionId: UUID?
    public var memberId: UUID?
    public var text: String?
    public var createdAt: Date?
    public var editedAt: Date?

    public init(
        id: UUID,
        dailyQuestionId: UUID? = nil,
        memberId: UUID? = nil,
        text: String? = nil,
        createdAt: Date? = nil,
        editedAt: Date? = nil
    ) {
        self.id = id
        self.dailyQuestionId = dailyQuestionId
        self.memberId = memberId
        self.text = text
        self.createdAt = createdAt
        self.editedAt = editedAt
    }

    public init(_ answer: QuestionAnswer, hidingText: Bool) {
        self.init(
            id: answer.id ?? UUID(),
            dailyQuestionId: answer.dailyQuestion?.id,
            memberId: answer.memberId,
            text: hidingText ? nil : answer.text,
            createdAt: answer.createdAt,
            editedAt: answer.editedAt
        )
    }

    public var isEdited: Bool { editedAt != nil }

    public var isHidden: Bool { text == nil }
}
