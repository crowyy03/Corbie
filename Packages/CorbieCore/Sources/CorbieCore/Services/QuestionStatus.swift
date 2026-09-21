import Foundation

public enum QuestionProgress: Sendable, Codable, Equatable {
    case unanswered(partnerAnswered: Bool)
    case waitingForPartner
    case revealUnread
    case revealRead

    public var isCompact: Bool {
        if case .unanswered = self { return false }
        return true
    }
}

public struct QuestionStatus: Sendable, Codable, Equatable {
    public let progress: QuestionProgress
    public let isToday: Bool
    public let isPast: Bool

    public init(
        dayKey: String,
        todayKey: String,
        viewerAnswered: Bool,
        partnerAnswered: Bool,
        readDays: RevealReadDays
    ) {
        isToday = dayKey == todayKey
        isPast = dayKey < todayKey
        switch (viewerAnswered, partnerAnswered) {
        case (false, _):
            progress = .unanswered(partnerAnswered: partnerAnswered)
        case (true, false):
            progress = .waitingForPartner
        case (true, true):
            progress = readDays.hasRead(dayKey, today: todayKey) ? .revealRead : .revealUnread
        }
    }

    public init(question: DailyQuestionDTO, todayKey: String, viewer: MemberDTO?, partnerId: UUID?) {
        self.init(
            dayKey: question.dayKey,
            todayKey: todayKey,
            viewerAnswered: question.hasAnswered(viewer?.id),
            partnerAnswered: question.hasAnswered(partnerId),
            readDays: viewer?.revealReadDays ?? RevealReadDays()
        )
    }

    public var showsTodayDot: Bool { isToday && progress == .revealUnread }

    public var showsHistoryDot: Bool { isPast && progress == .revealUnread }

    public static func todayKey(now: Date, space: SpaceDTO) -> String {
        QuestionSelector.dayKey(for: now, timeZone: space.anchorCalendarTimeZone)
    }
}
