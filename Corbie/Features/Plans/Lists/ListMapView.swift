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
    @Environment(\.palette) private var palette

    let items: [ListItemDTO]
    let slot: (UUID?) -> MemberColorSlot?
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
            .background(palette.bg)
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
            .fill(slot(item.addedByMemberId).map(palette.member) ?? palette.accent)
            .frame(width: CorbieSpacing.m, height: CorbieSpacing.m)
            .overlay(
                Circle().strokeBorder(palette.surface, lineWidth: CorbieSpacing.xxs / 2)
            )
            .frame(width: CorbieMetrics.minimumTapTarget, height: CorbieMetrics.minimumTapTarget)
            .contentShape(Circle())
    }
}

struct ListPlaceSheet: View {
    @Environment(\.palette) private var palette

    let item: ListItemDTO
    let memberName: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CorbieSpacing.m) {
                    Text(item.title)
                        .corbieScreenTitle()
                        .foregroundStyle(palette.text)
                    if let placeName = item.placeName, placeName.isEmpty == false, placeName != item.title {
                        Text(placeName)
                            .corbieBody()
                            .foregroundStyle(palette.text)
                    }
                    if let address = item.address, address.isEmpty == false {
                        Text(address)
                            .corbieMono()
                            .foregroundStyle(palette.text2)
                    }
                    if let note = item.note, note.isEmpty == false {
                        Text(note)
                            .corbieBody()
                            .foregroundStyle(palette.text)
                    }
                    Text(String(format: PlansCopy.text("lists.map.addedby"), memberName))
                        .corbieMono()
                        .foregroundStyle(palette.text2)
                    PrimaryButton(title: String(localized: "lists.map.openinmaps")) {
                        openInMaps()
                    }
                    .padding(.top, CorbieSpacing.s)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(CorbieSpacing.l)
            }
            .background(palette.bg)
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

#if DEBUG
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
        slot: { _ in MemberColorSlot.teal },
        name: { _ in "you" }
    )
}
#endif
