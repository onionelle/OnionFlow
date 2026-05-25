import SwiftUI

// Canvas 绘制的高清萌系胖胖小鸟（Chubby Birb）；
// 具备渐变球形身体、独立扑棱翅膀（高频骨骼旋转矩阵变换）、随音乐节奏唱歌张合的三角形橙橘色小喙。
struct BirbMascotView: View {
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

    // --- 1. IDLE 状态（圆滚滚缩头盹盹） ---
    private func drawIdle(context: inout GraphicsContext, t: Double, cx: CGFloat, cy: CGFloat) {
        // 轻柔的 1.1s 周期微重力浮沉
        let floatY = sin(t * 1.5) * 0.6
        let breath = 0.98 + 0.02 * sin(t * 1.5)
        
        var bodyCtx = context
        bodyCtx.translateBy(x: cx, y: cy + floatY)
        bodyCtx.scaleBy(x: breath, y: breath)
        bodyCtx.translateBy(x: -cx, y: -(cy + floatY))
        
        let curCY = cy + floatY

        drawWings(context: &bodyCtx, cx: cx, cy: curCY, t: t, state: .idle)
        drawBodyFrame(context: &bodyCtx, cx: cx, cy: curCY)
        drawBeak(context: &bodyCtx, cx: cx, cy: curCY, t: t, state: .idle)
        drawEyes(context: &bodyCtx, cx: cx, cy: curCY, open: false)
        
        // Z 睡眠气泡
        drawZs(context: &context, t: t, originX: cx + 10, originY: curCY - 6)
    }

    // --- 2. WORKING 状态（极速扇翅/疯狂干活） ---
    private func drawWorking(context: inout GraphicsContext, t: Double, cx: CGFloat, cy: CGFloat) {
        let bounceY = abs(sin(t * 3.5)) * 1.2
        let curCY = cy - bounceY
        
        let lean = sin(t * 8.0) * 0.04
        
        var bodyCtx = context
        bodyCtx.translateBy(x: cx, y: curCY)
        bodyCtx.rotate(by: Angle(radians: Double(lean)))
        bodyCtx.translateBy(x: -cx, y: -curCY)

        // 高频振翅
        drawWings(context: &bodyCtx, cx: cx, cy: curCY, t: t, state: .working)
        drawBodyFrame(context: &bodyCtx, cx: cx, cy: curCY)
        drawBeak(context: &bodyCtx, cx: cx, cy: curCY, t: t, state: .working)
        drawEyes(context: &bodyCtx, cx: cx, cy: curCY, open: true)
        
        // 顶部 Loading 点
        drawLoadingDots(context: &context, t: t, cx: cx, topY: curCY - 13)
    }

    // --- 3. MUSIC 状态（跳跃唱歌/音符起飞） ---
    private func drawMusic(context: inout GraphicsContext, t: Double, cx: CGFloat, cy: CGFloat) {
        let bounceY = abs(sin(t * 4.5)) * 1.8
        let curCY = cy - bounceY
        
        // 跟随音乐偏转（左右跳歌）
        let lean = sin(t * 4.5) * 0.08
        
        var bodyCtx = context
        bodyCtx.translateBy(x: cx, y: curCY)
        bodyCtx.rotate(by: Angle(radians: Double(lean)))
        bodyCtx.translateBy(x: -cx, y: -curCY)

        // 飞舞的翅膀
        drawWings(context: &bodyCtx, cx: cx, cy: curCY, t: t, state: .music)
        drawBodyFrame(context: &bodyCtx, cx: cx, cy: curCY)
        drawBeak(context: &bodyCtx, cx: cx, cy: curCY, t: t, state: .music)
        drawEyes(context: &bodyCtx, cx: cx, cy: curCY, open: MascotMusicNotesEffect.isEyeOpen(t: t, seed: 6))
        
        MascotMusicNotesEffect.draw(context: &context, t: t, cx: cx, cy: curCY)
    }

    // ==========================================
    // ============= 青鸟组件绘制 =============
    // ==========================================

    // 1. 胖胖小鸟翅膀（带旋转矩阵振翼）
    private func drawWings(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat, t: Double, state: MascotState) {
        let wingColor = Color(red: 0.10, green: 0.38, blue: 0.78)
        
        // 振翅频率：工作模式下蜂鸟般极速拍打；音乐模式下按拍起舞
        let flapFreq = state == .music ? 14.0 : (state == .working ? 24.0 : 0)
        let maxAngle = state == .music ? 0.32 : (state == .working ? 0.45 : 0)
        let leftAngle = -0.1 + sin(t * flapFreq) * maxAngle
        let rightAngle = 0.1 - sin(t * flapFreq) * maxAngle
        
        // A. 左小翅膀
        var leftCtx = context
        let leftRect = CGRect(x: cx - 11.6, y: cy - 2.5, width: 3.4, height: 6.2)
        let leftPath = Path(roundedRect: leftRect, cornerRadius: 1.5)
        // 绕左肩部轴心 (cx - 8, cy) 旋转
        leftCtx.translateBy(x: cx - 8.2, y: cy + 0.6)
        leftCtx.rotate(by: Angle(radians: leftAngle))
        leftCtx.translateBy(x: -(cx - 8.2), y: -(cy + 0.6))
        leftCtx.fill(leftPath, with: .color(wingColor))
        
        // B. 右小翅膀
        var rightCtx = context
        let rightRect = CGRect(x: cx + 8.2, y: cy - 2.5, width: 3.4, height: 6.2)
        let rightPath = Path(roundedRect: rightRect, cornerRadius: 1.5)
        // 绕右肩部轴心 (cx + 8, cy) 旋转
        rightCtx.translateBy(x: cx + 8.2, y: cy + 0.6)
        rightCtx.rotate(by: Angle(radians: rightAngle))
        rightCtx.translateBy(x: -(cx + 8.2), y: -(cy + 0.6))
        rightCtx.fill(rightPath, with: .color(wingColor))
    }

