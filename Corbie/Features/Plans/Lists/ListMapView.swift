import CorbieCore
import MapKit
import SwiftUI

extension ListItemDTO {
    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct ListMapView: View {
    let items: [ListItemDTO]
    let color: (UUID?) -> Color
    let name: (UUID?) -> String

    @State private var camera: MapCameraPosition = .automatic
    @State private var selected: ListItemDTO?

    var body: some View {
        content
            .sheet(item: $selected) { item in
                ListPlaceSheet(item: item, memberName: name(item.addedByMemberId))
            }
    }

    @ViewBuilder
    private var content: some View {
        if items.isEmpty {
            EmptyState(
                systemImage: "map",
                title: String(localized: "lists.map.empty.title"),
                monoNote: String(localized: "lists.map.empty.note")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CorbieColorPalette.bg)
        } else {
            Map(position: $camera) {
                ForEach(items) { item in
                    if let coordinate = item.coordinate {
                        Annotation(item.title, coordinate: coordinate) {
                            Button {
                                selected = item
                            } label: {
                                pin(for: item)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(item.title))
                        }
                    }
                }
            }
            .mapControls {
                MapCompass()
                MapScaleView()
            }
        }
    }

    private func pin(for item: ListItemDTO) -> some View {
        Circle()
            .fill(color(item.addedByMemberId))
            .frame(width: CorbieSpacing.m, height: CorbieSpacing.m)
            .overlay(
                Circle().strokeBorder(CorbieColorPalette.surface, lineWidth: CorbieSpacing.xxs / 2)
            )
            .frame(width: CorbieMetrics.minimumTapTarget, height: CorbieMetrics.minimumTapTarget)
            .contentShape(Circle())
    }
}

struct ListPlaceSheet: View {
    let item: ListItemDTO
    let memberName: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CorbieSpacing.m) {
                    Text(item.title)
                        .corbieScreenTitle()
                        .foregroundStyle(CorbieColorPalette.text)
                    if let placeName = item.placeName, placeName.isEmpty == false, placeName != item.title {
                        Text(placeName)
                            .corbieBody()
                            .foregroundStyle(CorbieColorPalette.text)
                    }
                    if let address = item.address, address.isEmpty == false {
                        Text(address)
                            .corbieMono()
                            .foregroundStyle(CorbieColorPalette.text2)
                    }
                    if let note = item.note, note.isEmpty == false {
                        Text(note)
                            .corbieBody()
                            .foregroundStyle(CorbieColorPalette.text)
                    }
                    Text(String(format: PlansCopy.text("lists.map.addedby"), memberName))
                        .corbieMono()
                        .foregroundStyle(CorbieColorPalette.text2)
                    PrimaryButton(title: String(localized: "lists.map.openinmaps")) {
                        openInMaps()
                    }
                    .padding(.top, CorbieSpacing.s)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(CorbieSpacing.l)
            }
            .background(CorbieColorPalette.bg)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.action.done")) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func openInMaps() {
        guard let coordinate = item.coordinate else { return }
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = item.placeName ?? item.title
        mapItem.openInMaps()
    }
}

#Preview {
    ListMapView(
        items: [
            ListItemDTO(
                id: UUID(),
                title: "Time Out Market",
                placeName: "Time Out Market",
                address: "Av. 24 de Julho, Lisbon",
                latitude: 38.7067,
                longitude: -9.1459
            )
        ],
        color: { _ in MemberColorKey.p1.color },
        name: { _ in "you" }
    )
}
