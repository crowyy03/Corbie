import CorbieCore
import MapKit
import SwiftUI

struct PlaceSearchView: View {
    let title: String
    let placeholder: String
    let onPick: (MapPlace) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var model = PlaceSearchViewModel()

    var body: some View {
        @Bindable var model = model

        return NavigationStack {
            VStack(alignment: .leading, spacing: CorbieSpacing.m) {
                searchField(query: $model.query)
                results
                Spacer(minLength: 0)
            }
            .padding(CorbieSpacing.l)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(CorbieColorPalette.bg)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "common.action.cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func searchField(query: Binding<String>) -> some View {
        HStack(spacing: CorbieSpacing.s) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(CorbieColorPalette.text2)
                .accessibilityHidden(true)
            TextField(placeholder, text: query)
                .textFieldStyle(.plain)
                .corbieBody()
                .foregroundStyle(CorbieColorPalette.text)
                .accessibilityLabel(placeholder)
        }
        .padding(.horizontal, CorbieSpacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: CorbieMetrics.minimumTapTarget)
        .corbieFieldBox()
    }

    @ViewBuilder
    private var results: some View {
        if model.suggestions.isEmpty {
            Text(model.hasQuery ? "place.search.empty" : "place.search.hint")
                .corbieMono()
                .foregroundStyle(CorbieColorPalette.text2)
        } else {
            ScrollView {
                VStack(spacing: CorbieSpacing.xs) {
                    ForEach(Array(model.suggestions.enumerated()), id: \.offset) { item in
                        suggestionRow(item.element)
                    }
                }
            }
            .scrollDismissesKeyboard(.immediately)
        }
    }

    private func suggestionRow(_ suggestion: MKLocalSearchCompletion) -> some View {
        Button {
            Task {
                guard let place = await model.resolve(suggestion) else { return }
                onPick(place)
                dismiss()
            }
        } label: {
            Card {
                VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                    Text(suggestion.title)
                        .corbieBody()
                        .foregroundStyle(CorbieColorPalette.text)
                        .multilineTextAlignment(.leading)
                    if suggestion.subtitle.isEmpty == false {
                        Text(suggestion.subtitle)
                            .corbieMono()
                            .foregroundStyle(CorbieColorPalette.text2)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(model.isResolving)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

#if DEBUG
#Preview {
    PlaceSearchView(
        title: String(localized: "lists.place.search.title"),
        placeholder: String(localized: "lists.place.search.placeholder")
    ) { _ in }
}
#endif
