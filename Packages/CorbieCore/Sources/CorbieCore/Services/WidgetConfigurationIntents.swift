#if canImport(AppIntents)
import AppIntents
import Foundation

@available(iOS 17.0, macOS 14.0, *)
public struct CountdownConfigurationIntent: WidgetConfigurationIntent {
    public static let title: LocalizedStringResource = "intent.countdown.title"
    public static let description = IntentDescription("intent.countdown.description")
    public static let isDiscoverable = false

    @Parameter(title: "intent.countdown.parameter.source", default: CountdownSourceOption.anniversary)
    public var source: CountdownSourceOption

    @Parameter(title: "intent.countdown.parameter.event")
    public var event: CorbieEventEntity?

    public init() { }

    public init(source: CountdownSourceOption, event: CorbieEventEntity? = nil) {
        self.source = source
        self.event = event
    }

    public var countdownSource: CountdownSource? {
        switch source {
        case .anniversary:
            return .anniversary
        case .wedding:
            return .wedding
        case .partnerBirthday:
            return .partnerBirthday
        case .customEvent:
            return event.map { .customEvent($0.id) }
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
public struct PlanProgressConfigurationIntent: WidgetConfigurationIntent {
    public static let title: LocalizedStringResource = "intent.plan.title"
    public static let description = IntentDescription("intent.plan.description")
    public static let isDiscoverable = false

    @Parameter(title: "intent.plan.parameter.plan")
    public var plan: CorbiePlanEntity?

    public init() { }

    public init(plan: CorbiePlanEntity?) {
        self.plan = plan
    }

    public var planId: UUID? { plan?.id }
}

@available(iOS 17.0, macOS 14.0, *)
public struct LockCircularConfigurationIntent: WidgetConfigurationIntent {
    public static let title: LocalizedStringResource = "intent.lock.title"
    public static let description = IntentDescription("intent.lock.description")
    public static let isDiscoverable = false

    @Parameter(title: "intent.lock.parameter.mode", default: LockCircularModeOption.daysTogether)
    public var mode: LockCircularModeOption

    public init() { }

    public init(mode: LockCircularModeOption) {
        self.mode = mode
    }

    public var circularMode: LockCircularMode { mode.mode }
}
#endif