    // 2. 胖乎乎球形身体 + 奶油白肚皮
    private func drawBodyFrame(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat) {
        let outlineColor = Color(red: 0.05, green: 0.04, blue: 0.08)
        let birbBodyColor = Color(red: 0.16, green: 0.52, blue: 0.94)
        let bellyColor = Color(red: 0.98, green: 0.96, blue: 0.94)
        
        // A. 主圆滚滚身体舱体
        let rect = CGRect(x: cx - 8.5, y: cy - 7.5, width: 17, height: 15.0)
        let path = Path(ellipseIn: rect)
        context.stroke(path, with: .color(outlineColor), lineWidth: 0.8)
        
        let bodyGrad = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [birbBodyColor, Color(red: 0.10, green: 0.38, blue: 0.78)]),
            startPoint: CGPoint(x: cx - 8.5, y: cy - 7.5),
            endPoint: CGPoint(x: cx + 8.5, y: cy + 7.5)
        )
        context.fill(path, with: bodyGrad)
        
        // B. 奶油胖肚皮
        let bellyRect = CGRect(x: cx - 5.5, y: cy + 0.5, width: 11.0, height: 6.5)
        let bellyPath = Path(ellipseIn: bellyRect)
        context.fill(bellyPath, with: .color(bellyColor.opacity(0.92)))
    }

    // 3. 三角橙黄色小喙（小尖嘴，音乐模式下张合高歌！）
    private func drawBeak(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat, t: Double, state: MascotState) {
        let beakColor = Color(red: 0.98, green: 0.62, blue: 0.15)
        
        let startX = cx - 0.5
        let startY = cy - 1.2
        
        if state == .music {
            // 音乐模式下，上下小三角形尖喙随拍子节奏欢快张合唱歌
            let open = abs(sin(t * 12.0)) * 2.0
            
            // 上尖嘴
            var upBeak = Path()
            upBeak.move(to: CGPoint(x: startX, y: startY - 0.5))
            upBeak.addLine(to: CGPoint(x: startX + 4.5, y: startY - 0.5 - open * 0.4))
            upBeak.addLine(to: CGPoint(x: startX, y: startY + 0.5))
            upBeak.closeSubpath()
            context.fill(upBeak, with: .color(beakColor))
            
            // 下尖嘴
            var downBeak = Path()
            downBeak.move(to: CGPoint(x: startX, y: startY + 0.5))
            downBeak.addLine(to: CGPoint(x: startX + 4.0, y: startY + 1.2 + open * 0.6))
            downBeak.addLine(to: CGPoint(x: startX - 0.2, y: startY + 1.6))
            downBeak.closeSubpath()
            context.fill(downBeak, with: .color(Color(red: 0.88, green: 0.52, blue: 0.10)))
        } else {
            // 平常为一只闭合的小巧三角形喙
            var beakPath = Path()
            beakPath.move(to: CGPoint(x: startX, y: startY - 0.5))
            beakPath.addLine(to: CGPoint(x: startX + 4.2, y: startY + 0.5))
            beakPath.addLine(to: CGPoint(x: startX, y: startY + 1.5))
            beakPath.closeSubpath()
            context.fill(beakPath, with: .color(beakColor))
        }
    }

    // 4. 眼睛（豆豆眼 + 高光）
    private func drawEyes(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat, open: Bool) {
        let leftEyeX = cx - 3.2
        let eyeY = cy - 2.4
        let outlineColor = Color(red: 0.05, green: 0.04, blue: 0.08)
        
        if open {
            let size: CGFloat = 2.2
            let leftEye = Path(ellipseIn: CGRect(x: leftEyeX - size / 2, y: eyeY - size / 2, width: size, height: size))
            context.fill(leftEye, with: .color(outlineColor))
            
            // 白高光点
            context.fill(Path(ellipseIn: CGRect(x: leftEyeX - 0.6, y: eyeY - 0.6, width: 0.6, height: 0.6)), with: .color(.white))
        } else {
            let ew: CGFloat = 2.0
            let eh: CGFloat = 0.8
            context.fill(Path(roundedRect: CGRect(x: leftEyeX - ew / 2, y: eyeY - eh / 2, width: ew, height: eh), cornerRadius: 0.4), with: .color(outlineColor.opacity(0.75)))
        }
        
        // 软萌的粉色腮红（只在眼睛下方晕染一点）
        let blush = Color(red: 0.98, green: 0.44, blue: 0.54)
        context.fill(Path(ellipseIn: CGRect(x: leftEyeX - 1.5, y: eyeY + 1.2, width: 1.8, height: 1.2)), with: .color(blush.opacity(0.42)))
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

    // Working Loading 浆果
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
            // 荧光橘黄色小浆果 Loading 点
            let berryColor = Color(red: 1.0, green: 0.60, blue: 0.15)
            context.fill(
                Path(ellipseIn: rect),
                with: .color(berryColor.opacity(opacity))
            )
        }
    }
}
