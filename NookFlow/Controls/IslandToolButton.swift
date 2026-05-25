import SwiftUI

// 顶栏工具按钮的统一视觉封装；业务动作由调用方传入。
struct IslandToolButton: View {
    @State private var isHovered = false
    let systemName: String
    let title: String
    var isActive = false
    let action: () -> Void
    private let buttonSize: CGFloat = 22
    private let iconSize: CGFloat = 10.5
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(isActive ? Color.white : Color.white.opacity(0.74))
                .frame(width: buttonSize, height: buttonSize)
                .background(
                    Circle()
                        .fill(buttonBackgroundColor)
                )
                .overlay(
                    Circle()
                        .stroke(buttonStrokeColor, lineWidth: isHovered ? 0.8 : 0.5)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .frame(width: buttonSize, height: buttonSize)
        .help(title)
        .accessibilityLabel(Text(title))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }

    private var buttonBackgroundColor: Color {
        // 激活态和 hover 态使用同一套尺寸，只改变颜色，避免 compact 顶栏抖动。
        if isActive {
            return Color.white.opacity(isHovered ? 0.30 : 0.18)
        }
        return Color.white.opacity(isHovered ? 0.22 : 0.08)
    }
    private var buttonStrokeColor: Color {
        Color.white.opacity(isHovered ? 0.34 : (isActive ? 0.20 : 0.10))
    }
}
