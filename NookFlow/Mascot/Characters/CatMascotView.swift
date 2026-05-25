import SwiftUI

// Canvas 绘制的高清萌系奶油橘猫（Cozy Neko）；
// 具备渐变大粉耳、发光双瞳（音乐模式下瞳孔随节拍缩放）、物理摇摆胡须与微型红色蝴蝶结。
struct CatMascotView: View {
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

    // --- 1. IDLE 状态（打盹小憩） ---
    private func drawIdle(context: inout GraphicsContext, t: Double, cx: CGFloat, cy: CGFloat) {
        let floatY = sin(t * 1.3) * 0.6
        let breath = 0.975 + 0.025 * sin(t * 1.6)
        
        var bodyCtx = context
        bodyCtx.translateBy(x: cx, y: cy + floatY)
        bodyCtx.scaleBy(x: breath, y: breath)
        bodyCtx.translateBy(x: -cx, y: -(cy + floatY))
        
        let curCY = cy + floatY

        drawEars(context: &bodyCtx, cx: cx, cy: curCY, t: t, state: .idle)
        drawBodyFrame(context: &bodyCtx, cx: cx, cy: curCY)
        drawFace(context: &bodyCtx, cx: cx, cy: curCY, open: false, t: t, state: .idle)
        drawWhiskers(context: &bodyCtx, cx: cx, cy: curCY, sway: sin(t * 2.0) * 0.4)
        
        // 睡眠 Z 符号
        drawZs(context: &context, t: t, originX: cx + 10, originY: curCY - 6)
    }

    // --- 2. WORKING 状态（专注抓弄/好奇满满） ---
    private func drawWorking(context: inout GraphicsContext, t: Double, cx: CGFloat, cy: CGFloat) {
        let bounceY = abs(sin(t * 3.5)) * 1.3
        let curCY = cy - bounceY
        
        let lean = sin(t * 7.5) * 0.05
        
        var bodyCtx = context
        bodyCtx.translateBy(x: cx, y: curCY)
        bodyCtx.rotate(by: Angle(radians: Double(lean)))
        bodyCtx.translateBy(x: -cx, y: -curCY)

        drawEars(context: &bodyCtx, cx: cx, cy: curCY, t: t, state: .working)
        drawBodyFrame(context: &bodyCtx, cx: cx, cy: curCY)
        drawFace(context: &bodyCtx, cx: cx, cy: curCY, open: true, t: t, state: .working)
        drawWhiskers(context: &bodyCtx, cx: cx, cy: curCY, sway: sin(t * 8.0) * 0.8)
        
        // 顶部工作 Loading
        drawLoadingDots(context: &context, t: t, cx: cx, topY: curCY - 13)
    }

    // --- 3. MUSIC 状态（摇头欢歌/电眼律动） ---
    private func drawMusic(context: inout GraphicsContext, t: Double, cx: CGFloat, cy: CGFloat) {
        let bounceY = abs(sin(t * 4.0)) * 1.8
        let curCY = cy - bounceY
        
        let lean = sin(t * 4.0) * 0.08
        
        var bodyCtx = context
        bodyCtx.translateBy(x: cx, y: curCY)
        bodyCtx.rotate(by: Angle(radians: Double(lean)))
        bodyCtx.translateBy(x: -cx, y: -curCY)

        drawEars(context: &bodyCtx, cx: cx, cy: curCY, t: t, state: .music)
        drawBodyFrame(context: &bodyCtx, cx: cx, cy: curCY)
        drawFace(context: &bodyCtx, cx: cx, cy: curCY, open: MascotMusicNotesEffect.isEyeOpen(t: t, seed: 3), t: t, state: .music)
        drawWhiskers(context: &bodyCtx, cx: cx, cy: curCY, sway: sin(t * 12.0) * 1.2)
        
        MascotMusicNotesEffect.draw(context: &context, t: t, cx: cx, cy: curCY)
    }

    // ==========================================
    // ============= 橘猫组件绘制 =============
    // ==========================================

