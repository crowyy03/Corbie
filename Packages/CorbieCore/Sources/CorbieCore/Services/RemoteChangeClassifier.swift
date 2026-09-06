import Foundation

public enum RemoteChangeKind: String, Sendable, Equatable, CaseIterable {
    case taskAssigned
    case taskHandover
    case partnerWish
    case planUpdate
    case capsuleOpened
    case voteUpdate

    public var prefix: String { "corbie.remote." + rawValue + "." }

    public func isEnabled(in prefs: NotificationPrefs) -> Bool {
        switch self {
        case .taskAssigned: return prefs.taskAssigned
        case .taskHandover: return prefs.taskTakenOrHandedBack
        case .partnerWish: return prefs.partnerAddedWish
        case .planUpdate: return prefs.planUpdates
        case .capsuleOpened: return prefs.capsuleUpdates
        case .voteUpdate: return prefs.voteUpdates
        }
    }
}

public enum RemoteChangeProperty {
    public static let taskAssignee = "assigneeMemberId"
    public static let planSaved = "savedAmount"
    public static let planTarget = "targetAmount"
    public static let voteRevealed = "revealedAt"
}

public enum RemoteChangeSubject: Sendable, Equatable {
    case task(TaskDTO)
    case wish(WishDTO)
    case plan(PlanDTO)
    case expense(PlanExpenseDTO, plan: PlanDTO?)
    case capsuleOpen(capsule: CapsuleDTO, memberId: UUID?)
    case vote(VoteDTO)
}

public struct RemoteChange: Sendable, Equatable {
    public let type: RemoteChangeType
    public let properties: Set<String>
    public let subject: RemoteChangeSubject

    public init(type: RemoteChangeType, properties: Set<String> = [], subject: RemoteChangeSubject) {
        self.type = type
        self.properties = properties
        self.subject = subject
    }
}

public struct RemoteChangeViewer: Sendable, Equatable {
    public var memberId: UUID?
    public var partnerId: UUID?
    public var partnerName: String

    public init(memberId: UUID? = nil, partnerId: UUID? = nil, partnerName: String = "") {
        self.memberId = memberId
        self.partnerId = partnerId
        self.partnerName = partnerName
    }
}

public struct RemoteChangeAlert: Sendable, Equatable, Identifiable {
    public let id: String
    public let kind: RemoteChangeKind
    public let content: CorbieNotificationContent

    public init(id: String, kind: RemoteChangeKind, content: CorbieNotificationContent) {
        self.id = id
        self.kind = kind
        self.content = content
    }
}

public enum RemoteChangeClassifier {
    public static func alerts(for changes: [RemoteChange], viewer: RemoteChangeViewer) -> [RemoteChangeAlert] {
        var seen = Set<String>()
        return changes
            .compactMap { alert(for: $0, viewer: viewer) }
            .filter { seen.insert($0.id).inserted }
    }

    public static func alert(for change: RemoteChange, viewer: RemoteChangeViewer) -> RemoteChangeAlert? {
        switch change.subject {
        case let .task(task):
            return taskAlert(task, change: change, viewer: viewer)
        case let .wish(wish):
            return wishAlert(wish, change: change, viewer: viewer)
        case let .plan(plan):
            return planAlert(plan, change: change)
        case let .expense(expense, plan):
            return expenseAlert(expense, plan: plan, change: change, viewer: viewer)
        case let .capsuleOpen(capsule, memberId):
            return capsuleAlert(capsule, openedBy: memberId, change: change, viewer: viewer)
        case let .vote(vote):
            return voteAlert(vote, change: change, viewer: viewer)
        }
    }

    private static func taskAlert(
        _ task: TaskDTO,
        change: RemoteChange,
        viewer: RemoteChangeViewer
    ) -> RemoteChangeAlert? {
        guard task.isDone == false, task.archivedAt == nil, let me = viewer.memberId else { return nil }
        let touchedAssignee = change.properties.contains(RemoteChangeProperty.taskAssignee)
        switch change.type {
        case .insert:
            guard task.assigneeMemberId == me, task.createdByMemberId != me else { return nil }
            return assignedAlert(task, viewer: viewer)
        case .update:
            guard touchedAssignee else { return nil }
            if task.assigneeMemberId == me { return assignedAlert(task, viewer: viewer) }
            return handoverAlert(task, viewer: viewer)
        case .delete:
            return nil
        }
    }

