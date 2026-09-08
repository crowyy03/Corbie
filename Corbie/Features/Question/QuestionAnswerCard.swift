import CorbieCore
import SwiftUI

struct QuestionAnswerCard: View {
    @Environment(\.palette) private var palette
    let name: String
    let slot: MemberColorSlot?
    let answer: QuestionAnswerDTO?
    let stamp: String?
    let placeholder: String?

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
                HStack(spacing: CorbieSpacing.xs) {
                    MemberDot(slot: slot)
                    Text(name)
                        .corbieBody()
                        .fontWeight(.semibold)
                        .foregroundStyle(palette.text)
                    Spacer(minLength: CorbieSpacing.xs)
                    if let stamp {
                        Text(stamp)
                            .corbieMono()
                            .foregroundStyle(palette.text2)
                    }
                }
                if let text = answer?.text {
                    Text(text)
                        .corbieBody()
                        .foregroundStyle(palette.text)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                } else if let placeholder {
                    Text(placeholder)
                        .corbieMono()
                        .foregroundStyle(palette.text2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if answer?.isEdited == true {
                    Text("question.answer.edited")
                        .corbieMono()
                        .foregroundStyle(palette.text2)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