    // 1. 三角粉嫩猫耳
    private func drawEars(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat, t: Double, state: MascotState) {
        let earBaseColor = Color(red: 0.82, green: 0.50, blue: 0.30)
        let earInnerColor = Color(red: 0.98, green: 0.65, blue: 0.65)
        
        // 慢动耳朵微颤
        let earSway = state == .music ? sin(t * 10.0) * 0.06 : (state == .working ? sin(t * 6.0) * 0.03 : 0.0)

        // 左耳
        var leftPath = Path()
        leftPath.move(to: CGPoint(x: cx - 9.0, y: cy - 3.5))
        leftPath.addLine(to: CGPoint(x: cx - 8.5 + CGFloat(earSway * 8.0), y: cy - 11.5))
        leftPath.addLine(to: CGPoint(x: cx - 3.0, y: cy - 7.0))
        leftPath.closeSubpath()
        context.fill(leftPath, with: .color(earBaseColor))
        
        var leftInner = Path()
        leftInner.move(to: CGPoint(x: cx - 8.0, y: cy - 4.5))
        leftInner.addLine(to: CGPoint(x: cx - 7.5 + CGFloat(earSway * 6.0), y: cy - 10.0))
        leftInner.addLine(to: CGPoint(x: cx - 4.0, y: cy - 6.5))
        leftInner.closeSubpath()
        context.fill(leftInner, with: .color(earInnerColor))
        
        // 右耳
        var rightPath = Path()
        rightPath.move(to: CGPoint(x: cx + 9.0, y: cy - 3.5))
        rightPath.addLine(to: CGPoint(x: cx + 8.5 - CGFloat(earSway * 8.0), y: cy - 11.5))
        rightPath.addLine(to: CGPoint(x: cx + 3.0, y: cy - 7.0))
        rightPath.closeSubpath()
        context.fill(rightPath, with: .color(earBaseColor))
        
        var rightInner = Path()
        rightInner.move(to: CGPoint(x: cx + 8.0, y: cy - 4.5))
        rightInner.addLine(to: CGPoint(x: cx + 7.5 - CGFloat(earSway * 6.0), y: cy - 10.0))
        rightInner.addLine(to: CGPoint(x: cx + 4.0, y: cy - 6.5))
        rightInner.closeSubpath()
        context.fill(rightInner, with: .color(earInnerColor))
    }

