import CorbieCore
import SwiftUI

struct CurrencyChoices: View {
    let groups: [[String]]

    var body: some View {
        ForEach(groups, id: \.self) { group in
            Section {
                ForEach(group, id: \.self) { code in
                    Text(verbatim: SupportedCurrencies.label(of: code, in: .current)).tag(code)
                }
            }
        }
    }
}
