import SwiftUI

// Canvas 绘制的高清萌系太妃糖色柴犬（Sleepy Puppy）；
// 具备渐变垂耳、发光金铃铛、粉色舌头以及微重力漂浮呼吸效果。
struct SleepCapsuleMascotView: View {
    let state: MascotState
    let size: CGFloat

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, canvasSize in
                drawFrame(context: &context, size: canvasSize, date: timeline.date)
            }
        }
        .frame(width: size, height: size)
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

    // --- 1. IDLE 状态（休眠/慵懒打盹） ---
    private func drawIdle(context: inout GraphicsContext, t: Double, cx: CGFloat, cy: CGFloat) {
        let floatY = sin(t * 1.5) * 0.7
        let breath = 0.985 + 0.015 * sin(t * 1.5)
        
        var bodyCtx = context
        bodyCtx.translateBy(x: cx, y: cy + floatY)
        bodyCtx.scaleBy(x: breath, y: breath)
        bodyCtx.translateBy(x: -cx, y: -(cy + floatY))
        
        let curCY = cy + floatY

        drawEars(context: &bodyCtx, cx: cx, cy: curCY, sway: sin(t * 1.5) * 0.05)
        drawBodyFrame(context: &bodyCtx, cx: cx, cy: curCY, t: t, state: .idle)
        drawFace(context: &bodyCtx, cx: cx, cy: curCY, open: false, state: .idle)
        
        // 睡眠 Z 符号上浮
        drawZs(context: &context, t: t, originX: cx + 11, originY: curCY - 6)
    }

    // --- 2. WORKING 状态（欢快摇摆/精力充沛） ---
    private func drawWorking(context: inout GraphicsContext, t: Double, cx: CGFloat, cy: CGFloat) {
        let bounceY = abs(sin(t * 3.5)) * 1.2
        let curCY = cy - bounceY
        
        // 头部轻微点头晃动
        let lean = sin(t * 7.0) * 0.04
        
        var bodyCtx = context
        bodyCtx.translateBy(x: cx, y: curCY)
        bodyCtx.rotate(by: Angle(radians: Double(lean)))
        bodyCtx.translateBy(x: -cx, y: -curCY)

        drawEars(context: &bodyCtx, cx: cx, cy: curCY, sway: sin(t * 7.0) * 0.12)
        drawBodyFrame(context: &bodyCtx, cx: cx, cy: curCY, t: t, state: .working)
        drawFace(context: &bodyCtx, cx: cx, cy: curCY, open: true, state: .working)
        
        // 顶部工作 Loading
        drawLoadingDots(context: &context, t: t, cx: cx, topY: curCY - 13)
    }

    // --- 3. MUSIC 状态（摇头欢歌/可爱吐舌） ---
    private func drawMusic(context: inout GraphicsContext, t: Double, cx: CGFloat, cy: CGFloat) {
        let bounceY = abs(sin(t * 4.2)) * 1.6
        let curCY = cy - bounceY
        
        let lean = sin(t * 4.2) * 0.06
        
        var bodyCtx = context
        bodyCtx.translateBy(x: cx, y: curCY)
        bodyCtx.rotate(by: Angle(radians: Double(lean)))
        bodyCtx.translateBy(x: -cx, y: -curCY)

        drawEars(context: &bodyCtx, cx: cx, cy: curCY, sway: cos(t * 4.2) * 0.16)
        drawBodyFrame(context: &bodyCtx, cx: cx, cy: curCY, t: t, state: .music)
        drawFace(context: &bodyCtx, cx: cx, cy: curCY, open: MascotMusicNotesEffect.isEyeOpen(t: t, seed: 1), state: .music)
        
        MascotMusicNotesEffect.draw(context: &context, t: t, cx: cx, cy: curCY)
    }

    // ==========================================
    // ============= 柴犬组件绘制 =============
    // ==========================================

    // 1. 双侧垂耳
    private func drawEars(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat, sway: Double) {
        let leftEarColor = Color(red: 0.58, green: 0.32, blue: 0.18)
        let rightEarColor = Color(red: 0.52, green: 0.28, blue: 0.14)
        
        // 左耳：带微旋转的圆角矩形
        var leftCtx = context
        let leftRect = CGRect(x: cx - 11.2, y: cy - 6.5, width: 4.0, height: 8.5)
        let leftPath = Path(roundedRect: leftRect, cornerRadius: 2.0)
        leftCtx.translateBy(x: cx - 9.2, y: cy - 4.5)
        leftCtx.rotate(by: Angle(radians: -0.15 + sway))
        leftCtx.translateBy(x: -(cx - 9.2), y: -(cy - 4.5))
        leftCtx.fill(leftPath, with: .color(leftEarColor))
        
        // 右耳
        var rightCtx = context
        let rightRect = CGRect(x: cx + 7.2, y: cy - 6.5, width: 4.0, height: 8.5)
        let rightPath = Path(roundedRect: rightRect, cornerRadius: 2.0)
        rightCtx.translateBy(x: cx + 9.2, y: cy - 4.5)
        rightCtx.rotate(by: Angle(radians: 0.15 - sway))
        rightCtx.translateBy(x: -(cx + 9.2), y: -(cy - 4.5))
        rightCtx.fill(rightPath, with: .color(rightEarColor))
    }

    // 2. 身体、领圈与小金铃铛
    private func drawBodyFrame(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat, t: Double, state: MascotState) {
        let outline = Color(red: 0.05, green: 0.05, blue: 0.07)
        let dogBodyColor = Color(red: 0.85, green: 0.55, blue: 0.35)
        let bellyColor = Color(red: 0.98, green: 0.95, blue: 0.90)
        
        // A. 柴犬主头部舱体
        let rect = CGRect(x: cx - 8.5, y: cy - 7.5, width: 17, height: 13.5)
        let path = Path(roundedRect: rect, cornerRadius: 5.5)
        context.stroke(path, with: .color(outline), lineWidth: 0.8)
        
        let dogGrad = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [dogBodyColor, dogBodyColor.opacity(0.88), Color(red: 0.72, green: 0.42, blue: 0.24)]),
            startPoint: CGPoint(x: cx - 8.5, y: cy - 7.5),
            endPoint: CGPoint(x: cx + 8.5, y: cy + 6)
        )
        context.fill(path, with: dogGrad)
        
        // B. 脸颊两旁的白毛花纹区
        let leftCheek = Path(ellipseIn: CGRect(x: cx - 7.5, y: cy + 0.5, width: 6.0, height: 5.0))
        let rightCheek = Path(ellipseIn: CGRect(x: cx + 1.5, y: cy + 0.5, width: 6.0, height: 5.0))
        context.fill(leftCheek, with: .color(bellyColor.opacity(0.92)))
        context.fill(rightCheek, with: .color(bellyColor.opacity(0.92)))

        // C. 红色项圈
        let collarRect = CGRect(x: cx - 6.0, y: cy + 5.2, width: 12.0, height: 1.8)
        let collarPath = Path(roundedRect: collarRect, cornerRadius: 0.5)
        context.fill(collarPath, with: .color(Color(red: 0.88, green: 0.20, blue: 0.20)))
        
        // D. 发光黄铜小铃铛
        let bellY = cy + 6.6
        let bellRect = CGRect(x: cx - 1.5, y: bellY - 1.5, width: 3.0, height: 3.0)
        let bellPath = Path(ellipseIn: bellRect)
        
        let bellColor = Color(red: 1.0, green: 0.78, blue: 0.15)
        var bellCtx = context
        let glowRadius: CGFloat = state == .idle ? 1.0 : (state == .working ? 2.0 : 1.5 + CGFloat(abs(sin(t * 5.0)) * 2.0))
        bellCtx.addFilter(.shadow(color: bellColor.opacity(0.8), radius: glowRadius, x: 0, y: 0))
        bellCtx.fill(bellPath, with: .color(bellColor))
    }

    // 3. 脸部（嘴巴、鼻头、黑眼圈）与吐舌头
    private func drawFace(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat, open: Bool, state: MascotState) {
        let leftEyeX = cx - 3.8
        let rightEyeX = cx + 3.8
        let eyeY = cy - 2.5
        
        let outlineColor = Color(red: 0.05, green: 0.05, blue: 0.07)
        let tongueColor = Color(red: 0.98, green: 0.44, blue: 0.54)
        
        // A. 眼睛
        if open {
            // 睁眼：灵动的大黑球 + 微小白高光
            let size: CGFloat = 2.4
            let leftEye = Path(ellipseIn: CGRect(x: leftEyeX - size / 2, y: eyeY - size / 2, width: size, height: size))
            let rightEye = Path(ellipseIn: CGRect(x: rightEyeX - size / 2, y: eyeY - size / 2, width: size, height: size))
            
            context.fill(leftEye, with: .color(outlineColor))
            context.fill(rightEye, with: .color(outlineColor))
            
            // 高光
            let hlSize: CGFloat = 0.7
            context.fill(Path(ellipseIn: CGRect(x: leftEyeX - 0.7, y: eyeY - 0.7, width: hlSize, height: hlSize)), with: .color(.white))
            context.fill(Path(ellipseIn: CGRect(x: rightEyeX - 0.7, y: eyeY - 0.7, width: hlSize, height: hlSize)), with: .color(.white))
        } else {
            // 眯眼：两道弯曲的细月牙
            let ew: CGFloat = 2.4
            let eh: CGFloat = 1.0
            context.fill(Path(roundedRect: CGRect(x: leftEyeX - ew / 2, y: eyeY - eh / 2, width: ew, height: eh), cornerRadius: 0.4), with: .color(outlineColor.opacity(0.82)))
            context.fill(Path(roundedRect: CGRect(x: rightEyeX - ew / 2, y: eyeY - eh / 2, width: ew, height: eh), cornerRadius: 0.4), with: .color(outlineColor.opacity(0.82)))
        }
        
        // B. 白色嘴巴鼻头基底
        let snoutRect = CGRect(x: cx - 2.6, y: cy - 0.8, width: 5.2, height: 4.2)
        context.fill(Path(roundedRect: snoutRect, cornerRadius: 1.8), with: .color(.white))
        
        // C. 小黑狗鼻头
        let noseRect = CGRect(x: cx - 1.1, y: cy - 0.6, width: 2.2, height: 1.5)
        context.fill(Path(ellipseIn: noseRect), with: .color(outlineColor))
        
        // D. 嘴巴与吐舌头（仅在音乐模式下欢快吐舌，其余时间为小微笑）
        if state == .music {
            // 吐出的小粉舌头
            let tongueRect = CGRect(x: cx - 1.2, y: cy + 1.6, width: 2.4, height: 3.4)
            let tonguePath = Path(roundedRect: tongueRect, cornerRadius: 1.2)
            context.fill(tonguePath, with: .color(tongueColor))
            // 舌头中间的压痕细线
            let line = Path(CGRect(x: cx - 0.3, y: cy + 1.8, width: 0.6, height: 2.0))
            context.fill(line, with: .color(outlineColor.opacity(0.18)))
        } else {
            // 极细的小微笑人字线
            let mouthRect = CGRect(x: cx - 1.2, y: cy + 1.5, width: 2.4, height: 0.8)
            context.fill(Path(roundedRect: mouthRect, cornerRadius: 0.4), with: .color(outlineColor.opacity(0.65)))
        }
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
