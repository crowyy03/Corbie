import CorbieCore
import SwiftUI

extension FolderTemplate {
    var systemImage: String {
        switch self {
        case .shopping: return "cart"
        case .watch: return "play.rectangle"
        case .places: return "mappin.and.ellipse"
        case .cities: return "building.2"
        case .empty: return "checklist"
        }
    }

    var title: String {
        switch self {
        case .shopping: return String(localized: "tasks.folder.template.shopping")
        case .watch: return String(localized: "tasks.folder.template.watch")
        case .places: return String(localized: "tasks.folder.template.places")
        case .cities: return String(localized: "tasks.folder.template.cities")
        case .empty: return String(localized: "tasks.folder.template.empty")
        }
    }

    var itemPlaceholder: String {
        switch self {
        case .shopping: return String(localized: "tasks.folder.template.shopping.placeholder")
        case .watch: return String(localized: "tasks.folder.template.watch.placeholder")
        case .places: return String(localized: "tasks.folder.template.places.placeholder")
        case .cities: return String(localized: "tasks.folder.template.cities.placeholder")
        case .empty: return String(localized: "tasks.editor.field.what.placeholder")
        }
    }
}
