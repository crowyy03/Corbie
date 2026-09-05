import CorbieCore
import SwiftUI

struct ChecklistCard: View {
    let list: ChecklistListDTO

    var body: some View {
        Card {
            HStack(alignment: .top, spacing: CorbieSpacing.s) {
                Image(systemName: list.template.systemImage)
                    .foregroundStyle(CorbieColorPalette.text2)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                    Text(list.title)
                        .corbieBody()
                        .fontWeight(.semibold)
                        .foregroundStyle(CorbieColorPalette.text)
                        .lineLimit(2)
                    if let subtitle = list.subtitle, subtitle.isEmpty == false {
                        Text(subtitle)
                            .corbieCaption()
                            .foregroundStyle(CorbieColorPalette.text2)
                            .lineLimit(1)
                    }
                    Text(progressText)
                        .corbieMono()
                        .foregroundStyle(CorbieColorPalette.text2)
                }
                Spacer(minLength: 0)
                if list.isPinnedShopping {
                    Image(systemName: "pin")
                        .foregroundStyle(CorbieColorPalette.text2)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    private var progressText: String {
        String(format: PlansCopy.text("lists.card.progress"), list.checkedCount, list.itemCount)
    }
}

#Preview {
    VStack(spacing: CorbieSpacing.m) {
        ChecklistCard(
            list: ChecklistListDTO(
                id: UUID(),
                title: "Shopping",
                template: .shopping,
                isPinnedShopping: true,
                itemCount: 8,
                checkedCount: 3
            )
        )
        ChecklistCard(
            list: ChecklistListDTO(
                id: UUID(),
                title: "Places to go",
                subtitle: "Lisbon, this fall",
                template: .places,
                itemCount: 12,
                checkedCount: 4
            )
        )
    }
    .padding(CorbieSpacing.l)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(CorbieColorPalette.bg)
}
