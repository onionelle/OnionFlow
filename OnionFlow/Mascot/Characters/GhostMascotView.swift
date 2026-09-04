import SwiftUI

// Canvas 绘制的高清萌系半透明蓝色小幽灵（Translucent Boo）；
// 具备数学正弦波实时流动的底边裙摆、发光高斯害羞红晕、浮空幽灵双手与果冻透明渐变。
struct GhostMascotView: View {
    let state: MascotState
    let size: CGFloat
    var isStatic: Bool = false

    var body: some View {
        MascotRenderedCanvas(size: size, isStatic: isStatic, state: state, idleAmplitude: 1.2) { context, canvasSize, date in
            drawFrame(context: &context, size: canvasSize, date: date)
        }
    }

    private func drawFrame(
        context: inout GraphicsContext,
        size: CGSize,
        date: Date
    ) {
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

    // --- 1. IDLE 状态（轻柔漂浮/安静水母） ---
    private func drawIdle(context: inout GraphicsContext, t: Double, cx: CGFloat, cy: CGFloat) {
        // 较大幅度但缓慢（1.5 弧度/秒）的浮沉
        let floatY = sin(t * 1.4) * 1.2
        let breath = 0.97 + 0.03 * sin(t * 1.4)
        
        var bodyCtx = context
        bodyCtx.translateBy(x: cx, y: cy + floatY)
        bodyCtx.scaleBy(x: breath, y: breath)
        bodyCtx.translateBy(x: -cx, y: -(cy + floatY))
        
        let curCY = cy + floatY

        drawGhostBody(context: &bodyCtx, cx: cx, cy: curCY, t: t, state: .idle)
        drawFace(context: &bodyCtx, cx: cx, cy: curCY, open: false, state: .idle)
        
        // Z 睡眠气泡
        drawZs(context: &context, t: t, originX: cx + 11, originY: curCY - 6)
    }

    // --- 2. WORKING 状态（张牙舞爪/调皮捣蛋） ---
    private func drawWorking(context: inout GraphicsContext, t: Double, cx: CGFloat, cy: CGFloat) {
        let bounceY = abs(sin(t * 3.5)) * 1.5
        let curCY = cy - bounceY
        
        let lean = sin(t * 8.0) * 0.04
        
        var bodyCtx = context
        bodyCtx.translateBy(x: cx, y: curCY)
        bodyCtx.rotate(by: Angle(radians: Double(lean)))
        bodyCtx.translateBy(x: -cx, y: -curCY)

        drawGhostBody(context: &bodyCtx, cx: cx, cy: curCY, t: t, state: .working)
        drawFace(context: &bodyCtx, cx: cx, cy: curCY, open: true, state: .working)
        
        // 顶部 Loading 点
        drawLoadingDots(context: &context, t: t, cx: cx, topY: curCY - 13)
    }

    // --- 3. MUSIC 状态（快乐扭动/音浪穿透） ---
    private func drawMusic(context: inout GraphicsContext, t: Double, cx: CGFloat, cy: CGFloat) {
        let bounceY = abs(sin(t * 4.5)) * 1.8
        let curCY = cy - bounceY
        
        // 快乐地左右疯狂摇扭扭（波浪式旋转）
        let lean = sin(t * 6.0) * 0.08
        
        var bodyCtx = context
        bodyCtx.translateBy(x: cx, y: curCY)
        bodyCtx.rotate(by: Angle(radians: Double(lean)))
        bodyCtx.translateBy(x: -cx, y: -curCY)

        drawGhostBody(context: &bodyCtx, cx: cx, cy: curCY, t: t, state: .music)
        drawFace(context: &bodyCtx, cx: cx, cy: curCY, open: MascotMusicNotesEffect.isEyeOpen(t: t, seed: 4), state: .music)
        
        MascotMusicNotesEffect.draw(context: &context, t: t, cx: cx, cy: curCY)
    }

    // ==========================================
    // ============= 幽灵组件绘制 =============
    // ==========================================

    // 1. 半透明水母流动身体 + 双手
    private func drawGhostBody(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat, t: Double, state: MascotState) {
        let outlineColor = Color(red: 0.04, green: 0.05, blue: 0.08)
        let glowColor = Color(red: 0.70, green: 0.90, blue: 1.0)
        
        // A. 建立幽灵身体矢量路径：顶部圆弧穹顶，底部 3 段数学正弦波波动裙摆
        var path = Path()
        let topRadius: CGFloat = 8.5
        let headCenterY = cy - 3.5
        
        path.move(to: CGPoint(x: cx - topRadius, y: headCenterY))
        // 顶部半圆穹顶
        path.addArc(center: CGPoint(x: cx, y: headCenterY), radius: topRadius, startAngle: .radians(.pi), endAngle: .radians(0), clockwise: false)
        // 右侧身体线下滑
        path.addLine(to: CGPoint(x: cx + topRadius, y: cy + 6.0))
        
        // 基于时间 t 的正弦裙摆摆动
        let freq = state == .music ? 14.0 : (state == .working ? 9.0 : 4.5)
        let amp = state == .music ? 2.2 : (state == .working ? 1.6 : 1.0)
        let w1 = sin(t * freq) * amp
        let w2 = sin(t * freq + 2.0) * amp
        let w3 = sin(t * freq + 4.0) * amp
        
        // 从右到左绘制 3 组波浪曲线
        path.addQuadCurve(to: CGPoint(x: cx + 3.0, y: cy + 6.0), control: CGPoint(x: cx + 5.75, y: cy + 6.0 + w1))
        path.addQuadCurve(to: CGPoint(x: cx - 3.0, y: cy + 6.0), control: CGPoint(x: cx, y: cy + 6.0 + w2))
        path.addQuadCurve(to: CGPoint(x: cx - topRadius, y: cy + 6.0), control: CGPoint(x: cx - 5.75, y: cy + 6.0 + w3))
        path.closeSubpath()
        
        // B. 描边与填充（白色到科技淡蓝的极致透明果冻渐变）
        context.stroke(path, with: .color(outlineColor.opacity(0.65)), lineWidth: 0.6)
        
        let ghostGrad = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [
                Color.white.opacity(0.88),
                Color(red: 0.94, green: 0.97, blue: 1.0).opacity(0.72),
                Color(red: 0.76, green: 0.88, blue: 1.0).opacity(0.38)
            ]),
            startPoint: CGPoint(x: cx, y: cy - 12),
            endPoint: CGPoint(x: cx, y: cy + 8)
        )
        
