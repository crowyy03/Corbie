import CorbieCore
import Foundation

struct QuestionCopy {
    private let bank: QuestionBank
    private let locale: Locale
    private let dayKeys: DateFormatter
    private let days: DateFormatter

    init(bank: QuestionBank = .bundled, locale: Locale = .current) {
        self.bank = bank
        self.locale = locale
        dayKeys = DateFormatter()
        dayKeys.locale = Locale(identifier: "en_US_POSIX")
        dayKeys.timeZone = TimeZone(identifier: "UTC")
        dayKeys.dateFormat = "yyyy-MM-dd"
        days = DateFormatter()
        days.locale = locale
        days.timeZone = TimeZone(identifier: "UTC")
        days.setLocalizedDateFormatFromTemplate("yMMMd")
    }

    func text(of question: DailyQuestionDTO) -> String? {
        guard let entry = bank.entry(id: question.questionId) else { return nil }
        let text = entry.text(for: locale)
        return text.isEmpty ? nil : text
    }

    func time(of date: Date?) -> String? {
        guard let date else { return nil }
        return date.formatted(.dateTime.locale(locale).hour().minute())
    }

    func day(of question: DailyQuestionDTO) -> String {
        guard let date = dayKeys.date(from: question.dayKey) else { return question.dayKey }
        return days.string(from: date)
    }
}
