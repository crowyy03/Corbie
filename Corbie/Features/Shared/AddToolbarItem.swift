import SwiftUI

struct AddToolbarItem: ToolbarContent {
    let action: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: action) {
                Image(systemName: "plus")
            }
            .accessibilityLabel(Text("common.action.add"))
        }
    }
}
