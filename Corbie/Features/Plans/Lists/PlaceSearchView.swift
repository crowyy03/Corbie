import CorbieCore
import SwiftUI

struct PlaceSearchView: View {
    let onPick: (PlaceResult) -> Void
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var model = PlaceSearchViewModel()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: CorbieSpacing.m) {
                searchField
                results
            }
            .padding(CorbieSpacing.l)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(CorbieColorPalette.bg)
            .navigationTitle(String(localized: "lists.place.search.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "common.action.cancel")) {
                        dismiss()
                    }
                }
            }
            .task {
                model.attach(environment)
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: CorbieSpacing.s) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(CorbieColorPalette.text2)
                .accessibilityHidden(true)
            TextField(String(localized: "lists.place.search.placeholder"), text: $model.query)
                .textFieldStyle(.plain)
                .corbieBody()
                .foregroundStyle(CorbieColorPalette.text)
                .submitLabel(.search)
                .onSubmit {
                    Task { await model.search() }
                }
                .accessibilityLabel(Text("lists.place.search.placeholder"))
        }
        .plansFieldBackground()
    }

    @ViewBuilder
    private var results: some View {
        if model.isSearching {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, CorbieSpacing.xl)
        } else if model.results.isEmpty {
            Text(model.didSearch ? "lists.place.search.empty" : "lists.place.search.hint")
                .corbieMono()
                .foregroundStyle(CorbieColorPalette.text2)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ScrollView {
                LazyVStack(spacing: CorbieSpacing.s) {
                    ForEach(model.results) { place in
                        Button {
                            onPick(place)
                            dismiss()
                        } label: {
                            Card {
                                VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                                    Text(place.name)
                                        .corbieBody()
                                        .foregroundStyle(CorbieColorPalette.text)
                                        .multilineTextAlignment(.leading)
                                    if let address = place.address, address.isEmpty == false {
                                        Text(address)
                                            .corbieMono()
                                            .foregroundStyle(CorbieColorPalette.text2)
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isButton)
                    }
                }
            }
        }
    }
}

#Preview {
    PlaceSearchView { _ in }
        .environment(AppEnvironment.preview())
}
