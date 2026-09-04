import SwiftUI

// Mascot 动画统一分发入口；新增角色时只在这里和 MascotKind 增加映射。
struct MascotView: View {
    let kind: MascotKind
    let state: MascotState
    let size: CGFloat
    let isStatic: Bool

    init(kind: MascotKind, state: MascotState, size: CGFloat = 32, isStatic: Bool = false) {
        self.kind = kind
        self.state = state
        self.size = size
        self.isStatic = isStatic
    }

    var body: some View {
        switch kind {
        case .ghost:        GhostMascotView(state: state, size: size, isStatic: isStatic)
        case .pixelGhost:   PixelGhostMascotView(state: state, size: size, isStatic: isStatic)
        case .pixelCrab:    PixelCrabMascotView(state: state, size: size, isStatic: isStatic)
        case .pixelPuppy:   PixelPuppyMascotView(state: state, size: size, isStatic: isStatic)
        }
    }
}
