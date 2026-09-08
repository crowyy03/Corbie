import CorbieCore
import SwiftUI

struct ListItemEditorView: View {
    @Environment(\.palette) private var palette

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var model: ListItemEditorViewModel

    init(item: ListItemDTO) {
        _model = State(initialValue: ListItemEditorViewModel(item: item))
    }

    var body: some View {
        PlansEditorScaffold(
            title: String(localized: "lists.item.editor.title"),
            saveTitle: String(localized: "common.action.save"),
            canSave: model.canSave,
            onCancel: { dismiss() },
            onSave: {
                Task {
                    if await model.save() { dismiss() }
                }
            }
        ) {
            TextFieldRow(
                label: String(localized: "lists.item.field.text"),
                placeholder: String(localized: "lists.item.field.text.placeholder"),
                text: $model.title
            )
            PlansNoteField(
                label: String(localized: "lists.item.field.note"),
                placeholder: String(localized: "lists.item.field.note.placeholder"),
                text: $model.note
            )
            FieldRow(label: String(localized: "lists.item.field.place")) {
                place
            }
        }
        .sheet(isPresented: $model.isSearchingPlace) {
            PlaceSearchView(
                title: String(localized: "lists.place.search.title"),
                placeholder: String(localized: "lists.place.search.placeholder")
            ) { place in
                model.apply(place)
            }
        }
        .task {
            model.attach(environment)
        }
    }

    @ViewBuilder
    private var place: some View {
        if model.hasPlace {
            VStack(alignment: .leading, spacing: CorbieSpacing.s) {
                Card {
                    VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                        Text(model.placeName ?? model.title)
                            .corbieBody()
                            .foregroundStyle(palette.text)
                        if let address = model.address, address.isEmpty == false {
                            Text(address)
                                .corbieMono()
                                .foregroundStyle(palette.text2)
                        }
                    }
                }
                SecondaryButton(title: String(localized: "lists.item.action.removeplace")) {
                    model.removePlace()
                }
            }
        } else {
            SecondaryButton(title: String(localized: "lists.item.action.addplace")) {
                model.startPlaceSearch()
            }
        }
    }
}

#if DEBUG
#Preview {
    ListItemEditorView(item: ListItemDTO(id: UUID(), title: "Time Out Market"))
        .environment(AppEnvironment.preview())
}
#endif
