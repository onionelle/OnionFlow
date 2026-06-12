import SwiftUI

// notch-style 外轮廓。核心约束是顶部贴边、两侧 inward shoulder、底部连续圆角。
struct NotchIslandShape: InsettableShape {
    var shoulderRadius: CGFloat
    var bottomRadius: CGFloat
    private var insetAmount: CGFloat = 0

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(shoulderRadius, bottomRadius) }
        set {
            shoulderRadius = newValue.first
            bottomRadius = newValue.second
        }
    }

    init(shoulderRadius: CGFloat, bottomRadius: CGFloat) {
        self.shoulderRadius = shoulderRadius
        self.bottomRadius = bottomRadius
    }

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        // 半径和深度都做夹取，避免 compact 宽高较小时曲线自交或退化成普通 capsule。
        let shoulderRadius = min(max(3, shoulderRadius), rect.width * 0.16)
        let bottomRadius = min(max(10, bottomRadius), rect.height / 2)
        let shoulderDepth = min(max(shoulderRadius * 0.84, 5), rect.height - bottomRadius - 6)
        let curveTightness: CGFloat = 0.82

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        // 左右肩部使用镜像曲线；控制点略收紧，让轮廓保持 notch 感而不是圆角矩形。
        path.addCurve(
            to: CGPoint(x: rect.maxX - shoulderRadius, y: rect.minY + shoulderDepth),
            control1: CGPoint(x: rect.maxX - shoulderRadius * 0.82, y: rect.minY),
            control2: CGPoint(x: rect.maxX - shoulderRadius, y: rect.minY + shoulderDepth * curveTightness)
        )
        path.addLine(to: CGPoint(x: rect.maxX - shoulderRadius, y: rect.maxY - bottomRadius))
        path.addCurve(
            to: CGPoint(x: rect.maxX - shoulderRadius - bottomRadius, y: rect.maxY),
            control1: CGPoint(x: rect.maxX - shoulderRadius, y: rect.maxY - bottomRadius * (1 - curveTightness)),
            control2: CGPoint(x: rect.maxX - shoulderRadius - bottomRadius * (1 - curveTightness), y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + shoulderRadius + bottomRadius, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.minX + shoulderRadius, y: rect.maxY - bottomRadius),
            control1: CGPoint(x: rect.minX + shoulderRadius + bottomRadius * (1 - curveTightness), y: rect.maxY),
            control2: CGPoint(x: rect.minX + shoulderRadius, y: rect.maxY - bottomRadius * (1 - curveTightness))
        )
        path.addLine(to: CGPoint(x: rect.minX + shoulderRadius, y: rect.minY + shoulderDepth))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.minY),
            control1: CGPoint(x: rect.minX + shoulderRadius, y: rect.minY + shoulderDepth * curveTightness),
            control2: CGPoint(x: rect.minX + shoulderRadius * 0.82, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> some InsettableShape {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}
