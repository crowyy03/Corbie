import Foundation

public enum NotificationCategories {
    public static let task = "CORBIE_TASK"
    public static let vote = "CORBIE_VOTE"

    public enum Action {
        public static let takeTask = "CORBIE_TASK_TAKE"
        public static let completeTask = "CORBIE_TASK_DONE"
        public static let castVote = "CORBIE_VOTE_CAST"
    }

    public static let taskCategory = NotificationCategoryDescriptor(
        identifier: task,
        actions: [
            NotificationActionDescriptor(
                identifier: Action.takeTask,
                titleKey: "notification.action.task.take",
                opensApp: false
            ),
            NotificationActionDescriptor(
                identifier: Action.completeTask,
                titleKey: "notification.action.task.done",
                opensApp: false
            )
        ]
    )

    public static let voteCategory = NotificationCategoryDescriptor(
        identifier: vote,
        actions: [
            NotificationActionDescriptor(
                identifier: Action.castVote,
                titleKey: "notification.action.vote.cast",
                opensApp: true
            )
        ]
    )

    public static let all: [NotificationCategoryDescriptor] = [taskCategory, voteCategory]
}

public enum NotificationStrings {
    public static let eventReminderTitle = "notification.event.reminder.title"
    public static let eventReminderBody = "notification.event.reminder.body"
    public static let eventTodayTitle = "notification.event.today.title"
    public static let eventTodayBody = "notification.event.today.body"
    public static let eventTomorrowTitle = "notification.event.tomorrow.title"
    public static let eventTomorrowBody = "notification.event.tomorrow.body"
    public static let taskDueTodayTitle = "notification.task.duetoday.title"
    public static let taskDueTodayBody = "notification.task.duetoday.body"
    public static let capsuleReceivedTitle = "notification.capsule.received.title"
    public static let capsuleReceivedBody = "notification.capsule.received.body"
    public static let capsuleSentTitle = "notification.capsule.sent.title"
    public static let capsuleSentBody = "notification.capsule.sent.body"
    public static let radarTitle = "notification.radar.title"
    public static let radarBodyPicked = "notification.radar.body.picked"
    public static let radarBodyMissing = "notification.radar.body.missing"
    public static let taskAssignedTitle = "notification.task.assigned.title"
    public static let taskAssignedBody = "notification.task.assigned.body"
    public static let taskTakenTitle = "notification.task.taken.title"
    public static let taskTakenBody = "notification.task.taken.body"
    public static let taskHandedBackTitle = "notification.task.handedback.title"
    public static let taskHandedBackBody = "notification.task.handedback.body"
    public static let wishAddedTitle = "notification.wish.added.title"
    public static let wishAddedBody = "notification.wish.added.body"
    public static let planExpenseTitle = "notification.plan.expense.title"
    public static let planExpenseBody = "notification.plan.expense.body"
    public static let planGoalTitle = "notification.plan.goal.title"
    public static let planGoalBody = "notification.plan.goal.body"
    public static let planOverTitle = "notification.plan.over.title"
    public static let planOverBody = "notification.plan.over.body"
    public static let capsuleOpenedTitle = "notification.capsule.opened.title"
    public static let capsuleOpenedBody = "notification.capsule.opened.body"
    public static let voteNewTitle = "notification.vote.new.title"
    public static let voteNewBody = "notification.vote.new.body"
    public static let voteRevealedTitle = "notification.vote.revealed.title"
    public static let voteRevealedBody = "notification.vote.revealed.body"
    public static let recapTitle = "notification.recap.title"
    public static let recapBody = "notification.recap.body"
    public static let recapBodyDates = "notification.recap.body.dates"
    public static let questionTitle = "notification.question.title"
    public static let questionBodyPartner = "notification.question.body.partner"
    public static let questionBodyNeither = "notification.question.body.neither"
    public static let choreReadyTitle = "notification.chore.ready.title"
    public static let choreReadyBody = "notification.chore.ready.body"
    public static let memberFallback = "member.name.partner"

    public static let all: [String] = [
        eventReminderTitle,
        eventReminderBody,
        eventTodayTitle,
        eventTodayBody,
        eventTomorrowTitle,
        eventTomorrowBody,
        taskDueTodayTitle,
        taskDueTodayBody,
        capsuleReceivedTitle,
        capsuleReceivedBody,
        capsuleSentTitle,
        capsuleSentBody,
        radarTitle,
        radarBodyPicked,
        radarBodyMissing,
        taskAssignedTitle,
        taskAssignedBody,
        taskTakenTitle,
        taskTakenBody,
        taskHandedBackTitle,
        taskHandedBackBody,
        wishAddedTitle,
        wishAddedBody,
        planExpenseTitle,
        planExpenseBody,
        planGoalTitle,
        planGoalBody,
        planOverTitle,
        planOverBody,
        capsuleOpenedTitle,
        capsuleOpenedBody,
        voteNewTitle,
        voteNewBody,
        voteRevealedTitle,
        voteRevealedBody,
        recapTitle,
        recapBody,
        recapBodyDates,
        questionTitle,
        questionBodyPartner,
        questionBodyNeither,
        choreReadyTitle,
        choreReadyBody,
        memberFallback,
        "notification.action.task.take",
        "notification.action.task.done",
        "notification.action.vote.cast"
    ]
}
