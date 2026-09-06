import CorbieCore
import SwiftUI

struct PlanStepRow: View {
    let step: PlanStepDTO
    let due: PlanStepDue?
    let assigneeColor: Color?
    let assigneeName: String?
    let isReadOnly: Bool
    let toggle: () -> Void
    let openEditor: () -> Void

    @State private var isNoteShown = false

    private var note: String? {
        guard let note = step.note, note.isEmpty == false else { return nil }
        return note
    }

    private var detailsLabel: String {
        [String(format: String(localized: "plans.step.action.edit"), step.title), assigneeName, due?.text]
            .compactMap { $0 }
            .joined(separator: ", ")
    }

    var body: some View {
        Card {
            HStack(alignment: .top, spacing: CorbieSpacing.xs) {
                checkbox
                details
                if note != nil {
                    noteDisclosure
                }
            }
        }
    }

    private var checkbox: some View {
        Button(action: toggle) {
            Image(systemName: step.isDone ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(step.isDone ? CorbieColorPalette.ice : CorbieColorPalette.text2)
                .frame(minWidth: CorbieMetrics.minimumTapTarget, minHeight: CorbieMetrics.minimumTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isReadOnly)
        .accessibilityLabel(Text(step.title))
        .accessibilityValue(Text(step.isDone ? "tasks.item.checked" : "tasks.item.unchecked"))
    }

    private var details: some View {
        Button(action: openEditor) {
            VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                Text(step.title)
                    .corbieBody()
                    .strikethrough(step.isDone)
                    .foregroundStyle(step.isDone ? CorbieColorPalette.text2 : CorbieColorPalette.text)
                    .multilineTextAlignment(.leading)
                if assigneeColor != nil || due != nil {
                    meta
                }
                if isNoteShown, let note {
                    Text(note)
                        .corbieCaption()
                        .foregroundStyle(CorbieColorPalette.text2)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, minHeight: CorbieMetrics.minimumTapTarget, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isReadOnly)
        .accessibilityLabel(Text(detailsLabel))
    }

    private var meta: some View {
        HStack(spacing: CorbieSpacing.xs) {
            if let assigneeColor {
                MemberDot(color: assigneeColor)
            }
            if let due {
                Text(due.text)
                    .corbieMono()
                    .foregroundStyle(due.isOverdue ? CorbieColorPalette.warn : CorbieColorPalette.text2)
            }
        }
    }

    private var noteDisclosure: some View {
        Button {
            isNoteShown.toggle()
        } label: {
            Image(systemName: isNoteShown ? "chevron.up" : "chevron.down")
                .font(.footnote)
                .foregroundStyle(CorbieColorPalette.text2)
                .frame(minWidth: CorbieMetrics.minimumTapTarget, minHeight: CorbieMetrics.minimumTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            Text(
                isNoteShown
                    ? String(localized: "plans.step.action.note.hide")
                    : String(localized: "plans.step.action.note.show")
            )
        )
    }
}

#if DEBUG
#Preview {
    let dated = PlanStepDTO(
        id: UUID(),
        title: "Collect the documents",
        note: "passports, the booking, the insurance",
        dueAt: Date().addingTimeInterval(-2 * 24 * 60 * 60)
    )
    return VStack(spacing: CorbieSpacing.s) {
        PlanStepRow(
            step: dated,
            due: planStepDue(for: dated, now: Date()),
            assigneeColor: MemberColorKey.p2.color,
            assigneeName: "Sofia",
            isReadOnly: false,
            toggle: {},
            openEditor: {}
        )
        PlanStepRow(
            step: PlanStepDTO(id: UUID(), title: "Drop the suit at the cleaner", isDone: true),
            due: nil,
            assigneeColor: nil,
            assigneeName: nil,
            isReadOnly: false,
            toggle: {},
            openEditor: {}
        )
    }
    .padding(CorbieSpacing.l)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(CorbieColorPalette.bg)
}
#endif
