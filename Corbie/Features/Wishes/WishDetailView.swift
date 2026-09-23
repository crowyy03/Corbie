import CorbieCore
import SwiftUI

struct WishDetailView: View {
    @Environment(\.palette) private var palette

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var model: WishDetailViewModel

    init(wishId: UUID, wish: WishDTO?, approximate: Money?) {
        _model = State(initialValue: WishDetailViewModel(wishId: wishId, wish: wish, approximate: approximate))
    }

    var body: some View {
        @Bindable var model = model

        content
            .toolbar(.hidden, for: .navigationBar)
            .keepsEdgeSwipeBack()
            .task {
                model.attach(environment)
                await model.load()
            }
            .onChange(of: model.isGone) {
                if model.isGone { dismiss() }
            }
            .confirmationDialog(
                Text("wishes.detail.delete.confirm"),
                isPresented: $model.isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button(String(localized: "common.action.delete"), role: .destructive) {
                    Task { await model.delete() }
                }
                Button(String(localized: "common.action.cancel"), role: .cancel) {}
            }
            .sheet(item: $model.editor) { request in
                WishEditorView(request: request) {
                    await model.load()
                }
            }
    }

    @ViewBuilder private var content: some View {
        if let wish = model.wish {
            WishDetailContent(
                wish: wish,
                approximate: model.approximate,
                ownerSlot: environment.memberSlot(id: wish.ownerMemberId),
                addedLine: WishDetailText.added(
                    ownerName: environment.memberName(id: wish.ownerMemberId),
                    createdAt: wish.createdAt
                ),
                actions: actions
            )
        } else {
            WishDetailChrome(back: actions.back, edit: actions.edit, delete: actions.delete)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(palette.bg.ignoresSafeArea())
        }
    }

    private var actions: WishDetailActions {
        WishDetailActions(
            back: { dismiss() },
            edit: { model.startEditing() },
            delete: { model.startDeleting() },
            open: { openURL($0) },
            fulfil: { Task { await model.fulfil() } }
        )
    }
}