    // 2. 猫咪身体舱体与红色小领结
    private func drawBodyFrame(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat) {
        let outlineColor = Color(red: 0.05, green: 0.04, blue: 0.04)
        let catBodyColor = Color(red: 0.94, green: 0.66, blue: 0.45)
        let whiteChestColor = Color(red: 0.98, green: 0.96, blue: 0.94)
        
        // A. 橘猫主脸庞舱体
        let rect = CGRect(x: cx - 9.0, y: cy - 7.0, width: 18.0, height: 13.0)
        let path = Path(roundedRect: rect, cornerRadius: 5.5)
        context.stroke(path, with: .color(outlineColor), lineWidth: 0.8)
        
        let bodyGrad = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [catBodyColor, Color(red: 0.88, green: 0.54, blue: 0.30)]),
            startPoint: CGPoint(x: cx - 9, y: cy - 7),
            endPoint: CGPoint(x: cx + 9, y: cy + 6)
        )
        context.fill(path, with: bodyGrad)
        
        // B. 嘴部和胸口白毛花纹区
        let whiteSnout = Path(ellipseIn: CGRect(x: cx - 2.8, y: cy + 1.2, width: 5.6, height: 4.0))
        context.fill(whiteSnout, with: .color(whiteChestColor.opacity(0.92)))
        
        // C. 红色小蝴蝶结
        let tieColor = Color(red: 0.90, green: 0.18, blue: 0.18)
        let leftKnot = Path(ellipseIn: CGRect(x: cx - 2.8, y: cy + 4.8, width: 2.2, height: 1.8))
        let rightKnot = Path(ellipseIn: CGRect(x: cx + 0.6, y: cy + 4.8, width: 2.2, height: 1.8))
        let centerKnot = Path(ellipseIn: CGRect(x: cx - 0.8, y: cy + 5.0, width: 1.6, height: 1.4))
        
        context.fill(leftKnot, with: .color(tieColor))
        context.fill(rightKnot, with: .color(tieColor))
        context.fill(centerKnot, with: .color(Color.white.opacity(0.9)))
    }

    // 3. 发光猫眼与面部表情
    private func drawFace(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat, open: Bool, t: Double, state: MascotState) {
        let leftEyeX = cx - 3.8
        let rightEyeX = cx + 3.8
        let eyeY = cy - 2.2
        let outlineColor = Color(red: 0.05, green: 0.04, blue: 0.04)
        
        if open {
            // 睁眼：高亮霓虹荧光绿大猫眼（带有瞳孔呼吸收缩）
            let eyeSize: CGFloat = 2.8
            let irisColor = Color(red: 0.62, green: 0.96, blue: 0.12)
            
            // 绘制两个大猫眼（绿莹莹的）
            let leftEyePath = Path(ellipseIn: CGRect(x: leftEyeX - eyeSize / 2, y: eyeY - eyeSize / 2, width: eyeSize, height: eyeSize))
            let rightEyePath = Path(ellipseIn: CGRect(x: rightEyeX - eyeSize / 2, y: eyeY - eyeSize / 2, width: eyeSize, height: eyeSize))
            
            var eyeCtx = context
            eyeCtx.addFilter(.shadow(color: irisColor.opacity(0.6), radius: 1.5, x: 0, y: 0))
            eyeCtx.fill(leftEyePath, with: .color(irisColor))
            eyeCtx.fill(rightEyePath, with: .color(irisColor))
            
            // 绘制瞳孔：音乐模式下随着节拍像真实猫眼一样有弹性的缩放；工作模式为细长的竖瞳
            let pupilW: CGFloat
            if state == .music {
                pupilW = 0.5 + CGFloat(abs(sin(t * 5.0)) * 0.9) // [0.5, 1.4] 动态缩放
            } else {
                pupilW = 0.7 // 保持专注猫咪经典的偏细立瞳
            }
            
            let pupilLeft = Path(roundedRect: CGRect(x: leftEyeX - pupilW / 2, y: eyeY - 1.1, width: pupilW, height: 2.2), cornerRadius: 0.4)
            let pupilRight = Path(roundedRect: CGRect(x: rightEyeX - pupilW / 2, y: eyeY - 1.1, width: pupilW, height: 2.2), cornerRadius: 0.4)
            
            context.fill(pupilLeft, with: .color(outlineColor))
            context.fill(pupilRight, with: .color(outlineColor))
            
            // 猫眼微小白高光
            let hlSize: CGFloat = 0.6
            context.fill(Path(ellipseIn: CGRect(x: leftEyeX - 0.7, y: eyeY - 0.8, width: hlSize, height: hlSize)), with: .color(.white.opacity(0.95)))
            context.fill(Path(ellipseIn: CGRect(x: rightEyeX - 0.7, y: eyeY - 0.8, width: hlSize, height: hlSize)), with: .color(.white.opacity(0.95)))
        } else {
            // 闭眼：小憩时的向上弯曲小月牙
            let ew: CGFloat = 2.5
            let eh: CGFloat = 1.0
            
            let leftArc = Path(roundedRect: CGRect(x: leftEyeX - ew / 2, y: eyeY - eh / 2, width: ew, height: eh), cornerRadius: 0.5)
            let rightArc = Path(roundedRect: CGRect(x: rightEyeX - ew / 2, y: eyeY - eh / 2, width: ew, height: eh), cornerRadius: 0.5)
            
            context.fill(leftArc, with: .color(outlineColor.opacity(0.80)))
            context.fill(rightArc, with: .color(outlineColor.opacity(0.80)))
        }
        
        // 三角粉红小鼻头
        let noseRect = CGRect(x: cx - 0.8, y: cy + 0.5, width: 1.6, height: 1.2)
        context.fill(Path(roundedRect: noseRect, cornerRadius: 0.4), with: .color(Color(red: 0.98, green: 0.52, blue: 0.62)))
    }

    // 4. 4根细胡须
    private func drawWhiskers(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat, sway: Double) {
        let whiskerColor = Color.black.opacity(0.38)
        let whiskerL = cy + 1.2
        let delta = CGFloat(sway)
        
        // 左边两根
        var pathL1 = Path()
        pathL1.move(to: CGPoint(x: cx - 6.5, y: whiskerL - 0.5))
        pathL1.addQuadCurve(to: CGPoint(x: cx - 11.5, y: whiskerL - 1.5 + delta), control: CGPoint(x: cx - 9.0, y: whiskerL - 1.0))
        context.stroke(pathL1, with: .color(whiskerColor), lineWidth: 0.6)
        
        var pathL2 = Path()
        pathL2.move(to: CGPoint(x: cx - 6.5, y: whiskerL + 0.8))
        pathL2.addQuadCurve(to: CGPoint(x: cx - 11.2, y: whiskerL + 1.8 - delta), control: CGPoint(x: cx - 9.0, y: whiskerL + 1.3))
        context.stroke(pathL2, with: .color(whiskerColor), lineWidth: 0.6)
        
        // 右边两根
        var pathR1 = Path()
        pathR1.move(to: CGPoint(x: cx + 6.5, y: whiskerL - 0.5))
        pathR1.addQuadCurve(to: CGPoint(x: cx + 11.5, y: whiskerL - 1.5 - delta), control: CGPoint(x: cx + 9.0, y: whiskerL - 1.0))
        context.stroke(pathR1, with: .color(whiskerColor), lineWidth: 0.6)
        
        var pathR2 = Path()
        pathR2.move(to: CGPoint(x: cx + 6.5, y: whiskerL + 0.8))
        pathR2.addQuadCurve(to: CGPoint(x: cx + 11.2, y: whiskerL + 1.8 + delta), control: CGPoint(x: cx + 9.0, y: whiskerL + 1.3))
        context.stroke(pathR2, with: .color(whiskerColor), lineWidth: 0.6)
    }

    // Z 气泡
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
