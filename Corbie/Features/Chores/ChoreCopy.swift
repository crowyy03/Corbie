import CorbieCore
import Foundation

struct ChoreCopy {
    private let locale: Locale
    private let calendar: Calendar

    init(locale: Locale = .current, calendar: Calendar = .current) {
        self.locale = locale
        self.calendar = calendar
    }

    func stateLine(_ state: ChoreSplitState, partnerName: String) -> String {
        switch state {
        case .notStarted:
            return String(localized: "chore.state.notstarted")
        case .building:
            return String(localized: "chore.state.building")
        case .yourTurnToRate:
            return String(localized: "chore.state.yourturn")
        case .waitingForPartner:
            return String.localizedStringWithFormat(String(localized: "chore.state.waiting"), partnerName)
        case .readyToReveal:
            return String(localized: "chore.state.readytoreveal")
        case .revealed:
            return String(localized: "chore.state.revealed")
        case let .applied(date):
            return String.localizedStringWithFormat(String(localized: "chore.state.applied"), month(date))
        case .needsResplit:
            return String(localized: "chore.state.resplit")
        }
    }

    func verdictTitle(_ verdict: ChoreVerdict) -> String {
        switch verdict {
        case .hate: return String(localized: "chore.verdict.hate")
        case .neutral: return String(localized: "chore.verdict.neutral")
        case .fine: return String(localized: "chore.verdict.fine")
        case .like: return String(localized: "chore.verdict.like")
        }
    }

    func frequency(_ frequency: ChoreFrequency) -> String {
        switch frequency {
        case .daily: return String(localized: "chore.frequency.daily")
        case .fewTimesAWeek: return String(localized: "chore.frequency.fewtimesaweek")
        case .weekly: return String(localized: "chore.frequency.weekly")
        case .everyTwoWeeks: return String(localized: "chore.frequency.everytwoweeks")
        case .monthly: return String(localized: "chore.frequency.monthly")
        case .quarterly: return String(localized: "chore.frequency.quarterly")
        }
    }

    func progress(position: Int, total: Int) -> String {
        String.localizedStringWithFormat(String(localized: "chore.rating.progress"), position, total)
    }

    func month(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(locale: locale, calendar: calendar)
                .month(.wide)
                .year()
        )
    }

    func day(_ date: Date?) -> String {
        guard let date else { return "" }
        return date.formatted(
            Date.FormatStyle(locale: locale, calendar: calendar)
                .day()
                .month(.abbreviated)
                .year()
        )
    }

    func viewerVerdict(_ verdict: ChoreVerdict) -> String {
        switch verdict {
        case .hate: return String(localized: "chore.said.you.hate")
        case .neutral: return String(localized: "chore.said.you.neutral")
        case .fine: return String(localized: "chore.said.you.fine")
        case .like: return String(localized: "chore.said.you.like")
        }
    }

    func partnerVerdict(_ verdict: ChoreVerdict, name: String) -> String {
        let key: String.LocalizationValue
        switch verdict {
        case .hate: key = "chore.said.partner.hate"
        case .neutral: key = "chore.said.partner.neutral"
        case .fine: key = "chore.said.partner.fine"
        case .like: key = "chore.said.partner.like"
        }
        return String.localizedStringWithFormat(String(localized: key), name)
    }
}
