import CorbieCore
import SwiftUI

struct TodayView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase

    @State private var model: TodayViewModel?
    @State private var quickAction: TodayQuickAction?

    private let presentation = TodayPresentation()

    var body: some View {
        ZStack {
            CorbieColorPalette.bg.ignoresSafeArea()
            if let model {
                content(model)
            }
        }
        .navigationTitle(Text("tab.today.title"))
        .toolbar {
            UsPillToolbarItem()
        }
        .sheet(item: $quickAction) { action in
            quickActionSheet(action)
        }
        .task { await start() }
        .onDisappear { model?.stopObserving() }
        .onChange(of: environment.session) {
            Task { await model?.apply(context) }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await model?.load() }
        }
    }

    private func content(_ model: TodayViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CorbieSpacing.l) {
                header(model)
                if model.hasLoaded, model.feed.isEmpty {
                    emptyState(model)
                } else {
                    blocks(model)
                }
            }
            .padding(.horizontal, CorbieSpacing.l)
            .padding(.bottom, CorbieSpacing.xxl)
        }
        .refreshable { await model.load() }
    }

    private func header(_ model: TodayViewModel) -> some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
            SectionCaps(text: presentation.headerDate(model.feed.day))
            HStack(alignment: .firstTextBaseline, spacing: CorbieSpacing.xs) {
                if let days = model.feed.daysTogether {
                    Text(presentation.daysTogether(days))
                        .corbieCounter()
                        .foregroundStyle(CorbieColorPalette.text)
                    Text("today.header.days")
                        .corbieMono()
                        .foregroundStyle(CorbieColorPalette.text2)
                }
                Spacer(minLength: 0)
                HStack(spacing: CorbieSpacing.xxs) {
                    MemberDot(color: environment.memberColor(id: environment.currentMember?.id))
                    if environment.isPaired {
                        MemberDot(color: environment.memberColor(id: environment.partner?.id))
                    }
                }
            }
        }
        .padding(.top, CorbieSpacing.xs)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private func blocks(_ model: TodayViewModel) -> some View {
        if model.feed.entries.isEmpty == false {
            block(String(localized: "today.block.today")) {
                ForEach(model.feed.entries) { entry in
                    entryRow(entry, model: model)
                }
            }
        }
        if model.feed.freeTasks.isEmpty == false {
            block(String(localized: "today.block.freetasks")) {
                ForEach(model.feed.freeTasks) { task in
                    TodayFreeTaskRow(
                        title: task.title,
                        take: { edit { await model.take(task) } },
                        open: { open(block: .freeTasks, route: .task(task.id), model: model) }
                    )
                }
                if model.feed.freeTasksRemaining > 0 {
                    Button {
                        open(block: .freeTasks, route: .tasks, model: model)
                    } label: {
                        Text(presentation.moreFreeTasks(model.feed.freeTasksRemaining))
                            .corbieMono()
                            .foregroundStyle(CorbieColorPalette.ice)
                            .frame(maxWidth: .infinity, minHeight: CorbieMetrics.minimumTapTarget, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        if model.feed.comingUp.isEmpty == false {
            block(String(localized: "today.block.comingup")) {
                ForEach(model.feed.comingUp) { date in
                    TodayDateRow(
                        title: presentation.dateTitle(date),
                        caption: presentation.dateCaption(date),
                        giftLine: date.isGiftMissing ? presentation.giftLine(date) : nil,
                        dotColor: environment.memberColor(id: date.memberId),
                        open: { open(block: .comingUp, route: route(for: date), model: model) }
                    )
                }
            }
        }
        if let goal = model.feed.goal {
            block(String(localized: "today.block.goal")) {
                TodayGoalCard(
                    title: goal.title,
                    amount: presentation.goalAmount(goal),
                    progress: goal.progress,
                    open: { open(block: .goal, route: .goal(goal.id), model: model) }
                )
            }
        }
        if model.feed.waiting.isEmpty == false {
            block(String(localized: "today.block.waiting")) {
                ForEach(model.feed.waiting) { item in
                    waitingRow(item, model: model)
                }
            }
        }
        if let recap = model.feed.recap {
            RecapCard(summary: recap) {
                model.record(block: .recap)
                Task { await model.openRecap() }
            }
        }
    }

    private func block(
        _ title: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
            SectionCaps(text: title)
            content()
        }
    }

    private func entryRow(_ entry: TodayEntry, model: TodayViewModel) -> some View {
        TodayEntryRow(
            entry: entry,
            dotColor: environment.memberColor(id: entry.memberId),
            time: presentation.time(for: entry),
            fromGoal: entry.goalTitle.map(presentation.fromGoal),
            checkboxLabel: presentation.checkboxLabel(entry),
            toggle: entry.task == nil ? nil : { edit { await model.toggle(entry) } },
            open: { open(block: .today, route: route(for: entry), model: model) }
        )
    }

    private func waitingRow(_ item: TodayWaitingItem, model: TodayViewModel) -> some View {
        let content = waitingContent(item)
        return TodayWaitingRow(
            title: content.title,
            caption: content.caption,
            open: { open(block: .waiting, route: content.route, model: model) }
        )
    }

    private func waitingContent(_ item: TodayWaitingItem) -> (title: String, caption: String, route: Route) {
        switch item {
        case let .capsule(capsule):
            return (capsule.title, String(localized: "today.waiting.capsule"), .capsules)
        case let .vote(vote):
            return (vote.question, String(localized: "today.waiting.vote"), .votes)
        case let .partnerWishes(count):
            let text = presentation.waitingWishes(partner: environment.partnerName, count: count)
            return (text.title, text.caption, .wishes)
        }
    }

    private func emptyState(_ model: TodayViewModel) -> some View {
        VStack(spacing: CorbieSpacing.m) {
            EmptyState(
                systemImage: "sun.max",
                title: String(localized: "today.empty.title"),
                monoNote: String(localized: "today.empty.note")
            )
            PrimaryButton(title: String(localized: "today.action.task")) {
                start(quickAction: .task, model: model)
            }
            SecondaryButton(title: String(localized: "today.action.date")) {
                start(quickAction: .date, model: model)
            }
            if model.feed.isPaired == false {
                SecondaryButton(title: String(localized: "today.action.invite")) {
                    start(quickAction: .invite, model: model)
                }
            }
        }
        .padding(.top, CorbieSpacing.xxl)
    }

    @ViewBuilder private func quickActionSheet(_ action: TodayQuickAction) -> some View {
        switch action {
        case .task:
            TaskEditorView(model: taskEditorModel())
        case .date:
            EventEditorView(
                target: .create(Date()),
                people: model?.people ?? [],
                calendar: .current
            )
        case .invite:
            NavigationStack {
                InviteView(environment: environment, spaceId: environment.space?.id ?? UUID()) {
                    quickAction = nil
                }
            }
        }
    }

    private var context: TodayContext {
        TodayContext(
            space: environment.space,
            memberId: environment.currentMember?.id,
            prefs: environment.currentMember?.notificationPrefs ?? .allEnabled
        )
    }

    private func start() async {
        let created = model ?? makeModel()
        model = created
        created.startObserving()
        await created.apply(context)
    }

    private func makeModel() -> TodayViewModel {
        let created = TodayViewModel(
            repositories: environment.repositories,
            notifications: environment.notifications,
            analytics: environment.analytics
        )
        created.onError = { error in
            environment.report(error)
        }
        created.onMemberChanged = { member in
            environment.apply(member: member)
        }
        return created
    }

    private func taskEditorModel() -> TaskEditorViewModel {
        let created = TaskEditorViewModel(
            task: nil,
            context: TasksContext(
                spaceId: environment.space?.id,
                memberId: environment.currentMember?.id,
                partnerId: environment.partner?.id,
                partnerName: environment.partner?.displayName,
                prefs: environment.currentMember?.notificationPrefs ?? .allEnabled
            ),
            repository: environment.repositories.tasks,
            notifications: TaskDueNotifications(scheduler: environment.notifications),
            analytics: environment.analytics
        )
        created.onError = { error in
            environment.report(error)
        }
        return created
    }

    private func route(for entry: TodayEntry) -> Route {
        switch entry.item {
        case .event:
            return .calendar
        case let .task(task):
            guard let goalId = entry.goalId else { return .task(task.id) }
            return .goal(goalId)
        }
    }

    private func route(for date: TodayDate) -> Route {
        if let personId = date.personId { return .person(personId) }
        if date.eventId != nil { return .calendar }
        return .people
    }

    private func open(block: TodayBlock, route: Route, model: TodayViewModel) {
        model.record(block: block)
        appState.open(route)
    }

    private func start(quickAction kind: TodayQuickAction, model: TodayViewModel) {
        model.record(quickAction: kind)
        switch kind {
        case .task, .date:
            guard environment.premiumGate.require(.create) else { return }
        case .invite:
            break
        }
        quickAction = kind
    }

    private func edit(_ work: @escaping () async -> Void) {
        guard environment.premiumGate.require(.edit) else { return }
        Task { await work() }
    }
}


#if DEBUG
#Preview {
    NavigationStack {
        TodayView()
    }
    .environment(AppState())
    .environment(AppEnvironment.previewSignedIn())
}
#endif
