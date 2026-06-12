import Foundation

/// 灵动岛收起态右侧的频谱动画风格定义
enum SpectrumStyle: String, CaseIterable, Identifiable, Codable {
    case columns
    case wave
    case breathing
    case pulse
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .columns: return "翡翠晶柱"
        case .wave: return "极简声波"
        case .breathing: return "灵动呼吸"
        case .pulse: return "科幻脉冲"
        }
    }
}
