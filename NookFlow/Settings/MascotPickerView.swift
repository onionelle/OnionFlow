import SwiftUI

/// 支持无边框窗口原生拖动热区的 AppKit 桥接视图。
/// 铺满窗口背景，捕获所有非交互空白区域的鼠标按下动作并触发窗口拖拽，保证极致流畅的手感。
struct WindowDragFinderView: NSViewRepresentable {
    class DragNSView: NSView {
        override var mouseDownCanMoveWindow: Bool {
            true
        }
    }
    
    func makeNSView(context: Context) -> DragNSView {
        let view = DragNSView()
        return view
    }
    
    func updateNSView(_ nsView: DragNSView, context: Context) {}
}

/// Mascot 设置仪表面板。
/// 1. 移除了 ScrollView 剪裁容器，改用完全静态的居中 LazyVGrid（7个角色完美容纳且绝不溢出）。
/// 2. 增加了 28pt 的宽敞边距安全区，保证卡片在 Hover 上浮或缩放时 100% 保留在窗口圆角边框内，彻底消除溢出或硬切问题。
/// 3. 引入 WindowDragFinderView 原生热区，支持点击任意空白、标题栏甚至卡片间距进行顺滑拖拽移动窗口。
struct MascotPickerView: View {
    /// 关闭回调
    let onClose: () -> Void
    
    @AppStorage("mascotKind") private var selectedKindRawValue = "sleepCapsule"
    @State private var hoveredKind: MascotKind? = nil
    
    // 3列精简网格布局
    private let columns = [
        GridItem(.fixed(114), spacing: 14),
        GridItem(.fixed(114), spacing: 14),
        GridItem(.fixed(114), spacing: 14)
    ]
    
    var body: some View {
        ZStack {
            // 1. 面板磨砂背景与星云特效（单独裁剪 16pt，消除锯齿）
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.04, green: 0.04, blue: 0.06).opacity(0.92))
                
                ZStack {
                    Circle()
                        .fill(Color(red: 0.12, green: 0.08, blue: 0.26).opacity(0.32))
                        .frame(width: 260, height: 260)
                        .blur(radius: 50)
                        .offset(x: -100, y: 80)
                    
                    Circle()
                        .fill(Color(red: 0.20, green: 0.06, blue: 0.30).opacity(0.28))
                        .frame(width: 220, height: 220)
                        .blur(radius: 50)
                        .offset(x: 100, y: -80)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .allowsHitTesting(false)
            
            // 2. 原生拖拽热区层（铺满整个背景，空白处的点击事件会自动向上传递至此，触发完美的窗口拖拽）
            WindowDragFinderView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // 3. 内容层（静态排布，四周留出充裕的 Margin，防止 Hover 时超出或被硬性剪裁）
            VStack(spacing: 0) {
                // 自定义头部标题栏
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Mascot Dashboard")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                        
                        Text("Choose an active avatar to accompany your island")
                            .font(.system(size: 10.5, weight: .regular))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    
                    Spacer()
                    
                    // 独立设计的关闭按钮
                    CloseButton(action: onClose)
                }
                .padding(.bottom, 16)
                
                // 3列精美静态网格（去除 ScrollView，以规避其内部强制剪裁行为）
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(MascotKind.allCases, id: \.rawValue) { kind in
                        mascotCard(for: kind)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, 28) // 宽敞的 28pt 左右边距安全区
            .padding(.top, 18)
            .padding(.bottom, 22)
            
            // 4. 极细白光玻璃窗体边框
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
                .allowsHitTesting(false)
        }
        .frame(width: 420, height: 330)
        .clipShape(RoundedRectangle(cornerRadius: 16)) // 全局圆角裁剪，四角完全一致
    }
    
    /// 精巧紧凑的单卡组件 (宽 114, 高 68)
    @ViewBuilder
    private func mascotCard(for kind: MascotKind) -> some View {
        let selected = selectedKindRawValue == kind.rawValue
        let isHovered = hoveredKind == kind
        let themeColor = glowColor(for: kind)
        
        VStack(spacing: 5) {
            // 头像微盒背景 (Mascot 大小优化至超精细 32pt 规格)
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.35))
                    .frame(width: 36, height: 36)
                
                MascotView(kind: kind, state: .idle, size: 32)
                    .frame(width: 30, height: 30)
            }
            .padding(.top, 6)
            
            Text(kind.displayName)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(selected ? themeColor : .white.opacity(0.80))
                .padding(.bottom, 5)
        }
        .frame(width: 114, height: 68)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(selected ? themeColor.opacity(0.08) : Color.white.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    selected ? themeColor.opacity(0.85) : (isHovered ? Color.white.opacity(0.18) : Color.white.opacity(0.08)),
                    lineWidth: selected ? 1.2 : 0.6
                )
        )
        // 选中时亮起对应 Mascot 专属色彩的散射呼吸背光
        .shadow(color: selected ? themeColor.opacity(0.24) : Color.clear, radius: 10, y: 3)
        // 物理悬浮弹跳
        .scaleEffect(isHovered ? 1.04 : 1.0)
        .offset(y: isHovered ? -4 : 0)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            selectedKindRawValue = kind.rawValue
        }
        .onHover { hovering in
            hoveredKind = hovering ? kind : nil
            if hovering {
                NSCursor.arrow.set()
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isHovered)
        .animation(.easeInOut(duration: 0.15), value: selected)
    }
    
    /// Mascot 对应主色调，用于卡片边框、高亮名称和独特的散射阴影
    private func glowColor(for kind: MascotKind) -> Color {
        switch kind {
        case .sleepCapsule:
            return Color(red: 0.98, green: 0.74, blue: 0.18) // 柴犬金黄
        case .robot:
            return Color(red: 0.16, green: 0.82, blue: 0.50) // 霓虹荧光绿
        case .cat:
            return Color(red: 0.95, green: 0.45, blue: 0.32) // 蜜桃橘猫色
        case .ghost:
            return Color(red: 0.68, green: 0.45, blue: 0.90) // 幽暗魔力紫
        case .noodle:
            return Color(red: 0.18, green: 0.68, blue: 0.90) // 云朵天空蓝
        case .birb:
            return Color(red: 0.65, green: 0.88, blue: 0.18) // 荧光柠黄
        case .moai:
            return Color(red: 0.90, green: 0.18, blue: 0.65) // 朋克霓虹粉
        }
    }
}

// 独立高光关闭按钮
private struct CloseButton: View {
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isHovered ? Color(red: 0.95, green: 0.28, blue: 0.28) : Color.white.opacity(0.08))
                    .frame(width: 20, height: 20)
                
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(isHovered ? .white : Color.white.opacity(0.40))
            }
        }
        .buttonStyle(.plain)
        .help("关闭面板")
        .accessibilityLabel("关闭面板")
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.arrow.set()
            }
        }
    }
}
