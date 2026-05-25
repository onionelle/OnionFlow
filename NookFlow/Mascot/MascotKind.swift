// 角色类型使用 String rawValue 存进 AppStorage；不要随意改 rawValue，避免破坏用户设置。
enum MascotKind: String, CaseIterable {
    case sleepCapsule
    case robot
    case cat
    case ghost
    case noodle
    case birb
    case moai

    var displayName: String {
        switch self {
        case .sleepCapsule: return "小狗"
        case .robot:        return "小机器人"
        case .cat:          return "小猫"
        case .ghost:        return "鬼魂"
        case .noodle:       return "小羊"
        case .birb:         return "小鸟"
        case .moai:         return "木头人"
        }
    }
}
