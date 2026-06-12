import SwiftUI

/// Canvas 绘制的 8-bit/未来感终端蛙（Sleek Cyber Frog）；
/// 包含凸起大圆眼、发光充气歌袋、折叠蛙腿与动态歌袋起伏/大跳弹跳动效。
struct PixelFrogMascotView: View {
    let state: MascotState
    let size: CGFloat
    var isStatic: Bool = false

    var body: some View {
        if isStatic {
            Canvas { context, canvasSize in
                drawFrame(context: &context, size: canvasSize, date: Date(timeIntervalSinceReferenceDate: 0))
            }
            .frame(width: size, height: size)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                Canvas { context, canvasSize in
                    drawFrame(context: &context, size: canvasSize, date: timeline.date)
                }
            }
            .frame(width: size, height: size)
        }
    }

    private func drawFrame(context: inout GraphicsContext, size: CGSize, date: Date) {
        let t = date.timeIntervalSinceReferenceDate
        let cx = size.width / 2
        let cy = size.height / 2

        switch state {
        case .idle:
            drawIdle(context: &context, t: t, cx: cx, cy: cy)
        case .working:
            drawWorking(context: &context, t: t, cx: cx, cy: cy)
        case .music:
            drawMusic(context: &context, t: t, cx: cx, cy: cy)
        }
    }

    private func drawIdle(context: inout GraphicsContext, t: Double, cx: CGFloat, cy: CGFloat) {
        let floatY = sin(t * 1.5) * 0.5
        let curCY = cy + floatY
        let breath = 0.98 + 0.02 * sin(t * 1.5)

        var frogCtx = context
        frogCtx.translateBy(x: cx, y: curCY)
        frogCtx.scaleBy(x: breath, y: breath)
        frogCtx.translateBy(x: -cx, y: -curCY)

        drawBody(context: &frogCtx, cx: cx, cy: curCY)
        drawPouch(context: &frogCtx, cx: cx, cy: curCY, t: t, state: .idle)
        drawEyes(context: &frogCtx, cx: cx, cy: curCY)
        drawLegs(context: &frogCtx, cx: cx, cy: curCY, t: t, state: .idle)

        drawZs(context: &context, t: t, originX: cx + 10.0, originY: curCY - 7.0)
    }

    private func drawWorking(context: inout GraphicsContext, t: Double, cx: CGFloat, cy: CGFloat) {
        let bounceY = abs(sin(t * 4.5)) * 0.8
        let curCY = cy - bounceY

        var frogCtx = context
        frogCtx.translateBy(x: cx, y: curCY)
        frogCtx.translateBy(x: -cx, y: -curCY)

        drawBody(context: &frogCtx, cx: cx, cy: curCY)
        drawPouch(context: &frogCtx, cx: cx, cy: curCY, t: t, state: .working)
        drawEyes(context: &frogCtx, cx: cx, cy: curCY)
        drawLegs(context: &frogCtx, cx: cx, cy: curCY, t: t, state: .working)

        drawPixelLoading(context: &context, t: t, cx: cx, topY: curCY - 13.0)
    }

    private func drawMusic(context: inout GraphicsContext, t: Double, cx: CGFloat, cy: CGFloat) {
        // 大跳跃起伏
        let bounceY = abs(sin(t * 4.8)) * 2.2
        let curCY = cy - bounceY
        let scaleY = 1.0 + max(0.0, sin(t * 4.8)) * 0.15

        var frogCtx = context
        frogCtx.translateBy(x: cx, y: curCY)
        frogCtx.scaleBy(x: 1.0, y: scaleY)
        frogCtx.translateBy(x: -cx, y: -curCY)

        drawBody(context: &frogCtx, cx: cx, cy: curCY)
        drawPouch(context: &frogCtx, cx: cx, cy: curCY, t: t, state: .music)
        drawEyes(context: &frogCtx, cx: cx, cy: curCY)
        drawLegs(context: &frogCtx, cx: cx, cy: curCY, t: t, state: .music)

        MascotMusicNotesEffect.draw(context: &context, t: t, cx: cx, cy: curCY)
    }

    // === 核心部件绘制 ===

    private func drawBody(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat) {
        // 绿绿扁扁的青蛙身躯
        let rect = CGRect(x: cx - 8.5, y: cy - 4.5, width: 17.0, height: 13.0)
        let path = Path(roundedRect: rect, cornerRadius: 4.8)
        let bodyGrad = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [
                Color(red: 0.28, green: 0.88, blue: 0.58),
                Color(red: 0.18, green: 0.78, blue: 0.48)
            ]),
            startPoint: CGPoint(x: cx - 8.5, y: cy - 4.5),
            endPoint: CGPoint(x: cx + 8.5, y: cy + 8.5)
        )
        context.fill(path, with: bodyGrad)
    }

    private func drawEyes(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat) {
        // 顶部两只大凸起眼睛
        let leftEyeRect = CGRect(x: cx - 6.5, y: cy - 8.0, width: 4.5, height: 4.5)
        let rightEyeRect = CGRect(x: cx + 2.0, y: cy - 8.0, width: 4.5, height: 4.5)
        let leftPath = Path(ellipseIn: leftEyeRect)
        let rightPath = Path(ellipseIn: rightEyeRect)
        
        let eyeGrad = Color(red: 0.18, green: 0.78, blue: 0.48)
        context.fill(leftPath, with: .color(eyeGrad))
        context.fill(rightPath, with: .color(eyeGrad))

        // 大黑眼珠
        let leftBlack = Path(ellipseIn: CGRect(x: cx - 5.5, y: cy - 7.5, width: 2.5, height: 3.5))
        let rightBlack = Path(ellipseIn: CGRect(x: cx + 3.0, y: cy - 7.5, width: 2.5, height: 3.5))
        context.fill(leftBlack, with: .color(Color(red: 0.08, green: 0.08, blue: 0.12)))
        context.fill(rightBlack, with: .color(Color(red: 0.08, green: 0.08, blue: 0.12)))

        // 眼神光
        let leftHighlight = Path(ellipseIn: CGRect(x: cx - 4.8, y: cy - 7.0, width: 1.0, height: 1.2))
        let rightHighlight = Path(ellipseIn: CGRect(x: cx + 3.7, y: cy - 7.0, width: 1.0, height: 1.2))
        context.fill(leftHighlight, with: .color(.white))
        context.fill(rightHighlight, with: .color(.white))
    }

    private func drawPouch(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat, t: Double, state: MascotState) {
        // 薄荷青色的发光歌袋 (喉囊)
        let pouchColor = Color(red: 0.18, green: 0.88, blue: 0.68)
        
        let scale: CGFloat
        if state == .music {
            scale = 1.0 + abs(sin(t * 8.0)) * 0.25
        } else if state == .working {
            scale = 1.0 + abs(sin(t * 6.0)) * 0.12
        } else {
            scale = 1.0 + abs(sin(t * 2.0)) * 0.08
        }

        let rect = CGRect(
            x: cx - 5.0 * scale,
            y: cy - 1.5,
            width: 10.0 * scale,
            height: 7.0 * scale
        )
        let path = Path(ellipseIn: rect)
        
        var glowCtx = context
        glowCtx.addFilter(.shadow(color: pouchColor, radius: 1.2, x: 0, y: 0))
        glowCtx.fill(path, with: .color(pouchColor))
        
        // 绘制微小的微笑弧线
        var mouth = Path()
        mouth.move(to: CGPoint(x: cx - 2.5, y: cy - 2.0))
        mouth.addQuadCurve(to: CGPoint(x: cx + 2.5, y: cy - 2.0), control: CGPoint(x: cx, y: cy - 0.5))
        context.stroke(mouth, with: .color(Color(red: 0.08, green: 0.08, blue: 0.12)), lineWidth: 1.0)
    }

    private func drawLegs(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat, t: Double, state: MascotState) {
        let legColor = Color(red: 0.18, green: 0.78, blue: 0.48)
        
        if state == .music && sin(t * 4.8) > 0.0 {
            // 跳跃中伸直的大长腿
            let leftLeg = Path(CGRect(x: cx - 7.5, y: cy + 8.5, width: 2.0, height: 4.5))
            let rightLeg = Path(CGRect(x: cx + 5.5, y: cy + 8.5, width: 2.0, height: 4.5))
            context.fill(leftLeg, with: .color(legColor))
            context.fill(rightLeg, with: .color(legColor))
        } else {
            // 蹲着缩起来的肥脚
            let leftLeg = Path(ellipseIn: CGRect(x: cx - 9.5, y: cy + 6.0, width: 3.0, height: 4.0))
            let rightLeg = Path(ellipseIn: CGRect(x: cx + 6.5, y: cy + 6.0, width: 3.0, height: 4.0))
            context.fill(leftLeg, with: .color(legColor))
            context.fill(rightLeg, with: .color(legColor))
        }
    }

    // === 辅助粒子效果 ===

    private func drawZs(context: inout GraphicsContext, t: Double, originX: CGFloat, originY: CGFloat) {
        let configs: [(phaseOffset: Double, offsetX: CGFloat, startY: CGFloat)] = [
            (0.0, 0.0, originY),
            (1.0, 2.0, originY - 2.5),
            (2.0, -1.5, originY - 5.0),
        ]
        for config in configs {
            let phase = (t + config.phaseOffset).truncatingRemainder(dividingBy: 3.0)
            let progress = phase / 3.0
            let floatUp = progress * 7.0
            let driftX = sin((t + config.phaseOffset) * 1.5) * 0.4
            let opacity = max(0.0, 0.8 - progress * 0.8)
            let zText = Text("Z").font(.system(size: 4.2, weight: .black, design: .monospaced)).foregroundStyle(.white.opacity(opacity))
            context.draw(zText, at: CGPoint(x: originX + config.offsetX + driftX, y: config.startY - floatUp))
        }
    }

    private func drawPixelLoading(context: inout GraphicsContext, t: Double, cx: CGFloat, topY: CGFloat) {
        let count = 3
        let spacing: CGFloat = 3.0
        let dotSize: CGFloat = 1.3
        let startX = cx - CGFloat(count - 1) * spacing / 2
        for i in 0..<count {
            let phase = (t + Double(i) * 0.28).truncatingRemainder(dividingBy: 1.0)
            let opacity = max(0.15, 0.92 * (sin(phase * 2 * .pi) * 0.5 + 0.5))
            let rect = CGRect(x: startX + CGFloat(i) * spacing - dotSize / 2, y: topY - dotSize / 2, width: dotSize, height: dotSize)
            context.fill(Path(rect), with: .color(.white.opacity(opacity)))
        }
    }
}
