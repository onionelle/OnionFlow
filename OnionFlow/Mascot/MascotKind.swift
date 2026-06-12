// 角色类型使用 String rawValue 存进 AppStorage；不要随意改 rawValue，避免破坏用户设置。
enum MascotKind: String, CaseIterable {
    case robot
    case ghost
    case pixelCrab
    case pixelPuppy
    case pixelCat
    case pixelDino
    case pixelFrog

    var displayName: String {
        switch self {
        case .robot:        return "Robot"
        case .ghost:        return "Ghost"
        case .pixelCrab:    return "Pixel Crab"
        case .pixelPuppy:   return "Pixel Puppy"
        case .pixelCat:     return "Cat"
        case .pixelDino:    return "Dino"
        case .pixelFrog:    return "Frog"
        }
    }
}
