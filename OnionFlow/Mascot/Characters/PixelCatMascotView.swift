import SwiftUI

/// Canvas 绘制的 8-bit/未来感调试像素猫（Sleek Cyber Cat）；
/// 包含猫耳、发光护目镜、挂件铃铛、机械尾巴与动态打字/听歌起舞动效。
struct PixelCatMascotView: View {
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
        let floatY = sin(t * 1.5) * 0.7
        let curCY = cy + floatY
        let breath = 0.98 + 0.02 * sin(t * 1.5)

        var catCtx = context
        catCtx.translateBy(x: cx, y: curCY)
        catCtx.scaleBy(x: breath, y: breath)
        catCtx.translateBy(x: -cx, y: -curCY)

        drawTail(context: &catCtx, cx: cx, cy: curCY, t: t, state: .idle)
        drawBody(context: &catCtx, cx: cx, cy: curCY)
        drawHead(context: &catCtx, cx: cx, cy: curCY)
        drawEars(context: &catCtx, cx: cx, cy: curCY, t: t)
        drawVisor(context: &catCtx, cx: cx, cy: curCY, t: t, state: .idle)
        drawCollar(context: &catCtx, cx: cx, cy: curCY, t: t)

        drawZs(context: &context, t: t, originX: cx + 10.0, originY: curCY - 8.0)
    }

    private func drawWorking(context: inout GraphicsContext, t: Double, cx: CGFloat, cy: CGFloat) {
        let bounceY = abs(sin(t * 4.0)) * 1.2
        let curCY = cy - bounceY

        var catCtx = context
        catCtx.translateBy(x: cx, y: curCY)
        catCtx.translateBy(x: -cx, y: -curCY)

        drawTail(context: &catCtx, cx: cx, cy: curCY, t: t, state: .working)
        drawBody(context: &catCtx, cx: cx, cy: curCY)
        drawHead(context: &catCtx, cx: cx, cy: curCY)
        drawEars(context: &catCtx, cx: cx, cy: curCY, t: t)
        drawVisor(context: &catCtx, cx: cx, cy: curCY, t: t, state: .working)
        drawCollar(context: &catCtx, cx: cx, cy: curCY, t: t)

        drawPixelLoading(context: &context, t: t, cx: cx, topY: curCY - 13.0)
    }

    private func drawMusic(context: inout GraphicsContext, t: Double, cx: CGFloat, cy: CGFloat) {
        let bounceY = abs(sin(t * 5.0)) * 1.8
        let curCY = cy - bounceY
        let rotationAngle = sin(t * 5.0) * 0.1

        var catCtx = context
        catCtx.translateBy(x: cx, y: curCY)
        catCtx.rotate(by: Angle(radians: rotationAngle))
        catCtx.translateBy(x: -cx, y: -curCY)

        drawTail(context: &catCtx, cx: cx, cy: curCY, t: t, state: .music)
        drawBody(context: &catCtx, cx: cx, cy: curCY)
        drawHead(context: &catCtx, cx: cx, cy: curCY)
        drawEars(context: &catCtx, cx: cx, cy: curCY, t: t)
        drawVisor(context: &catCtx, cx: cx, cy: curCY, t: t, state: .music)
        drawCollar(context: &catCtx, cx: cx, cy: curCY, t: t)

        MascotMusicNotesEffect.draw(context: &context, t: t, cx: cx, cy: curCY)
    }

    // === 核心部件绘制 ===

    private func drawBody(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat) {
        let rect = CGRect(x: cx - 6.5, y: cy + 4.5, width: 13.0, height: 7.0)
        let path = Path(roundedRect: rect, cornerRadius: 2.0)
        let bodyGrad = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [
                Color(red: 0.98, green: 0.72, blue: 0.54),
                Color(red: 0.98, green: 0.58, blue: 0.36)
            ]),
            startPoint: CGPoint(x: cx - 6.5, y: cy + 4.5),
            endPoint: CGPoint(x: cx + 6.5, y: cy + 11.5)
        )
        context.fill(path, with: bodyGrad)
    }

    private func drawHead(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat) {
        let rect = CGRect(x: cx - 9.0, y: cy - 8.5, width: 18.0, height: 13.0)
        let path = Path(roundedRect: rect, cornerRadius: 4.5)
        let headGrad = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [
                Color(red: 0.98, green: 0.72, blue: 0.54),
                Color(red: 0.98, green: 0.58, blue: 0.36)
            ]),
            startPoint: CGPoint(x: cx - 9.0, y: cy - 8.5),
            endPoint: CGPoint(x: cx + 9.0, y: cy + 4.5)
        )
        context.fill(path, with: headGrad)
    }

    private func drawEars(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat, t: Double) {
        // 左耳
        var leftEar = Path()
        leftEar.move(to: CGPoint(x: cx - 8.5, y: cy - 8.0))
        leftEar.addLine(to: CGPoint(x: cx - 9.5, y: cy - 13.5))
        leftEar.addLine(to: CGPoint(x: cx - 3.5, y: cy - 8.0))
        leftEar.closeSubpath()
        context.fill(leftEar, with: .color(Color(red: 0.98, green: 0.58, blue: 0.36)))

        // 右耳
        var rightEar = Path()
        rightEar.move(to: CGPoint(x: cx + 8.5, y: cy - 8.0))
        rightEar.addLine(to: CGPoint(x: cx + 9.5, y: cy - 13.5))
        rightEar.addLine(to: CGPoint(x: cx + 3.5, y: cy - 8.0))
        rightEar.closeSubpath()
        context.fill(rightEar, with: .color(Color(red: 0.98, green: 0.58, blue: 0.36)))

        // 内耳发光
        let innerGlow = Color(red: 0.98, green: 0.40, blue: 0.50)
        var leftInner = Path()
        leftInner.move(to: CGPoint(x: cx - 7.5, y: cy - 8.0))
        leftInner.addLine(to: CGPoint(x: cx - 8.5, y: cy - 12.0))
        leftInner.addLine(to: CGPoint(x: cx - 4.5, y: cy - 8.0))
        leftInner.closeSubpath()
        context.fill(leftInner, with: .color(innerGlow))

        var rightInner = Path()
        rightInner.move(to: CGPoint(x: cx + 7.5, y: cy - 8.0))
        rightInner.addLine(to: CGPoint(x: cx + 8.5, y: cy - 12.0))
        rightInner.addLine(to: CGPoint(x: cx + 4.5, y: cy - 8.0))
        rightInner.closeSubpath()
        context.fill(rightInner, with: .color(innerGlow))
    }

    private func drawVisor(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat, t: Double, state: MascotState) {
        let rect = CGRect(x: cx - 7.0, y: cy - 5.5, width: 14.0, height: 7.0)
        let path = Path(roundedRect: rect, cornerRadius: 2.0)
        
        let visorGrad = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [
                Color(red: 0.08, green: 0.08, blue: 0.12),
                Color(red: 0.15, green: 0.15, blue: 0.22)
            ]),
            startPoint: CGPoint(x: cx - 7.0, y: cy - 5.5),
            endPoint: CGPoint(x: cx + 7.0, y: cy + 1.5)
        )
        context.fill(path, with: visorGrad)

        // 绘制霓虹双眼 (或者智能发光线)
        let glowColor = Color(red: 0.98, green: 0.58, blue: 0.36) // 蜜桃橘
        var glowCtx = context
        glowCtx.addFilter(.shadow(color: glowColor, radius: 1.0, x: 0, y: 0))

        if state == .idle {
            // 细线闭眼/眯眼
            let leftEye = Path(CGRect(x: cx - 5.0, y: cy - 2.5, width: 3.0, height: 1.2))
            let rightEye = Path(CGRect(x: cx + 2.0, y: cy - 2.5, width: 3.0, height: 1.2))
            glowCtx.fill(leftEye, with: .color(glowColor))
            glowCtx.fill(rightEye, with: .color(glowColor))
        } else if state == .working {
            // 单像素大眼闪动
            let leftEye = Path(CGRect(x: cx - 5.0, y: cy - 3.5, width: 3.0, height: 3.0))
            let rightEye = Path(CGRect(x: cx + 2.0, y: cy - 3.5, width: 3.0, height: 3.0))
            glowCtx.fill(leftEye, with: .color(glowColor))
            glowCtx.fill(rightEye, with: .color(glowColor))
        } else {
            // 倒V字开心眼
            var leftEye = Path()
            leftEye.move(to: CGPoint(x: cx - 5.0, y: cy - 1.5))
            leftEye.addLine(to: CGPoint(x: cx - 3.5, y: cy - 3.5))
            leftEye.addLine(to: CGPoint(x: cx - 2.0, y: cy - 1.5))
            var rightEye = Path()
            rightEye.move(to: CGPoint(x: cx + 2.0, y: cy - 1.5))
            rightEye.addLine(to: CGPoint(x: cx + 3.5, y: cy - 3.5))
            rightEye.addLine(to: CGPoint(x: cx + 5.0, y: cy - 1.5))
            glowCtx.stroke(leftEye, with: .color(glowColor), lineWidth: 1.2)
            glowCtx.stroke(rightEye, with: .color(glowColor), lineWidth: 1.2)
        }
    }

    private func drawCollar(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat, t: Double) {
        // 项圈
        let collar = Path(CGRect(x: cx - 7.0, y: cy + 3.5, width: 14.0, height: 1.5))
        context.fill(collar, with: .color(Color(red: 0.88, green: 0.24, blue: 0.24)))

        // 挂件金铃铛
        let bellColor = Color(red: 0.98, green: 0.82, blue: 0.20)
        let bell = Path(ellipseIn: CGRect(x: cx - 1.5, y: cy + 4.5, width: 3.0, height: 3.0))
        var glowCtx = context
        glowCtx.addFilter(.shadow(color: bellColor, radius: 1.0, x: 0, y: 0))
        glowCtx.fill(bulb: bell, with: bellColor)
    }

    private func drawTail(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat, t: Double, state: MascotState) {
        // 尾巴摆动曲线
        let scale = (state == .music) ? 2.5 : ((state == .working) ? 1.8 : 1.0)
        let offset = sin(t * (state == .music ? 6.0 : 3.0)) * 2.0 * scale
        
        var tailPath = Path()
        tailPath.move(to: CGPoint(x: cx + 5.5, y: cy + 9.5))
        tailPath.addQuadCurve(
            to: CGPoint(x: cx + 11.5 + offset, y: cy + 6.0),
            control: CGPoint(x: cx + 9.0 + offset/2, y: cy + 11.5)
        )
        context.stroke(
            tailPath,
            with: .color(Color(red: 0.98, green: 0.58, blue: 0.36)),
            style: StrokeStyle(lineWidth: 1.6, lineCap: .round)
        )
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

extension GraphicsContext {
    fileprivate func fill(bulb: Path, with color: Color) {
        self.fill(bulb, with: .color(color))
    }
}
