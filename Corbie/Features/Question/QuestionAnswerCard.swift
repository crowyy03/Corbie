import CorbieCore
import SwiftUI

struct QuestionAnswerCard: View {
    let name: String
    let color: Color
    let answer: QuestionAnswerDTO?
    let stamp: String?
    let placeholder: String?

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
                HStack(spacing: CorbieSpacing.xs) {
                    MemberDot(color: color)
                    Text(name)
                        .corbieBody()
                        .fontWeight(.semibold)
                        .foregroundStyle(CorbieColorPalette.text)
                    Spacer(minLength: CorbieSpacing.xs)
                    if let stamp {
                        Text(stamp)
                            .corbieMono()
                            .foregroundStyle(CorbieColorPalette.text2)
                    }
                }
                if let text = answer?.text {
                    Text(text)
                        .corbieBody()
                        .foregroundStyle(CorbieColorPalette.text)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                } else if let placeholder {
                    Text(placeholder)
                        .corbieMono()
                        .foregroundStyle(CorbieColorPalette.text2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if answer?.isEdited == true {
                    Text("question.answer.edited")
                        .corbieMono()
                        .foregroundStyle(CorbieColorPalette.text2)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
