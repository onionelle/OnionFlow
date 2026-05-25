import SwiftUI

// Mascot 动画统一分发入口；新增角色时只在这里和 MascotKind 增加映射。
struct MascotView: View {
    let kind: MascotKind
    let state: MascotState
    let size: CGFloat
    init(kind: MascotKind, state: MascotState, size: CGFloat = 32) {
        self.kind = kind
        self.state = state
        self.size = size
    }

    var body: some View {
        switch kind {
        case .sleepCapsule: SleepCapsuleMascotView(state: state, size: size)
        case .robot:        RobotMascotView(state: state, size: size)
        case .cat:          CatMascotView(state: state, size: size)
        case .ghost:        GhostMascotView(state: state, size: size)
        case .noodle:       NoodleMascotView(state: state, size: size)
        case .birb:         BirbMascotView(state: state, size: size)
        case .moai:         MoaiMascotView(state: state, size: size)
        }
    }
}
