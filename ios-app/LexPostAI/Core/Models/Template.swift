import Foundation

struct Template: Codable, Identifiable {
    let id: String
    let name: String
    let theme: String
    let backgroundUrl: String?
    let previewUrl: String?
    let sortOrder: Int
    let isPro: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, theme
        case backgroundUrl = "background_url"
        case previewUrl = "preview_url"
        case sortOrder = "sort_order"
        case isPro = "is_pro"
    }

    var themeLabel: String {
        switch theme {
        case "law": return "Hukuk"
        case "office": return "Ofis"
        case "minimalist": return "Minimalist"
        default: return theme.capitalized
        }
    }
}

