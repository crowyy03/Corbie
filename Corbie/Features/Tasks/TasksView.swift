import CorbieCore
import SwiftUI

struct TaskEditorRequest: Identifiable {
    let id: UUID
    let task: TaskDTO?

    init(task: TaskDTO?) {
        id = task?.id ?? UUID()
        self.task = task
    }
}

struct TasksView: View {
    @Environment(\.palette) private var palette

    @Environment(AppEnvironment.self) private var environment
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase

    @State private var model: TasksViewModel?
    @State private var editorRequest: TaskEditorRequest?

    private let subtitles = TaskSubtitleFormatter()

    var body: some View {
        ZStack {
            palette.bg.ignoresSafeArea()
            if let model {
                list(model)
            }
        }
        .screenHeader(String(localized: "tab.tasks.title")) {
            AddButton(action: startCreating)
            UsPillButton()
        }
        .sheet(item: $editorRequest) { request in
            TaskEditorView(model: editorModel(for: request))
        }
        .task {
            await start()
        }
        .onDisappear {
            model?.stopObserving()
        }
        .onChange(of: environment.session) {
            Task { await model?.apply(context) }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await model?.load() }
        }
        .onChange(of: appState.route) {
            consumeRoute()
        }
    }

    private func list(_ model: TasksViewModel) -> some View {
        List {
            Section {
                filters(model)
            }
            if model.hasLoaded, model.groups.isEmpty {
                Section {
                    emptyState(model)
                }
            }
            ForEach(model.groups) { group in
                Section {
                    ForEach(group.tasks) { task in
                        row(task, model: model)
                    }
                } header: {
                    header(for: group.kind)
                }
            }
        }
        .listStyle(.plain)
        .listRowSpacing(CorbieSpacing.xs)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .refreshable {
            await model.load()
        }
    }

    private func filters(_ model: TasksViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CorbieSpacing.xs) {
                ForEach(model.availableFilters) { filter in
                    Button {
                        model.filter = filter
                    } label: {
                        Chip(
                            label: model.label(for: filter),
                            count: model.count(for: filter),
                            isSelected: model.filter == filter
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, CorbieSpacing.l)
            .padding(.vertical, CorbieSpacing.xxs)
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func header(for kind: TaskGroup.Kind) -> some View {
        let title = switch kind {
        case .inProgress: String(localized: "tasks.section.inprogress")
        case .free: String(localized: "tasks.section.free")
        }
        return SectionCaps(text: title)
            .padding(.horizontal, CorbieSpacing.l)
            .padding(.vertical, CorbieSpacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.bg)
            .listRowInsets(EdgeInsets())
    }

    private func row(_ task: TaskDTO, model: TasksViewModel) -> some View {
        TaskRow(
            task: task,
            dotSlot: environment.memberSlot(id: task.assigneeMemberId),
            subtitle: subtitles.text(
                for: task,
                viewerMemberId: environment.currentMember?.id,
                partnerName: environment.partner?.displayName,
                now: Date()
            ),
            take: task.isFree ? { edit { await model.take(task) } } : nil
        )
        .listRowInsets(EdgeInsets(
            top: CorbieSpacing.xxs,
            leading: CorbieSpacing.l,
            bottom: CorbieSpacing.xxs,
            trailing: CorbieSpacing.l
        ))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                edit { await model.markDone(task) }
            } label: {
                Label("tasks.action.done", systemImage: "checkmark")
            }
            .tint(palette.accent)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if task.isFree {
                Button {
                    edit { await model.take(task) }
                } label: {
                    Label("tasks.action.take", systemImage: "hand.raised")
                }
                .tint(palette.accent)
            } else {
                Button {
                    edit { await model.handBack(task) }
                } label: {
                    Label("tasks.action.handback", systemImage: "arrow.uturn.backward")
                }
                .tint(palette.text2)
            }
        }
        .contextMenu {
            Button {
                startEditing(task)
            } label: {
                Label("tasks.action.edit", systemImage: "pencil")
            }
            if task.isFree == false {
                Button {
                    edit { await model.handBack(task) }
                } label: {
                    Label("tasks.action.handback", systemImage: "arrow.uturn.backward")
                }
            }
            if model.canDelete(task) {
                Button(role: .destructive) {
                    edit { await model.delete(task) }
                } label: {
                    Label("tasks.action.delete", systemImage: "trash")
                }
            }
        }
    }

    private func emptyState(_ model: TasksViewModel) -> some View {
        Group {
            if model.isEmpty {
                VStack(spacing: CorbieSpacing.s) {
                    EmptyState(
                        systemImage: "checklist",
                        title: String(localized: "tasks.empty.title"),
                        monoNote: String(localized: "tasks.empty.note"),
                        cta: EmptyStateAction(title: String(localized: "tasks.empty.action")) {
                            startCreating()
                        }
                    )
                    TasksChoreSplitAction()
                }
            } else {
                EmptyState(
                    systemImage: "line.3.horizontal.decrease",
                    title: String(localized: "tasks.empty.filtered.title")
                )
            }
        }
        .padding(.top, CorbieSpacing.xxl)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var context: TasksContext {
        TasksContext(
            spaceId: environment.space?.id,
            memberId: environment.currentMember?.id,
            partnerId: environment.partner?.id,
            partnerName: environment.partner?.displayName,
            prefs: environment.currentMember?.notificationPrefs ?? .allEnabled
        )
    }

    private func start() async {
        let created = model ?? makeModel()
        model = created
        created.startObserving()
        consumeRoute()
        await created.apply(context)
    }

    private func makeModel() -> TasksViewModel {
        let created = TasksViewModel(
            repository: environment.repositories.tasks,
            notifications: TaskDueNotifications(scheduler: environment.notifications),
            analytics: environment.analytics
        )
        created.onError = { error in
            environment.report(error)
        }
        return created
    }

    private func editorModel(for request: TaskEditorRequest) -> TaskEditorViewModel {
        let created = TaskEditorViewModel(
            task: request.task,
            context: context,
            repository: environment.repositories.tasks,
            notifications: TaskDueNotifications(scheduler: environment.notifications),
            analytics: environment.analytics
        )
        created.onError = { error in
            environment.report(error)
        }
        return created
    }

    private func edit(_ work: @escaping () async -> Void) {
        guard environment.premiumGate.require(.edit) else { return }
        Task { await work() }
    }

    private func startCreating() {
        guard environment.premiumGate.require(.create) else { return }
        editorRequest = TaskEditorRequest(task: nil)
    }

    private func startEditing(_ task: TaskDTO) {
        guard environment.premiumGate.require(.edit) else { return }
        editorRequest = TaskEditorRequest(task: task)
    }

    private func consumeRoute() {
        switch appState.route {
        case .tasks:
            appState.route = nil
        case let .task(id):
            appState.route = nil
            Task { await openTask(id) }
        default:
            break
        }
    }

    private func openTask(_ id: UUID) async {
        do {
            guard let task = try await environment.repositories.tasks.task(id: id) else { return }
            startEditing(task)
        } catch {
            environment.report(error)
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        TasksView()
    }
    .environment(AppState())
    .environment(AppEnvironment.preview())
}
#endif
