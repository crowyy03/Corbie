import CorbieCore
import SwiftUI

struct ListItemRow: View {
    let item: ListItemDTO
    let addedByColor: Color
    let addedByName: String
    let checkedByColor: Color
    let checkedByName: String?
    let onToggle: () -> Void
    let onOpen: () -> Void

    var body: some View {
        Card {
            HStack(alignment: .top, spacing: CorbieSpacing.xs) {
                checkbox
                details
                MemberDot(color: addedByColor, accessibilityLabel: addedByName)
                    .padding(.top, CorbieSpacing.s)
            }
        }
    }

    private var checkbox: some View {
        Button(action: onToggle) {
            Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                .corbieBody()
                .imageScale(.large)
                .foregroundStyle(item.isChecked ? checkedByColor : CorbieColorPalette.text2)
                .frame(width: CorbieMetrics.minimumTapTarget, height: CorbieMetrics.minimumTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(item.title))
        .accessibilityValue(Text(item.isChecked ? "lists.item.checked" : "lists.item.unchecked"))
    }

    private var details: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                Text(item.title)
                    .corbieBody()
                    .foregroundStyle(item.isChecked ? CorbieColorPalette.text2 : CorbieColorPalette.text)
                    .strikethrough(item.isChecked, color: CorbieColorPalette.text2)
                    .multilineTextAlignment(.leading)
                if let note = item.note, note.isEmpty == false {
                    Text(note)
                        .corbieCaption()
                        .foregroundStyle(CorbieColorPalette.text2)
                        .multilineTextAlignment(.leading)
                }
                if let place = placeLine {
                    HStack(spacing: CorbieSpacing.xxs) {
                        Image(systemName: "mappin")
                            .accessibilityHidden(true)
                        Text(place)
                            .lineLimit(1)
                    }
                    .corbieMono()
                    .foregroundStyle(CorbieColorPalette.text2)
                }
                if item.isChecked, let checkedByName {
                    Text(String(format: PlansCopy.text("lists.item.checkedby"), checkedByName))
                        .corbieMono()
                        .foregroundStyle(CorbieColorPalette.text2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, CorbieSpacing.s)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var placeLine: String? {
        let name = item.placeName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let address = item.address?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let name, name.isEmpty == false { return name }
        if let address, address.isEmpty == false { return address }
        return nil
    }
}

#Preview {
    VStack(spacing: CorbieSpacing.m) {
        ListItemRow(
            item: ListItemDTO(
                id: UUID(),
                title: "Time Out Market",
                note: "the one with the tiles",
                placeName: "Time Out Market",
                address: "Av. 24 de Julho, Lisbon",
                latitude: 38.7,
                longitude: -9.14
            ),
            addedByColor: MemberColorKey.p1.color,
            addedByName: "you",
            checkedByColor: MemberColorKey.p2.color,
            checkedByName: nil,
            onToggle: {},
            onOpen: {}
        )
        ListItemRow(
            item: ListItemDTO(id: UUID(), title: "Milk", isChecked: true),
            addedByColor: MemberColorKey.p2.color,
            addedByName: "Sofia",
            checkedByColor: MemberColorKey.p1.color,
            checkedByName: "you",
            onToggle: {},
            onOpen: {}
        )
    }
    .padding(CorbieSpacing.l)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(CorbieColorPalette.bg)
}
