import SwiftUI

/// Canvas 绘制的 8-bit/未来感像素恐龙（Sleek Cyber Dino）；
/// 包含背部发光尖刺、T-Rex头部、小短手、踏步双足与动态奔跑/跳跃动效。
struct PixelDinoMascotView: View {
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
        let floatY = sin(t * 1.6) * 0.6
        let curCY = cy + floatY
        let breath = 0.98 + 0.02 * sin(t * 1.6)

        var dinoCtx = context
        dinoCtx.translateBy(x: cx, y: curCY)
        dinoCtx.scaleBy(x: breath, y: breath)
        dinoCtx.translateBy(x: -cx, y: -curCY)

        drawSpikes(context: &dinoCtx, cx: cx, cy: curCY, t: t)
        drawTail(context: &dinoCtx, cx: cx, cy: curCY, t: t, state: .idle)
        drawBody(context: &dinoCtx, cx: cx, cy: curCY)
        drawHead(context: &dinoCtx, cx: cx, cy: curCY)
        drawEye(context: &dinoCtx, cx: cx, cy: curCY, t: t, state: .idle)
        drawArms(context: &dinoCtx, cx: cx, cy: curCY, t: t, state: .idle)
        drawLegs(context: &dinoCtx, cx: cx, cy: curCY, t: t, state: .idle)

