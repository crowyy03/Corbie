import CorbieCore
import MapKit
import SwiftUI

struct LocationSearchView: View {
    let onPick: (CalendarPlace) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var model = LocationSearchViewModel()

    var body: some View {
        @Bindable var model = model

        return NavigationStack {
            VStack(alignment: .leading, spacing: CorbieSpacing.m) {
                TextFieldRow(
                    label: String(localized: "calendar.location.field"),
                    placeholder: String(localized: "calendar.location.placeholder"),
                    text: $model.query
                )
                results
                Spacer(minLength: 0)
            }
            .padding(CorbieSpacing.l)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(CorbieColorPalette.bg)
            .navigationTitle(String(localized: "calendar.location.title"))
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

    @ViewBuilder
    private var results: some View {
        if model.suggestions.isEmpty {
            Text("calendar.location.hint")
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

#Preview {
    LocationSearchView { _ in }
}
