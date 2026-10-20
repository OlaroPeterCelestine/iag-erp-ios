import SwiftUI

enum SystemTheme {
    static func symbol(for id: String) -> String {
        switch id {
        case "admin": return "person.badge.key"
        case "erp-api": return "server.rack"
        case "finance": return "banknote"
        case "erp": return "square.grid.2x2.fill"
        case "auditor": return "checkmark.seal"
        case "hr": return "person.3"
        case "inventory": return "shippingbox"
        case "procurement": return "cart"
        case "fleet": return "truck.box"
        case "logistics": return "arrow.left.arrow.right"
        case "distribution": return "box.truck"
        case "contract-manager": return "doc.text"
        case "project-manager": return "chart.bar"
        case "crm": return "person.crop.circle"
        case "production": return "gearshape.2"
        case "maintenance": return "wrench.and.screwdriver"
        case "lab": return "testtube.2"
        case "farmer-traceability": return "leaf"
        case "security": return "shield"
        case "pos": return "storefront"
        default: return "square.grid.2x2"
        }
    }

    static func tint(for id: String) -> Color {
        switch id {
        case "admin": return Color(hex: 0x334155)
        case "erp-api": return Color(hex: 0x0F766E)
        case "finance": return Color(hex: 0x0B6E4F)
        case "erp": return Color(hex: 0x1D4E89)
        case "auditor": return Color(hex: 0x7C3A6B)
        case "hr": return Color(hex: 0x9A3412)
        case "inventory": return Color(hex: 0x0369A1)
        case "procurement": return Color(hex: 0xA16207)
        case "fleet": return Color(hex: 0x155E75)
        case "logistics": return Color(hex: 0x1E40AF)
        case "distribution": return Color(hex: 0x3F6212)
        case "contract-manager": return Color(hex: 0x6D28D9)
        case "project-manager": return Color(hex: 0x0E7490)
        case "crm": return Color(hex: 0xBE185D)
        case "production": return Color(hex: 0xC2410C)
        case "maintenance": return Color(hex: 0x57534E)
        case "lab": return Color(hex: 0x6D28D9)
        case "farmer-traceability": return Color(hex: 0x3F6212)
        case "security": return Color(hex: 0x1E293B)
        case "pos": return Color(hex: 0x9F1239)
        default: return Color(hex: 0x0B6E4F)
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
