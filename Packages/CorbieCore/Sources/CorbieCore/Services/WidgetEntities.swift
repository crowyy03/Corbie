#if canImport(AppIntents)
import AppIntents
import Foundation

@available(iOS 17.0, macOS 14.0, *)
public struct CorbieEventEntity: AppEntity, Identifiable, Sendable {
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "intent.entity.event.type")
    public static let defaultQuery = CorbieEventQuery()

    public let id: UUID
    public let title: String
    public let date: Date?

    public init(id: UUID, title: String, date: Date?) {
        self.id = id
        self.title = title
        self.date = date
    }

    public init(_ option: WidgetEventOption) {
        self.init(id: option.id, title: option.title, date: option.date)
    }

    public var displayRepresentation: DisplayRepresentation {
        guard let date else { return DisplayRepresentation(title: "\(title)") }
        return DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(date.formatted(.dateTime.day().month(.abbreviated).year()))"
        )
    }
}

@available(iOS 17.0, macOS 14.0, *)
public struct CorbieEventQuery: EntityQuery, Sendable {
    private let persistence: IntentPersistence

    public init() {
        self.init(persistence: .shared)
    }

    public init(persistence: IntentPersistence) {
        self.persistence = persistence
    }

    public func entities(for identifiers: [UUID]) async throws -> [CorbieEventEntity] {
        try await provider().eventOptions(ids: identifiers).map(CorbieEventEntity.init)
    }

    public func suggestedEntities() async throws -> [CorbieEventEntity] {
        try await provider().selectableEvents().map(CorbieEventEntity.init)
    }

    private func provider() -> WidgetDataProvider {
        WidgetDataProvider(controller: persistence.controller(), identity: persistence.identity())
    }
}

@available(iOS 17.0, macOS 14.0, *)
public struct CorbiePlanEntity: AppEntity, Identifiable, Sendable {
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "intent.entity.plan.type")
    public static let defaultQuery = CorbiePlanQuery()

    public let id: UUID
    public let title: String
    public let progress: Double

    public init(id: UUID, title: String, progress: Double) {
        self.id = id
        self.title = title
        self.progress = progress
    }

    public init(_ option: WidgetPlanOption) {
        self.init(id: option.id, title: option.title, progress: option.progress)
    }

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(Int((progress * 100).rounded()).formatted(.percent))"
        )
    }
}

@available(iOS 17.0, macOS 14.0, *)
public struct CorbiePlanQuery: EntityQuery, Sendable {
    private let persistence: IntentPersistence

    public init() {
        self.init(persistence: .shared)
    }

    public init(persistence: IntentPersistence) {
        self.persistence = persistence
    }

    public func entities(for identifiers: [UUID]) async throws -> [CorbiePlanEntity] {
        try await provider().planOptions(ids: identifiers).map(CorbiePlanEntity.init)
    }

    public func suggestedEntities() async throws -> [CorbiePlanEntity] {
        try await provider().selectablePlans().map(CorbiePlanEntity.init)
    }

    private func provider() -> WidgetDataProvider {
        WidgetDataProvider(controller: persistence.controller(), identity: persistence.identity())
    }
}

@available(iOS 17.0, macOS 14.0, *)
public enum CountdownSourceOption: String, AppEnum, Sendable {
    case anniversary
    case wedding
    case partnerBirthday
    case customEvent

    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "intent.countdown.source.type")

    public static let caseDisplayRepresentations: [CountdownSourceOption: DisplayRepresentation] = [
        .anniversary: DisplayRepresentation(title: "intent.countdown.source.anniversary"),
        .wedding: DisplayRepresentation(title: "intent.countdown.source.wedding"),
        .partnerBirthday: DisplayRepresentation(title: "intent.countdown.source.birthday"),
        .customEvent: DisplayRepresentation(title: "intent.countdown.source.event")
    ]
}

@available(iOS 17.0, macOS 14.0, *)
public enum LockCircularModeOption: String, AppEnum, Sendable {
    case daysTogether
    case planRing
    case countdown

    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "intent.lock.mode.type")

    public static let caseDisplayRepresentations: [LockCircularModeOption: DisplayRepresentation] = [
        .daysTogether: DisplayRepresentation(title: "intent.lock.mode.days"),
        .planRing: DisplayRepresentation(title: "intent.lock.mode.plan"),
        .countdown: DisplayRepresentation(title: "intent.lock.mode.countdown")
    ]

    public var mode: LockCircularMode {
        switch self {
        case .daysTogether: return .daysTogether
        case .planRing: return .planRing
        case .countdown: return .countdown
        }
    }
}
#endif