        drawZs(context: &context, t: t, originX: cx + 11.0, originY: curCY - 7.0)
    }

    private func drawWorking(context: inout GraphicsContext, t: Double, cx: CGFloat, cy: CGFloat) {
        // 快跑颠簸
        let bounceY = abs(sin(t * 5.0)) * 1.0
        let curCY = cy - bounceY

        var dinoCtx = context
        dinoCtx.translateBy(x: cx, y: curCY)
        dinoCtx.translateBy(x: -cx, y: -curCY)

        drawSpikes(context: &dinoCtx, cx: cx, cy: curCY, t: t)
        drawTail(context: &dinoCtx, cx: cx, cy: curCY, t: t, state: .working)
        drawBody(context: &dinoCtx, cx: cx, cy: curCY)
        drawHead(context: &dinoCtx, cx: cx, cy: curCY)
        drawEye(context: &dinoCtx, cx: cx, cy: curCY, t: t, state: .working)
        drawArms(context: &dinoCtx, cx: cx, cy: curCY, t: t, state: .working)
        drawLegs(context: &dinoCtx, cx: cx, cy: curCY, t: t, state: .working)

        drawPixelLoading(context: &context, t: t, cx: cx, topY: curCY - 13.0)
    }

    private func drawMusic(context: inout GraphicsContext, t: Double, cx: CGFloat, cy: CGFloat) {
        // 配合音乐节奏大跳
        let bounceY = abs(sin(t * 4.5)) * 2.2
        let curCY = cy - bounceY
        let tilt = sin(t * 4.5) * 0.08

        var dinoCtx = context
        dinoCtx.translateBy(x: cx, y: curCY)
        dinoCtx.rotate(by: Angle(radians: tilt))
        dinoCtx.translateBy(x: -cx, y: -curCY)

        drawSpikes(context: &dinoCtx, cx: cx, cy: curCY, t: t)
        drawTail(context: &dinoCtx, cx: cx, cy: curCY, t: t, state: .music)
        drawBody(context: &dinoCtx, cx: cx, cy: curCY)
        drawHead(context: &dinoCtx, cx: cx, cy: curCY)
        drawEye(context: &dinoCtx, cx: cx, cy: curCY, t: t, state: .music)
        drawArms(context: &dinoCtx, cx: cx, cy: curCY, t: t, state: .music)
        drawLegs(context: &dinoCtx, cx: cx, cy: curCY, t: t, state: .music)

        MascotMusicNotesEffect.draw(context: &context, t: t, cx: cx, cy: curCY)
    }

    // === 核心部件绘制 ===

    private func drawBody(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat) {
        // 恐龙大肚子
        let path = Path(roundedRect: CGRect(x: cx - 7.5, y: cy + 1.0, width: 12.0, height: 10.0), cornerRadius: 3.5)
        let grad = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [
                Color(red: 0.35, green: 0.85, blue: 0.45),
                Color(red: 0.22, green: 0.75, blue: 0.36)
            ]),
            startPoint: CGPoint(x: cx - 7.5, y: cy + 1),
            endPoint: CGPoint(x: cx + 4.5, y: cy + 11)
        )
        context.fill(path, with: grad)
    }

    private func drawHead(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat) {
        // T-Rex 的方型大脑袋
        let path = Path(roundedRect: CGRect(x: cx - 4.5, y: cy - 9.0, width: 13.5, height: 11.0), cornerRadius: 3.0)
        let grad = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [
                Color(red: 0.35, green: 0.85, blue: 0.45),
                Color(red: 0.22, green: 0.75, blue: 0.36)
            ]),
            startPoint: CGPoint(x: cx - 4.5, y: cy - 9.0),
            endPoint: CGPoint(x: cx + 9.0, y: cy + 2.0)
        )
        context.fill(path, with: grad)
    }

    private func drawEye(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat, t: Double, state: MascotState) {
        let eyeRect = CGRect(x: cx + 3.0, y: cy - 6.5, width: 3.5, height: 3.5)
        let path = Path(roundedRect: eyeRect, cornerRadius: 1.0)
        let eyeColor = Color(red: 0.98, green: 0.42, blue: 0.15) // 橙色发光眼

        var glowCtx = context
        glowCtx.addFilter(.shadow(color: eyeColor, radius: 1.0, x: 0, y: 0))

        if state == .idle {
            // 眨眼
            let blink = sin(t * 2.0) > 0.85
            if blink {
                let closed = Path(CGRect(x: cx + 3.0, y: cy - 5.0, width: 3.5, height: 1.0))
                glowCtx.fill(closed, with: .color(eyeColor))
            } else {
                glowCtx.fill(path, with: .color(eyeColor))
            }
        } else {
            glowCtx.fill(path, with: .color(eyeColor))
        }
    }

    private func drawSpikes(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat, t: Double) {
        // 背脊刺发光
        let spikeColor = Color(red: 0.98, green: 0.52, blue: 0.15)
        var glowCtx = context
        glowCtx.addFilter(.shadow(color: spikeColor, radius: 1.2, x: 0, y: 0))

        // 绘制三颗三角形背刺
        let positions: [CGPoint] = [
            CGPoint(x: cx - 7.5, y: cy + 1.0),
            CGPoint(x: cx - 5.0, y: cy - 4.0),
            CGPoint(x: cx - 2.0, y: cy - 8.0)
        ]

        for pt in positions {
            var spike = Path()
            spike.move(to: CGPoint(x: pt.x, y: pt.y))
            spike.addLine(to: CGPoint(x: pt.x - 2.5, y: pt.y - 1.5))
            spike.addLine(to: CGPoint(x: pt.x - 1.0, y: pt.y + 1.5))
            spike.closeSubpath()
            glowCtx.fill(spike, with: .color(spikeColor))
        }
    }

    private func drawTail(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat, t: Double, state: MascotState) {
        let amp = (state == .music) ? 2.5 : ((state == .working) ? 1.8 : 0.8)
        let sway = sin(t * (state == .music ? 7.0 : 3.0)) * amp

        var tail = Path()
        tail.move(to: CGPoint(x: cx - 7.0, y: cy + 4.0))
        tail.addQuadCurve(
            to: CGPoint(x: cx - 13.0, y: cy + 7.0 + sway),
            control: CGPoint(x: cx - 11.0, y: cy + 2.0 + sway/2)
        )
        context.stroke(
            tail,
            with: .color(Color(red: 0.22, green: 0.75, blue: 0.36)),
            style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
        )
    }

    private func drawArms(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat, t: Double, state: MascotState) {
        // T-Rex 标志性小短手
        let sway = (state == .idle) ? 0.0 : sin(t * 8.0) * 1.5
        let armRect = CGRect(x: cx + 4.5, y: cy + 2.0 + sway, width: 2.8, height: 1.5)
        context.fill(Path(armRect), with: .color(Color(red: 0.35, green: 0.85, blue: 0.45)))
    }

    private func drawLegs(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat, t: Double, state: MascotState) {
        let color = Color(red: 0.22, green: 0.75, blue: 0.36)
        if state == .idle {
            // 静态脚
            let leftLeg = Path(CGRect(x: cx - 5.5, y: cy + 10.5, width: 2.2, height: 3.0))
            let rightLeg = Path(CGRect(x: cx + 0.5, y: cy + 10.5, width: 2.2, height: 3.0))
            context.fill(leftLeg, with: .color(color))
            context.fill(rightLeg, with: .color(color))
        } else {
            // 奔跑踢腿
            let phase = t * (state == .music ? 10.0 : 8.0)
            let leftOffset = sin(phase) * 2.5
            let rightOffset = -sin(phase) * 2.5
            
            let leftLeg = Path(CGRect(x: cx - 5.5, y: cy + 10.5 + max(0, leftOffset), width: 2.2, height: 3.0 - min(0, leftOffset)))
            let rightLeg = Path(CGRect(x: cx + 0.5, y: cy + 10.5 + max(0, rightOffset), width: 2.2, height: 3.0 - min(0, rightOffset)))
            context.fill(leftLeg, with: .color(color))
            context.fill(rightLeg, with: .color(color))
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
