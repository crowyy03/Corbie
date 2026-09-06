import CorbieCore
import SwiftUI

struct TaskEditorRequest: Identifiable {
    let id: UUID
    let task: TaskDTO?
    let folderId: UUID?
    let opensPlaceSearch: Bool

    init(task: TaskDTO?, folderId: UUID? = nil, opensPlaceSearch: Bool = false) {
        id = task?.id ?? UUID()
        self.task = task
        self.folderId = folderId
        self.opensPlaceSearch = opensPlaceSearch
    }
}

struct FolderEditorRequest: Identifiable {
    let id: UUID
    let folder: TaskFolderDTO?

    init(folder: TaskFolderDTO?) {
        id = folder?.id ?? UUID()
        self.folder = folder
    }
}

struct TasksView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase

    @State private var model: TasksViewModel?
    @State private var editorRequest: TaskEditorRequest?
    @State private var folderRequest: FolderEditorRequest?
    @State private var isConfirmingFolderDelete = false

    private let subtitles = TaskSubtitleFormatter()

    var body: some View {
        ZStack {
            CorbieColorPalette.bg.ignoresSafeArea()
            if let model {
                content(model)
            }
        }
        .navigationTitle(Text("tab.tasks.title"))
        .toolbar {
            if let model, model.selectedFolder != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    folderMenu(model)
                }
            }
            if let model, model.showsMapToggle {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        model.toggleMode()
                    } label: {
                        Image(systemName: model.mode == .list ? "map" : "list.bullet")
                            .frame(
                                width: CorbieMetrics.minimumTapTarget,
                                height: CorbieMetrics.minimumTapTarget
                            )
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(
                        Text(String(localized: model.mode == .list ? "tasks.action.map" : "tasks.action.list"))
                    )
                }
            }
            AddToolbarItem(action: startCreating)
            UsPillToolbarItem()
        }
        .sheet(item: $editorRequest) { request in
            TaskEditorView(model: editorModel(for: request), opensPlaceSearch: request.opensPlaceSearch)
        }
        .sheet(item: $folderRequest) { request in
            FolderEditorView(model: folderModel(for: request)) { folder in
                Task {
                    await model?.load()
                    await model?.select(.folder(folder.id))
                }
            }
        }
        .confirmationDialog(
            Text("tasks.folder.delete.confirm"),
            isPresented: $isConfirmingFolderDelete,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                edit { await model?.deleteSelectedFolder() }
            } label: {
                Text("tasks.folder.action.delete")
            }
        } message: {
            Text("tasks.folder.delete.note")
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

    private func content(_ model: TasksViewModel) -> some View {
        VStack(spacing: 0) {
            chipRows(model)
            if model.selectedFolder != nil, model.mode == .map {
                TasksMapView(
                    tasks: model.placedTasks,
                    color: { environment.memberColor(id: $0) },
                    name: { environment.memberName(id: $0) }
                )
            } else {
                list(model)
            }
        }
    }

    private func chipRows(_ model: TasksViewModel) -> some View {
        VStack(spacing: CorbieSpacing.xxs) {
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
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CorbieSpacing.xs) {
                    Button {
                        Task { await model.select(.all) }
                    } label: {
                        Chip(
                            label: String(localized: "tasks.folder.all"),
                            isSelected: model.folderSelection == .all
                        )
                    }
                    .buttonStyle(.plain)
                    ForEach(model.folders) { folder in
                        Button {
                            Task { await model.select(.folder(folder.id)) }
                        } label: {
                            Chip(
                                label: folder.title,
                                isSelected: model.folderSelection == .folder(folder.id)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    addFolderChip
                }
                .padding(.horizontal, CorbieSpacing.l)
            }
        }
        .padding(.vertical, CorbieSpacing.xs)
    }

    private var addFolderChip: some View {
        Button(action: startCreatingFolder) {
            Image(systemName: "plus")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(CorbieColorPalette.text2)
                .frame(width: CorbieMetrics.minimumTapTarget, height: CorbieMetrics.chipHeight)
                .background(Capsule(style: .continuous).fill(CorbieColorPalette.surface))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(CorbieColorPalette.border, lineWidth: CorbieMetrics.hairline)
                )
                .frame(minHeight: CorbieMetrics.minimumTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("tasks.folder.add"))
    }

    private func folderMenu(_ model: TasksViewModel) -> some View {
        Menu {
            if model.showsClearDone {
                Button {
                    edit { await model.clearDone() }
                } label: {
                    Text("tasks.folder.action.cleardone")
                }
            }
            Button {
                startEditingFolder(model.selectedFolder)
            } label: {
                Text("tasks.folder.action.edit")
            }
            if model.selectedFolder?.isPinnedShopping == false {
                Button(role: .destructive) {
                    isConfirmingFolderDelete = true
                } label: {
                    Text("tasks.folder.action.delete")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .frame(width: CorbieMetrics.minimumTapTarget, height: CorbieMetrics.minimumTapTarget)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(Text("tasks.folder.menu.label"))
    }

    private func list(_ model: TasksViewModel) -> some View {
        List {
            if model.hasLoaded, model.visibleItems.isEmpty {
                Section {
                    emptyState(model)
                }
            }
            if let folder = model.selectedFolder {
                Section {
                    ForEach(model.visibleItems) { item in
                        row(item, model: model)
                    }
                } header: {
                    if let subtitle = folder.subtitle, subtitle.isEmpty == false {
                        header(text: subtitle)
                    }
                }
            } else {
                ForEach(model.groups) { group in
                    Section {
                        ForEach(group.items) { item in
                            row(item, model: model)
                        }
                    } header: {
                        header(text: title(for: group.kind))
                    }
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

    private func title(for kind: TaskGroup.Kind) -> String {
        switch kind {
        case .inProgress: return String(localized: "tasks.section.inprogress")
        case .free: return String(localized: "tasks.section.free")
        }
    }

    private func header(text: String) -> some View {
        SectionCaps(text: text)
            .padding(.horizontal, CorbieSpacing.l)
            .padding(.vertical, CorbieSpacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CorbieColorPalette.bg)
            .listRowInsets(EdgeInsets())
    }

    @ViewBuilder
    private func row(_ item: TaskListItem, model: TasksViewModel) -> some View {
        let card = TaskRow(
            title: item.title,
            subtitle: subtitle(for: item, model: model),
            dotColor: dotColor(for: item, model: model),
            placeName: item.task?.hasPlace == true ? item.task?.placeName : nil,
            isDone: item.isDone,
            tick: model.selectedFolder != nil && model.canTick(item)
                ? { edit { await model.toggleDone(item) } }
                : nil,
            take: item.isFree && item.task != nil ? { edit { await model.take(item) } } : nil
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
            if model.canTick(item) {
                Button {
                    edit { await model.toggleDone(item) }
                } label: {
                    Label(
                        String(localized: item.isDone ? "tasks.action.undone" : "tasks.action.done"),
                        systemImage: item.isDone ? "arrow.uturn.backward" : "checkmark"
                    )
                }
                .tint(CorbieColorPalette.ice)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if item.task != nil {
                if item.isFree {
                    Button {
                        edit { await model.take(item) }
                    } label: {
                        Label("tasks.action.take", systemImage: "hand.raised")
                    }
                    .tint(CorbieColorPalette.ice)
                } else {
                    Button {
                        edit { await model.handBack(item) }
                    } label: {
                        Label("tasks.action.handback", systemImage: "arrow.uturn.backward")
                    }
                    .tint(CorbieColorPalette.text2)
                }
            }
        }

        if let task = item.task {
            card.contextMenu {
                menu(for: item, task: task, model: model)
            }
        } else {
            card
        }
    }

    @ViewBuilder
    private func menu(for item: TaskListItem, task: TaskDTO, model: TasksViewModel) -> some View {
        Button {
            startEditing(task)
        } label: {
            Label("tasks.action.edit", systemImage: "pencil")
        }
        if item.isFree == false {
            Button {
                edit { await model.handBack(item) }
            } label: {
                Label("tasks.action.handback", systemImage: "arrow.uturn.backward")
            }
        }
        if task.hasPlace == false {
            Button {
                startAddingPlace(task)
            } label: {
                Label("tasks.action.addplace", systemImage: "mappin")
            }
        }
        Menu {
            Button {
                edit { await model.move(item, to: nil) }
            } label: {
                Text("tasks.editor.folder.none")
            }
            ForEach(model.folders) { folder in
                Button(folder.title) {
                    edit { await model.move(item, to: folder.id) }
                }
            }
        } label: {
            Label("tasks.action.move", systemImage: "folder")
        }
        if model.canDelete(item) {
            Button(role: .destructive) {
                edit { await model.delete(item) }
            } label: {
                Label("tasks.action.delete", systemImage: "trash")
            }
        }
    }

    private func subtitle(for item: TaskListItem, model: TasksViewModel) -> String {
        if model.selectedFolder != nil, item.isFree, item.isDone == false, item.task?.dueAt == nil {
            return ""
        }
        return subtitles.text(
            for: item,
            viewerMemberId: environment.currentMember?.id,
            partnerName: environment.partner?.displayName,
            now: Date()
        )
    }

    private func dotColor(for item: TaskListItem, model: TasksViewModel) -> Color {
        guard model.selectedFolder != nil, let task = item.task else {
            return environment.memberColor(id: item.assigneeMemberId)
        }
        return environment.memberColor(id: task.createdByMemberId)
    }

    private func emptyState(_ model: TasksViewModel) -> some View {
        Group {
            if let folder = model.selectedFolder {
                EmptyState(
                    systemImage: folder.template.systemImage,
                    title: String(localized: "tasks.folder.empty.title"),
                    monoNote: folder.template.itemPlaceholder,
                    cta: EmptyStateAction(title: String(localized: "tasks.empty.action")) {
                        startCreating()
                    }
                )
            } else if model.isEmpty {
                EmptyState(
                    systemImage: "checklist",
                    title: String(localized: "tasks.empty.title"),
                    monoNote: String(localized: "tasks.empty.note"),
                    cta: EmptyStateAction(title: String(localized: "tasks.empty.action")) {
                        startCreating()
                    }
                )
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
            provider: UnifiedTaskProvider(repositories: environment.repositories),
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
            folderId: request.folderId,
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

    private func folderModel(for request: FolderEditorRequest) -> FolderEditorViewModel {
        let created = FolderEditorViewModel(
            folder: request.folder,
            context: context,
            repository: environment.repositories.tasks,
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
        editorRequest = TaskEditorRequest(task: nil, folderId: model?.selectedFolder?.id)
    }

    private func startEditing(_ task: TaskDTO) {
        guard environment.premiumGate.require(.edit) else { return }
        editorRequest = TaskEditorRequest(task: task)
    }

    private func startAddingPlace(_ task: TaskDTO) {
        guard environment.premiumGate.require(.edit) else { return }
        editorRequest = TaskEditorRequest(task: task, opensPlaceSearch: true)
    }

    private func startCreatingFolder() {
        guard environment.premiumGate.require(.create) else { return }
        folderRequest = FolderEditorRequest(folder: nil)
    }

    private func startEditingFolder(_ folder: TaskFolderDTO?) {
        guard let folder, environment.premiumGate.require(.edit) else { return }
        folderRequest = FolderEditorRequest(folder: folder)
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
