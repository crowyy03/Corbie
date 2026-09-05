import CorbieCore
import Foundation

enum VoteTemplate: String, CaseIterable, Identifiable {
    case food
    case watch
    case weekend
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .food: return String(localized: "votes.template.food")
        case .watch: return String(localized: "votes.template.watch")
        case .weekend: return String(localized: "votes.template.weekend")
        case .custom: return String(localized: "votes.template.custom")
        }
    }

    var question: String {
        switch self {
        case .food: return String(localized: "votes.template.food.question")
        case .watch: return String(localized: "votes.template.watch.question")
        case .weekend: return String(localized: "votes.template.weekend.question")
        case .custom: return ""
        }
    }

    var options: [String] {
        switch self {
        case .food:
            return [
                String(localized: "votes.template.food.option.out"),
                String(localized: "votes.template.food.option.delivery"),
                String(localized: "votes.template.food.option.home")
            ]
        case .watch:
            return [
                String(localized: "votes.template.watch.option.film"),
                String(localized: "votes.template.watch.option.series"),
                String(localized: "votes.template.watch.option.nothing")
            ]
        case .weekend:
            return [
                String(localized: "votes.template.weekend.option.away"),
                String(localized: "votes.template.weekend.option.home"),
                String(localized: "votes.template.weekend.option.friends")
            ]
        case .custom:
            return ["", ""]
        }
    }

    var mode: VoteMode {
        self == .food ? .multi : .single
    }
}