    private static func assignedAlert(_ task: TaskDTO, viewer: RemoteChangeViewer) -> RemoteChangeAlert {
        RemoteChangeAlert(
            id: RemoteChangeKind.taskAssigned.prefix + task.id.uuidString,
            kind: .taskAssigned,
            content: CorbieNotificationContent(
                titleKey: NotificationStrings.taskAssignedTitle,
                bodyKey: NotificationStrings.taskAssignedBody,
                arguments: [viewer.partnerName, task.title],
                categoryIdentifier: NotificationCategories.task,
                threadIdentifier: RemoteChangeKind.taskAssigned.rawValue,
                userInfo: NotificationPayload.userInfo(
                    remote: .taskAssigned,
                    route: .task(task.id),
                    objectId: task.id
                )
            )
        )
    }

    private static func handoverAlert(_ task: TaskDTO, viewer: RemoteChangeViewer) -> RemoteChangeAlert? {
        let isFree = task.assigneeMemberId == nil
        if isFree == false, let partnerId = viewer.partnerId, task.assigneeMemberId != partnerId { return nil }
        return RemoteChangeAlert(
            id: RemoteChangeKind.taskHandover.prefix + task.id.uuidString,
            kind: .taskHandover,
            content: CorbieNotificationContent(
                titleKey: isFree ? NotificationStrings.taskHandedBackTitle : NotificationStrings.taskTakenTitle,
                bodyKey: isFree ? NotificationStrings.taskHandedBackBody : NotificationStrings.taskTakenBody,
                arguments: [viewer.partnerName, task.title],
                categoryIdentifier: isFree ? NotificationCategories.task : nil,
                threadIdentifier: RemoteChangeKind.taskHandover.rawValue,
                userInfo: NotificationPayload.userInfo(
                    remote: .taskHandover,
                    route: .task(task.id),
                    objectId: task.id
                )
            )
        )
    }

    private static func wishAlert(
        _ wish: WishDTO,
        change: RemoteChange,
        viewer: RemoteChangeViewer
    ) -> RemoteChangeAlert? {
        guard change.type == .insert, wish.isFulfilled == false else { return nil }
        guard let me = viewer.memberId, wish.addedByMemberId != me else { return nil }
        return RemoteChangeAlert(
            id: RemoteChangeKind.partnerWish.prefix + wish.id.uuidString,
            kind: .partnerWish,
            content: CorbieNotificationContent(
                titleKey: NotificationStrings.wishAddedTitle,
                bodyKey: NotificationStrings.wishAddedBody,
                arguments: [viewer.partnerName, wish.title],
                threadIdentifier: RemoteChangeKind.partnerWish.rawValue,
                userInfo: NotificationPayload.userInfo(
                    remote: .partnerWish,
                    route: .wishes,
                    objectId: wish.id
                )
            )
        )
    }

    private static func planAlert(_ plan: PlanDTO, change: RemoteChange) -> RemoteChangeAlert? {
        guard change.type == .update else { return nil }
        let touchedMoney = change.properties.contains(RemoteChangeProperty.planSaved)
            || change.properties.contains(RemoteChangeProperty.planTarget)
        guard touchedMoney, plan.targetAmount > 0, plan.totalSavedAmount >= plan.targetAmount else { return nil }
        return RemoteChangeAlert(
            id: RemoteChangeKind.planUpdate.prefix + "plan." + plan.id.uuidString,
            kind: .planUpdate,
            content: CorbieNotificationContent(
                titleKey: NotificationStrings.planGoalTitle,
                bodyKey: NotificationStrings.planGoalBody,
                arguments: [plan.title],
                threadIdentifier: RemoteChangeKind.planUpdate.rawValue,
                userInfo: NotificationPayload.userInfo(
                    remote: .planUpdate,
                    route: .plan(plan.id),
                    objectId: plan.id
                )
            )
        )
    }