        var bodyCtx = context
        bodyCtx.addFilter(.shadow(color: glowColor.opacity(0.38), radius: 2.0, x: 0, y: 0))
        bodyCtx.fill(path, with: ghostGrad)
        
        // C. 绘制幽灵左、右浮空双手（在前台轻柔挥舞）
        let armFloat = sin(t * freq * 0.8) * (state == .idle ? 0.8 : 1.8)
        
        // 左手
        let leftHandRect = CGRect(x: cx - 11.2, y: cy - 2.2 + armFloat, width: 3.5, height: 2.4)
        let leftHandPath = Path(ellipseIn: leftHandRect)
        context.fill(leftHandPath, with: .color(Color.white.opacity(0.82)))
        context.stroke(leftHandPath, with: .color(outlineColor.opacity(0.25)), lineWidth: 0.5)
        
        // 右手
        let rightHandRect = CGRect(x: cx + 7.7, y: cy - 2.2 - armFloat, width: 3.5, height: 2.4)
        let rightHandPath = Path(ellipseIn: rightHandRect)
        context.fill(rightHandPath, with: .color(Color.white.opacity(0.82)))
        context.stroke(rightHandPath, with: .color(outlineColor.opacity(0.25)), lineWidth: 0.5)
    }

    // 2. 害羞红晕与五官
    private func drawFace(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat, open: Bool, state: MascotState) {
        let leftEyeX = cx - 3.8
        let rightEyeX = cx + 3.8
        let eyeY = cy - 2.8
        
        let outlineColor = Color(red: 0.04, green: 0.05, blue: 0.08)
        let cheekColor = Color(red: 0.98, green: 0.44, blue: 0.62)
        
        // A. 绘制两颊的粉红微光害羞红晕（腮红）
        let cheekL = CGRect(x: leftEyeX - 2.4, y: eyeY + 1.2, width: 2.6, height: 1.6)
        let cheekR = CGRect(x: rightEyeX - 0.2, y: eyeY + 1.2, width: 2.6, height: 1.6)
        
        var cheekCtx = context
        cheekCtx.addFilter(.shadow(color: cheekColor.opacity(0.65), radius: 1.2, x: 0, y: 0))
        cheekCtx.fill(Path(ellipseIn: cheekL), with: .color(cheekColor.opacity(0.35)))
        cheekCtx.fill(Path(ellipseIn: cheekR), with: .color(cheekColor.opacity(0.35)))
        
        // B. 眼睛
        if open {
            // 睁开眼：萌萌圆眼 + 白高光
            let size: CGFloat = 2.4
            let leftEye = Path(ellipseIn: CGRect(x: leftEyeX - size / 2, y: eyeY - size / 2, width: size, height: size))
            let rightEye = Path(ellipseIn: CGRect(x: rightEyeX - size / 2, y: eyeY - size / 2, width: size, height: size))
            
            context.fill(leftEye, with: .color(outlineColor.opacity(0.92)))
            context.fill(rightEye, with: .color(outlineColor.opacity(0.92)))
            
            let hlSize: CGFloat = 0.6
            context.fill(Path(ellipseIn: CGRect(x: leftEyeX - 0.6, y: eyeY - 0.6, width: hlSize, height: hlSize)), with: .color(.white))
            context.fill(Path(ellipseIn: CGRect(x: rightEyeX - 0.6, y: eyeY - 0.6, width: hlSize, height: hlSize)), with: .color(.white))
        } else {
            // 闭眼：小细弯月牙
            let ew: CGFloat = 2.2
            let eh: CGFloat = 0.8
            context.fill(Path(roundedRect: CGRect(x: leftEyeX - ew / 2, y: eyeY - eh / 2, width: ew, height: eh), cornerRadius: 0.4), with: .color(outlineColor.opacity(0.72)))
            context.fill(Path(roundedRect: CGRect(x: rightEyeX - ew / 2, y: eyeY - eh / 2, width: ew, height: eh), cornerRadius: 0.4), with: .color(outlineColor.opacity(0.72)))
        }
        
        // C. Adorable 惊奇小圆嘴
        let mouthW: CGFloat = 1.8
        let mouthH: CGFloat = state == .working ? 3.0 : 2.2
        let mouthRect = CGRect(x: cx - mouthW / 2, y: cy + 0.2 - mouthH / 2, width: mouthW, height: mouthH)
        context.fill(Path(ellipseIn: mouthRect), with: .color(outlineColor.opacity(0.85)))
    }

    // Z 字符号
    private func drawZs(context: inout GraphicsContext, t: Double, originX: CGFloat, originY: CGFloat) {
        let configs: [(phaseOffset: Double, offsetX: CGFloat, startY: CGFloat, fontSize: CGFloat)] = [
            (0.0, -1.0, originY + 2, 5.0),
            (0.5, 1.8, originY - 1, 4.4),
            (1.0, -2.2, originY - 3, 3.8),
            (1.5, 2.0, originY, 4.1),
            (2.0, 0.4, originY - 5, 3.2),
        ]
        for config in configs {
            let phase = (t + config.phaseOffset).truncatingRemainder(dividingBy: 3.0)
            let progress = phase / 3.0
            let floatUp = progress * 6.0
            let breathY = sin((t + config.phaseOffset) * 2.2) * 0.6
            let driftX = sin((t + config.phaseOffset) * 1.6) * 0.6
            let opacity = max(0.0, 0.88 - progress * 0.8)
            
            let zText = Text("Z")
                .font(.system(size: config.fontSize, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(opacity))
            
            context.draw(zText, at: CGPoint(x: originX + config.offsetX + driftX, y: config.startY - floatUp + breathY))
        }
    }

    // Working Loading 点
    private func drawLoadingDots(context: inout GraphicsContext, t: Double, cx: CGFloat, topY: CGFloat) {
        let count = 3
        let spacing: CGFloat = 3.5
        let dotSize: CGFloat = 1.6
        let startX = cx - CGFloat(count - 1) * spacing / 2

        for i in 0..<count {
            let phase = (t + Double(i) * 0.28).truncatingRemainder(dividingBy: 1.0)
            let opacity = max(0.18, 0.9 * (sin(phase * 2 * .pi) * 0.5 + 0.5))

            let rect = CGRect(
                x: startX + CGFloat(i) * spacing - dotSize / 2,
                y: topY - dotSize / 2,
                width: dotSize,
                height: dotSize
            )
            context.fill(
                Path(ellipseIn: rect),
                with: .color(.white.opacity(opacity))
            )
        }
    }
}
