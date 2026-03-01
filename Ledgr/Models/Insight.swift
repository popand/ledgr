import Foundation
import SwiftUI

struct Insight: Identifiable, Codable {
    let id: UUID
    let title: String
    let description: String
    let icon: String
    let iconColorName: String

    var iconColor: Color {
        switch iconColorName {
        case "success": return .ledgrSuccess
        case "warning": return .ledgrWarning
        case "error": return .ledgrError
        case "primary": return .ledgrPrimary
        default: return .ledgrPrimary
        }
    }

    init(id: UUID = UUID(), title: String, description: String, icon: String, iconColorName: String) {
        self.id = id
        self.title = title
        self.description = description
        self.icon = icon
        self.iconColorName = iconColorName
    }
}
