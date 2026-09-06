import CorbieCore
import MapKit
import SwiftUI

struct TasksMapView: View {
    let tasks: [TaskDTO]
    let color: (UUID?) -> Color
    let name: (UUID?) -> String

    @State private var camera: MapCameraPosition = .automatic
    @State private var selected: TaskDTO?

    var body: some View {
        Map(position: $camera) {
            ForEach(tasks) { task in
                if let coordinate = task.coordinate {
                    Annotation(task.title, coordinate: coordinate) {
                        Button {
                            selected = task
                        } label: {
                            pin(for: task)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(task.title))
                    }
                }
            }
        }
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .sheet(item: $selected) { task in
            TaskPlaceSheet(task: task, memberName: name(task.createdByMemberId))
        }
    }

    private func pin(for task: TaskDTO) -> some View {
        Circle()
            .fill(color(task.createdByMemberId))
            .frame(width: CorbieSpacing.m, height: CorbieSpacing.m)
            .overlay(
                Circle().strokeBorder(CorbieColorPalette.surface, lineWidth: CorbieSpacing.xxs / 2)
            )
            .frame(width: CorbieMetrics.minimumTapTarget, height: CorbieMetrics.minimumTapTarget)
            .contentShape(Circle())
    }
}

struct TaskPlaceSheet: View {
    let task: TaskDTO
    let memberName: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CorbieSpacing.m) {
                    Text(task.title)
                        .corbieScreenTitle()
                        .foregroundStyle(CorbieColorPalette.text)
                    if let placeName = task.placeName, placeName.isEmpty == false, placeName != task.title {
                        Text(placeName)
                            .corbieBody()
                            .foregroundStyle(CorbieColorPalette.text)
                    }
                    if let address = task.address, address.isEmpty == false {
                        Text(address)
                            .corbieMono()
                            .foregroundStyle(CorbieColorPalette.text2)
                    }
                    if let note = task.note, note.isEmpty == false {
                        Text(note)
                            .corbieBody()
                            .foregroundStyle(CorbieColorPalette.text)
                    }
                    Text(String(format: String(localized: "tasks.map.addedby"), memberName))
                        .corbieMono()
                        .foregroundStyle(CorbieColorPalette.text2)
                    PrimaryButton(title: String(localized: "tasks.map.openinmaps")) {
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
                    Button("common.action.done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func openInMaps() {
        guard let coordinate = task.coordinate else { return }
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = task.placeName ?? task.title
        mapItem.openInMaps()
    }
}

#if DEBUG
#Preview {
    TasksMapView(
        tasks: [
            TaskDTO(
                id: UUID(),
                title: "Time Out Market",
                placeName: "Time Out Market",
                address: "Av. 24 de Julho, Lisbon",
                lat: 38.7067,
                lon: -9.1459
            )
        ],
        color: { _ in MemberColorKey.p1.color },
        name: { _ in "you" }
    )
}
#endif
