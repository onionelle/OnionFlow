import SwiftUI

/// 10 种不同情感和色调的高保真星云渐变配色预设
enum NebulaTheme: String, CaseIterable, Identifiable {
    case charcoal = "charcoal"  // 深邃暗空 (charcoal slate)
    case indigo = "indigo"      // 靛蓝极光 (classic violet)
    case emerald = "emerald"    // 翡翠幽谷 (aurora green)
    case neon = "neon"          // 霓虹深渊 (magenta cyan)
    case amber = "amber"        // 琥珀晨曦 (warm sunset)
    case rose = "rose"          // 星尘玫瑰 (cosmic rose)
    case glacier = "glacier"    // 冰川冷光 (glacier ice)
    case andromeda = "andromeda"// 仙女星云 (andromeda mint)
    case inferno = "inferno"    // 金星赤焰 (inferno gold)
    case lavender = "lavender"  // 幻境紫罗 (dreamy lavender)

    var id: String { self.rawValue }

    var name: String {
        switch self {
        case .charcoal: return "深邃暗空"
        case .indigo: return "靛蓝极光"
        case .emerald: return "翡翠幽谷"
        case .neon: return "霓虹深渊"
        case .amber: return "琥珀晨曦"
        case .rose: return "星尘玫瑰"
        case .glacier: return "冰川冷光"
        case .andromeda: return "仙女星云"
        case .inferno: return "金星赤焰"
        case .lavender: return "幻境紫罗"
        }
    }

    /// 基础背景纯色
    var baseBackground: Color {
        switch self {
        case .charcoal: return Color(red: 0.025, green: 0.025, blue: 0.035)
        case .indigo: return Color(red: 0.035, green: 0.035, blue: 0.065)
        case .emerald: return Color(red: 0.03, green: 0.05, blue: 0.04)
        case .neon: return Color(red: 0.04, green: 0.03, blue: 0.06)
        case .amber: return Color(red: 0.05, green: 0.03, blue: 0.03)
        case .rose: return Color(red: 0.05, green: 0.03, blue: 0.05)
        case .glacier: return Color(red: 0.02, green: 0.04, blue: 0.06)
        case .andromeda: return Color(red: 0.02, green: 0.02, blue: 0.05)
        case .inferno: return Color(red: 0.05, green: 0.02, blue: 0.02)
        case .lavender: return Color(red: 0.04, green: 0.03, blue: 0.05)
        }
    }

    /// 第一层星云混合圆色
    var color1: Color {
        switch self {
        case .charcoal: return Color(red: 0.08, green: 0.08, blue: 0.12).opacity(0.45)
        case .indigo: return Color(red: 0.12, green: 0.08, blue: 0.26).opacity(0.42)
        case .emerald: return Color(red: 0.06, green: 0.24, blue: 0.16).opacity(0.36)
        case .neon: return Color(red: 0.28, green: 0.06, blue: 0.24).opacity(0.38)
        case .amber: return Color(red: 0.28, green: 0.14, blue: 0.06).opacity(0.38)
        case .rose: return Color(red: 0.28, green: 0.08, blue: 0.16).opacity(0.38)
        case .glacier: return Color(red: 0.06, green: 0.22, blue: 0.28).opacity(0.38)
        case .andromeda: return Color(red: 0.06, green: 0.26, blue: 0.20).opacity(0.38)
        case .inferno: return Color(red: 0.36, green: 0.20, blue: 0.05).opacity(0.38)
        case .lavender: return Color(red: 0.22, green: 0.12, blue: 0.32).opacity(0.38)
        }
    }

    /// 第二层星云混合圆色
    var color2: Color {
        switch self {
        case .charcoal: return Color(red: 0.05, green: 0.05, blue: 0.08).opacity(0.40)
        case .indigo: return Color(red: 0.20, green: 0.06, blue: 0.30).opacity(0.38)
        case .emerald: return Color(red: 0.08, green: 0.20, blue: 0.24).opacity(0.38)
        case .neon: return Color(red: 0.06, green: 0.22, blue: 0.28).opacity(0.38)
        case .amber: return Color(red: 0.24, green: 0.06, blue: 0.08).opacity(0.35)
        case .rose: return Color(red: 0.18, green: 0.06, blue: 0.22).opacity(0.38)
        case .glacier: return Color(red: 0.12, green: 0.28, blue: 0.26).opacity(0.35)
        case .andromeda: return Color(red: 0.16, green: 0.08, blue: 0.28).opacity(0.38)
        case .inferno: return Color(red: 0.30, green: 0.04, blue: 0.06).opacity(0.38)
        case .lavender: return Color(red: 0.32, green: 0.08, blue: 0.24).opacity(0.36)
        }
    }

    /// 用于设置面板微卡片里展示的色块渐变预览色彩
    var previewGradientColors: [Color] {
        switch self {
        case .charcoal:
            return [Color(red: 0.12, green: 0.12, blue: 0.18), Color(red: 0.06, green: 0.06, blue: 0.09)]
        case .indigo:
            return [Color(red: 0.16, green: 0.12, blue: 0.36), Color(red: 0.26, green: 0.10, blue: 0.38)]
        case .emerald:
            return [Color(red: 0.08, green: 0.32, blue: 0.22), Color(red: 0.10, green: 0.26, blue: 0.32)]
        case .neon:
            return [Color(red: 0.36, green: 0.08, blue: 0.32), Color(red: 0.08, green: 0.28, blue: 0.36)]
        case .amber:
            return [Color(red: 0.36, green: 0.18, blue: 0.08), Color(red: 0.30, green: 0.08, blue: 0.10)]
        case .rose:
            return [Color(red: 0.36, green: 0.10, blue: 0.22), Color(red: 0.24, green: 0.08, blue: 0.28)]
        case .glacier:
            return [Color(red: 0.10, green: 0.28, blue: 0.36), Color(red: 0.18, green: 0.36, blue: 0.34)]
        case .andromeda:
            return [Color(red: 0.08, green: 0.32, blue: 0.24), Color(red: 0.20, green: 0.12, blue: 0.36)]
        case .inferno:
            return [Color(red: 0.45, green: 0.26, blue: 0.08), Color(red: 0.36, green: 0.06, blue: 0.08)]
        case .lavender:
            return [Color(red: 0.28, green: 0.16, blue: 0.40), Color(red: 0.38, green: 0.12, blue: 0.30)]
        }
    }
}
