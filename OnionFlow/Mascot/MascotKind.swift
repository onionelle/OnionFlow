// 角色类型使用 String rawValue 存进 AppStorage；不要随意改 rawValue，避免破坏用户设置。
enum MascotKind: String, CaseIterable {
    case ghost
    case pixelGhost
    case pixelCrab
    case pixelPuppy

    var displayName: String {
        switch self {
        case .ghost:        return "Ghost"
        case .pixelGhost:   return "Pixel Ghost"
        case .pixelCrab:    return "Pixel Crab"
        case .pixelPuppy:   return "Pixel Puppy"
        }
    }
}
