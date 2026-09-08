import CorbieCore
import SwiftUI

struct ChoreListBuilderView: View {
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var model: ChoreListBuilderViewModel

    private let copy = ChoreCopy()

    init(model: ChoreListBuilderViewModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CorbieSpacing.l) {
                header
                ForEach(model.groups, id: \.self) { group in
                    section(group)
                }
                custom
            }
            .padding(.horizontal, CorbieSpacing.l)
            .padding(.vertical, CorbieSpacing.m)
        }
        .scrollDismissesKeyboard(.immediately)
        .safeAreaInset(edge: .bottom) { footer }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
            Text("chore.builder.header")
                .corbieBody()
                .fontWeight(.semibold)
                .foregroundStyle(palette.text)
                .fixedSize(horizontal: false, vertical: true)
            Text("chore.builder.note")
                .corbieMono()
                .foregroundStyle(palette.text2)
        }
    }

    private var columns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return Array(
            repeating: GridItem(.flexible(), spacing: CorbieSpacing.xs, alignment: .top),
            count: count
        )
    }

    private func section(_ group: ChoreGroup) -> some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
            SectionCaps(text: String(localized: String.LocalizationValue(group.titleKey)))
            LazyVGrid(columns: columns, spacing: CorbieSpacing.xs) {
                ForEach(model.catalogItems(in: group)) { item in
                    catalogChip(item)
                }
            }
            addField(group)
        }
    }

    private func catalogChip(_ item: ChoreCatalogItem) -> some View {
        let isIncluded = model.isIncluded(item)
        let frequency = model.frequency(of: item)
        return ChoreChip(
            title: model.title(of: item),
            frequency: copy.frequency(frequency),
            isSelected: isIncluded
        ) {
            Task { await model.toggle(item) }
        }
        .contextMenu {
            if model.isInTheList(item) {
                frequencyButtons(current: frequency) { choice in
                    Task { await model.setFrequency(choice, of: item) }
                }
            }
        }
    }

    private var custom: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
            if model.customItems.isEmpty == false {
                SectionCaps(text: String(localized: "chore.builder.custom.caps"))
                LazyVGrid(columns: columns, spacing: CorbieSpacing.xs) {
                    ForEach(model.customItems) { item in
                        customChip(item)
                    }
                }
            }
        }
    }

    private func customChip(_ item: ChoreItemDTO) -> some View {
        ChoreChip(
            title: item.title,
            frequency: copy.frequency(item.frequency),
            isSelected: item.isIncluded
        ) {
            Task { await model.toggle(item) }
        }
        .contextMenu {
            frequencyButtons(current: item.frequency) { choice in
                Task { await model.setFrequency(choice, of: item) }
            }
            Button(role: .destructive) {
                Task { await model.remove(item) }
            } label: {
                Label("chore.builder.remove", systemImage: "trash")
            }
        }
    }

    private func frequencyButtons(
        current: ChoreFrequency,
        pick: @escaping (ChoreFrequency) -> Void
    ) -> some View {
        ForEach(ChoreFrequency.allCases, id: \.self) { choice in
            Button {
                pick(choice)
            } label: {
                if choice == current {
                    Label(copy.frequency(choice), systemImage: "checkmark")
                } else {
                    Text(copy.frequency(choice))
                }
            }
        }
    }

    private func draft(for group: ChoreGroup) -> Binding<String> {
        Binding(
            get: { model.drafts[group.rawValue] ?? "" },
            set: { model.drafts[group.rawValue] = $0 }
        )
    }

    private func addField(_ group: ChoreGroup) -> some View {
        HStack(spacing: CorbieSpacing.xs) {
            TextField(
                String(localized: "chore.builder.add.placeholder"),
                text: draft(for: group)
            )
            .textFieldStyle(.plain)
            .corbieBody()
            .foregroundStyle(palette.text)
            .submitLabel(.done)
            .onSubmit { Task { await model.addCustom(in: group) } }
            .padding(.horizontal, CorbieSpacing.s)
            .frame(minHeight: CorbieMetrics.minimumTapTarget)
            .corbieFieldBox()
            .accessibilityLabel(Text("chore.builder.add.placeholder"))

            Button {
                Task { await model.addCustom(in: group) }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(palette.text)
                    .frame(width: CorbieMetrics.minimumTapTarget, height: CorbieMetrics.minimumTapTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text("common.action.add"))
        }
    }

    private var footer: some View {
        VStack(spacing: CorbieSpacing.xs) {
            Text(
                model.canContinue
                    ? String.localizedStringWithFormat(
                        String(localized: "chore.builder.count"),
                        model.includedCount
                    )
                    : String.localizedStringWithFormat(
                        String(localized: "chore.builder.more"),
                        model.missingCount
                    )
            )
            .corbieMono()
            .foregroundStyle(palette.text2)
            PrimaryButton(title: String(localized: "chore.builder.continue")) {
                Task { await model.startRating() }
            }
            .disabled(model.canContinue == false)
        }
        .padding(.horizontal, CorbieSpacing.l)
        .padding(.vertical, CorbieSpacing.s)
        .background(palette.bg)
    }
}

private struct ChoreChip: View {
    @Environment(\.palette) private var palette

    let title: String
    let frequency: String
    let isSelected: Bool
    let action: () -> Void

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: CorbieRadius.field, style: .continuous)
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                Text(title)
                    .corbieCaption()
                    .fontWeight(.semibold)
                    .foregroundStyle(palette.text)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(frequency)
                    .corbieMono()
                    .foregroundStyle(palette.text2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, CorbieSpacing.s)
            .padding(.vertical, CorbieSpacing.xs)
            .frame(minHeight: CorbieMetrics.minimumTapTarget)
            .background {
                ZStack {
                    shape.fill(palette.surface)
                    if isSelected {
                        shape.fill(palette.accent).opacity(0.12)
                    }
                }
            }
            .overlay(
                shape.strokeBorder(
                    isSelected ? palette.accent : palette.border,
                    lineWidth: isSelected ? 2 : CorbieMetrics.hairline
                )
            )
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