    private static func expenseCopy(plan: PlanDTO?) -> (title: String, body: String) {
        guard let plan, plan.targetAmount > 0 else {
            return (NotificationStrings.planExpenseTitle, NotificationStrings.planExpenseBody)
        }
        if plan.isOverspent {
            return (NotificationStrings.planOverTitle, NotificationStrings.planOverBody)
        }
        if plan.totalSavedAmount >= plan.targetAmount {
            return (NotificationStrings.planGoalTitle, NotificationStrings.planGoalBody)
        }
        return (NotificationStrings.planExpenseTitle, NotificationStrings.planExpenseBody)
    }

    private static func expenseAlert(
        _ expense: PlanExpenseDTO,
        plan: PlanDTO?,
        change: RemoteChange,
        viewer: RemoteChangeViewer
    ) -> RemoteChangeAlert? {
        guard change.type == .insert else { return nil }
        guard let me = viewer.memberId, expense.addedByMemberId != me else { return nil }
        let copy = expenseCopy(plan: plan)
        return RemoteChangeAlert(
            id: RemoteChangeKind.planUpdate.prefix + expense.id.uuidString,
            kind: .planUpdate,
            content: CorbieNotificationContent(
                titleKey: copy.title,
                bodyKey: copy.body,
                arguments: [viewer.partnerName, plan?.title ?? ""],
                threadIdentifier: RemoteChangeKind.planUpdate.rawValue,
                userInfo: NotificationPayload.userInfo(
                    remote: .planUpdate,
                    route: plan.map { CorbieRoute.plan($0.id) } ?? .plans,
                    objectId: plan?.id
                )
            )
        )
    }

    private static func capsuleAlert(
        _ capsule: CapsuleDTO,
        openedBy memberId: UUID?,
        change: RemoteChange,
        viewer: RemoteChangeViewer
    ) -> RemoteChangeAlert? {
        guard change.type == .insert, let opener = memberId, let me = viewer.memberId, opener != me else {
            return nil
        }
        return RemoteChangeAlert(
            id: RemoteChangeKind.capsuleOpened.prefix + capsule.id.uuidString,
            kind: .capsuleOpened,
            content: CorbieNotificationContent(
                titleKey: NotificationStrings.capsuleOpenedTitle,
                bodyKey: NotificationStrings.capsuleOpenedBody,
                arguments: [viewer.partnerName, capsule.title],
                threadIdentifier: RemoteChangeKind.capsuleOpened.rawValue,
                userInfo: NotificationPayload.userInfo(
                    remote: .capsuleOpened,
                    route: .capsule(capsule.id),
                    objectId: capsule.id
                )
            )
        )
    }

    private static func voteAlert(
        _ vote: VoteDTO,
        change: RemoteChange,
        viewer: RemoteChangeViewer
    ) -> RemoteChangeAlert? {
        switch change.type {
        case .insert:
            guard let me = viewer.memberId, vote.createdByMemberId != me else { return nil }
            return voteAlert(
                vote,
                suffix: "",
                titleKey: NotificationStrings.voteNewTitle,
                bodyKey: NotificationStrings.voteNewBody,
                arguments: [viewer.partnerName, vote.question]
            )
        case .update:
            guard change.properties.contains(RemoteChangeProperty.voteRevealed), vote.revealedAt != nil else { return nil }
            return voteAlert(
                vote,
                suffix: "revealed.",
                titleKey: NotificationStrings.voteRevealedTitle,
                bodyKey: NotificationStrings.voteRevealedBody,
                arguments: [vote.question]
            )
        case .delete:
            return nil
        }
    }

    private static func voteAlert(
        _ vote: VoteDTO,
        suffix: String,
        titleKey: String,
        bodyKey: String,
        arguments: [String]
    ) -> RemoteChangeAlert {
        RemoteChangeAlert(
            id: RemoteChangeKind.voteUpdate.prefix + suffix + vote.id.uuidString,
            kind: .voteUpdate,
            content: CorbieNotificationContent(
                titleKey: titleKey,
                bodyKey: bodyKey,
                arguments: arguments,
                categoryIdentifier: NotificationCategories.vote,
                threadIdentifier: RemoteChangeKind.voteUpdate.rawValue,
                userInfo: NotificationPayload.userInfo(
                    remote: .voteUpdate,
                    route: .vote(vote.id),
                    objectId: vote.id
                )
            )
        )
    }
}
