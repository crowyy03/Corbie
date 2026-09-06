import CorbieCore
import SwiftUI

struct ListDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var model: ListDetailViewModel

    init(listId: UUID) {
        _model = State(initialValue: ListDetailViewModel(listId: listId))
    }

    var body: some View {
        content
            .background(CorbieColorPalette.bg)
            .navigationTitle(model.list?.title ?? "")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if model.mode == .list {
                    ToolbarItem(placement: .topBarTrailing) {
                        EditButton()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        model.toggleMode()
                    } label: {
                        Image(systemName: model.mode == .list ? "map" : "list.bullet")
                    }
                    .accessibilityLabel(Text(model.mode == .list ? "lists.detail.action.map" : "lists.detail.action.list"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    listMenu
                }
            }
            .sheet(item: $model.editingItem, onDismiss: { Task { await model.load() } }) { item in
                ListItemEditorView(item: item)
            }
            .sheet(isPresented: $model.isEditingList, onDismiss: { Task { await model.load() } }) {
                ListEditorView(list: model.list)
            }
            .confirmationDialog(
                String(localized: "lists.detail.delete.confirm"),
                isPresented: $model.isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button(String(localized: "common.action.delete"), role: .destructive) {
                    Task {
                        if await model.deleteList() { dismiss() }
                    }
                }
            }
            .task {
                model.attach(environment)
                await model.load()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch model.mode {
        case .list:
            itemsList
        case .map:
            ListMapView(
                items: model.placedItems,
                color: { environment.memberColor(id: $0) },
                name: { environment.memberName(id: $0) }
            )
        }
    }

    private var listMenu: some View {
        Menu {
            Button(String(localized: "lists.detail.action.edit")) {
                model.startEditingList()
            }
            if model.list?.isPinnedShopping == false {
                Button(String(localized: "lists.detail.action.delete"), role: .destructive) {
                    model.startDeletingList()
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel(Text("lists.detail.menu.label"))
    }

    private var itemsList: some View {
        List {
            Section {
                addRow
                    .plansListRow()
            } header: {
                if let subtitle = model.list?.subtitle, subtitle.isEmpty == false {
                    Text(subtitle)
                        .corbieMono()
                        .foregroundStyle(CorbieColorPalette.text2)
                        .textCase(nil)
                        .plansListRow()
                }
            }
            if model.items.isEmpty {
                if model.isLoaded {
                    Section {
                        EmptyState(
                            systemImage: model.list?.template.systemImage ?? "list.bullet",
                            title: String(localized: "lists.detail.empty.title"),
                            monoNote: String(localized: "lists.detail.empty.note")
                        )
                        .padding(.vertical, CorbieSpacing.l)
                        .plansListRow()
                    }
                }
            } else {
                Section {
                    ForEach(model.items) { item in
                        row(for: item)
                            .plansListRow()
                    }
                    .onDelete { offsets in
                        Task { await model.deleteItems(at: offsets) }
                    }
                    .onMove { offsets, destination in
                        Task { await model.moveItems(from: offsets, to: destination) }
                    }
                }
            }
            if model.showsClearDone {
                Section {
                    SecondaryButton(title: String(localized: "lists.detail.action.cleardone")) {
                        Task { await model.clearDone() }
                    }
                    .plansListRow()
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var addRow: some View {
        HStack(spacing: CorbieSpacing.s) {
            Image(systemName: "plus")
                .foregroundStyle(CorbieColorPalette.text2)
                .accessibilityHidden(true)
            TextField(String(localized: "lists.detail.additem.placeholder"), text: $model.draftTitle)
                .textFieldStyle(.plain)
                .corbieBody()
                .foregroundStyle(CorbieColorPalette.text)
                .submitLabel(.done)
                .onSubmit {
                    Task { await model.addDraftItem() }
                }
                .accessibilityLabel(Text("lists.detail.additem.placeholder"))
        }
        .plansFieldBackground()
    }

    private func row(for item: ListItemDTO) -> some View {
        ListItemRow(
            item: item,
            addedByColor: environment.memberColor(id: item.addedByMemberId),
            addedByName: environment.memberName(id: item.addedByMemberId),
            checkedByColor: environment.memberColor(id: item.checkedByMemberId),
            checkedByName: item.checkedByMemberId.map { environment.memberName(id: $0) },
            onToggle: {
                Task { await model.toggle(item) }
            },
            onOpen: {
                model.startEditing(item)
            }
        )
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        ListDetailView(listId: UUID())
    }
    .environment(AppEnvironment.preview())
}
#endif
