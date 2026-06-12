import SwiftUI

// Canvas 绘制的高级未来感机器人伴侣（Sleek Sci-Fi Drone Companion）；
// 具备渐变高光舱舱体、发光高透面罩、动态浮空手部、胸口微型核反应堆及音乐均衡器律动眼睛。
struct RobotMascotView: View {
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
            TimelineView(.animation) { timeline in
                Canvas { context, canvasSize in
                    drawFrame(context: &context, size: canvasSize, date: timeline.date)
                }
            }
            .frame(width: size, height: size)
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

    // --- 1. IDLE 状态（休眠/微重力漂浮） ---
    private func drawIdle(
        context: inout GraphicsContext,
        t: Double,
        cx: CGFloat,
        cy: CGFloat
    ) {
        // 慢速 1.3 弧度/秒的微幅浮沉，以及极轻微的体积压缩呼吸感
        let floatY = sin(t * 1.5) * 0.8
        let breath = 0.98 + 0.02 * sin(t * 1.5)
        
        var bodyCtx = context
        // 平移和缩放变换
        bodyCtx.translateBy(x: cx, y: cy + floatY)
        bodyCtx.scaleBy(x: breath, y: breath)
        bodyCtx.translateBy(x: -cx, y: -(cy + floatY))
        
        let curCY = cy + floatY

        // 绘制各部分组件
        drawAntenna(context: &bodyCtx, cx: cx, cy: curCY, t: t)
        drawSideEars(context: &bodyCtx, cx: cx, cy: curCY)
        drawBodyFrame(context: &bodyCtx, cx: cx, cy: curCY, t: t)
        drawHeadFrame(context: &bodyCtx, cx: cx, cy: curCY)
        drawVisor(context: &bodyCtx, cx: cx, cy: curCY)
        drawEyesIdle(context: &bodyCtx, cx: cx, cy: curCY)
        drawFloatingHands(context: &bodyCtx, cx: cx, cy: curCY, t: t, state: .idle)
        
        // 睡意 Z 气泡上浮
        drawZs(context: &context, t: t, originX: cx + 11, originY: curCY - 6)
    }

    // --- 2. WORKING 状态（高频处理/思维跳跃） ---
    private func drawWorking(
        context: inout GraphicsContext,
        t: Double,
        cx: CGFloat,
        cy: CGFloat
    ) {
        // 快速上下起伏
        let bounceY = abs(sin(t * 4.0)) * 1.5
        let curCY = cy - bounceY

        var bodyCtx = context
        bodyCtx.translateBy(x: cx, y: curCY)
        bodyCtx.translateBy(x: -cx, y: -curCY)

        drawAntenna(context: &bodyCtx, cx: cx, cy: curCY, t: t)
        drawSideEars(context: &bodyCtx, cx: cx, cy: curCY)
        drawBodyFrame(context: &bodyCtx, cx: cx, cy: curCY, t: t)
        drawHeadFrame(context: &bodyCtx, cx: cx, cy: curCY)
        drawVisor(context: &bodyCtx, cx: cx, cy: curCY)
        drawEyesWorking(context: &bodyCtx, cx: cx, cy: curCY, t: t)
        drawFloatingHands(context: &bodyCtx, cx: cx, cy: curCY, t: t, state: .working)
        
        // 顶部浮现思维 Loading 点
        drawLoadingDots(context: &context, t: t, cx: cx, topY: curCY - 14)
    }

    // --- 3. MUSIC 状态（快乐摇摆/律动节拍） ---
    private func drawMusic(
        context: inout GraphicsContext,
        t: Double,
        cx: CGFloat,
        cy: CGFloat
    ) {
        // 配合音乐强度的弹跳
        let bounceY = abs(sin(t * 5.0)) * 2.0
        let curCY = cy - bounceY
        
        // 摇摆偏转角（Head-banging / Body-rocking）
        let rotationAngle = sin(t * 5.0) * 0.08 // ±4.5度
        
        var danceCtx = context
        danceCtx.translateBy(x: cx, y: curCY)
        danceCtx.rotate(by: Angle(radians: rotationAngle))
        danceCtx.translateBy(x: -cx, y: -curCY)

        drawAntenna(context: &danceCtx, cx: cx, cy: curCY, t: t)
        drawSideEars(context: &danceCtx, cx: cx, cy: curCY)
        drawBodyFrame(context: &danceCtx, cx: cx, cy: curCY, t: t)
        drawHeadFrame(context: &danceCtx, cx: cx, cy: curCY)
        drawVisor(context: &danceCtx, cx: cx, cy: curCY)
        drawEyesMusic(context: &danceCtx, cx: cx, cy: curCY, t: t)
        drawFloatingHands(context: &danceCtx, cx: cx, cy: curCY, t: t, state: .music)
        
        // 外部画音符粒子
        MascotMusicNotesEffect.draw(context: &context, t: t, cx: cx, cy: curCY)
    }

    // ==========================================
    // ============= 核心组件绘制 =============
    // ==========================================

    // 1. 头盔舱体（金属渐变）
    private func drawHeadFrame(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat) {
        let outline = Color(red: 0.04, green: 0.05, blue: 0.08)
        let rect = CGRect(x: cx - 9.5, y: cy - 9.5, width: 19, height: 13.5)
        let path = Path(roundedRect: rect, cornerRadius: 4.8)
        
        // 黑色细描边，凸显轮廓
        context.stroke(path, with: .color(outline), lineWidth: 0.8)
        
        // 银灰金属光泽渐变
        let helmetGrad = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [
                Color(red: 0.88, green: 0.91, blue: 0.94),
                Color(red: 0.60, green: 0.65, blue: 0.72),
                Color(red: 0.38, green: 0.42, blue: 0.48)
            ]),
            startPoint: CGPoint(x: cx - 9.5, y: cy - 9.5),
            endPoint: CGPoint(x: cx + 9.5, y: cy + 4)
        )
        context.fill(path, with: helmetGrad)
    }

    // 2. 黑色玻璃镜面面罩
    private func drawVisor(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat) {
        let rect = CGRect(x: cx - 7.0, y: cy - 7.0, width: 14, height: 8.5)
        let path = Path(roundedRect: rect, cornerRadius: 2.8)
        
        // 深邃蓝色镜面渐变
        let visorGrad = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [
                Color(red: 0.04, green: 0.05, blue: 0.10),
                Color(red: 0.08, green: 0.13, blue: 0.24)
            ]),
            startPoint: CGPoint(x: cx - 7, y: cy - 7),
            endPoint: CGPoint(x: cx + 7, y: cy + 1.5)
        )
        context.fill(path, with: visorGrad)
        
        // 绘制一层面罩反光高光（弧形反射）
        var pathHighlight = Path()
        pathHighlight.move(to: CGPoint(x: cx - 5.5, y: cy - 6))
        pathHighlight.addLine(to: CGPoint(x: cx - 1.0, y: cy - 6))
        pathHighlight.addQuadCurve(to: CGPoint(x: cx - 5.5, y: cy - 2.5), control: CGPoint(x: cx - 5.5, y: cy - 6))
        pathHighlight.closeSubpath()
        context.fill(pathHighlight, with: .color(Color.white.opacity(0.12)))
    }

    // 3. 耳部小接收器
    private func drawSideEars(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat) {
        let earColor = Color(red: 0.28, green: 0.32, blue: 0.38)
        let leftEar = Path(roundedRect: CGRect(x: cx - 11.2, y: cy - 6, width: 2, height: 6.5), cornerRadius: 0.8)
        let rightEar = Path(roundedRect: CGRect(x: cx + 9.2, y: cy - 6, width: 2, height: 6.5), cornerRadius: 0.8)
        
        context.fill(leftEar, with: .color(earColor))
        context.fill(rightEar, with: .color(earColor))
    }

    // 4. 金属天线与信号灯
    private func drawAntenna(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat, t: Double) {
        // 信号线
        let stem = Path(CGRect(x: cx - 0.75, y: cy - 12.5, width: 1.5, height: 3))
        context.fill(stem, with: .color(Color(red: 0.55, green: 0.60, blue: 0.68)))
        
        // 天线信号灯发光颜色
        let lightColor: Color
        let glowRadius: CGFloat
        
        switch state {
        case .idle:
            let pulse = sin(t * 3.0) * 0.5 + 0.5
            lightColor = Color(red: 1.0, green: 0.62, blue: 0.15).opacity(0.3 + 0.5 * pulse)
            glowRadius = 1.5 + CGFloat(pulse * 2.0)
        case .working:
            let pulse = sin(t * 9.0) * 0.5 + 0.5
            lightColor = Color(red: 1.0, green: 0.72, blue: 0.20).opacity(0.4 + 0.6 * pulse)
            glowRadius = 2.0
        case .music:
            let colorVal = abs(sin(t * 4.0))
            lightColor = Color(red: 0.25, green: 0.95, blue: 1.0).opacity(0.4 + 0.6 * colorVal)
            glowRadius = 1.0 + CGFloat(colorVal * 3.0)
        }
        
        // 信号球
        let bulbRect = CGRect(x: cx - 2.0, y: cy - 14.8, width: 4.0, height: 4.0)
        let bulb = Path(ellipseIn: bulbRect)
        
        // 利用阴影产生极富质感的光点辉光
        var glowCtx = context
        glowCtx.addFilter(.shadow(color: lightColor, radius: glowRadius, x: 0, y: 0))
        glowCtx.fill(bulb, with: .color(lightColor))
    }

    // 5. 机械身体与能量核心 (Arc Reactor)
    private func drawBodyFrame(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat, t: Double) {
        let outline = Color(red: 0.04, green: 0.05, blue: 0.08)
        let rect = CGRect(x: cx - 6.5, y: cy + 5.0, width: 13, height: 7.5)
        let path = Path(roundedRect: rect, cornerRadius: 2.2)
        
        context.stroke(path, with: .color(outline), lineWidth: 0.8)
        
        // 身体采用稍深的铁灰色金属渐变
        let bodyGrad = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [
                Color(red: 0.46, green: 0.52, blue: 0.60),
                Color(red: 0.28, green: 0.32, blue: 0.38)
            ]),
            startPoint: CGPoint(x: cx - 6.5, y: cy + 5),
            endPoint: CGPoint(x: cx + 6.5, y: cy + 12.5)
        )
        context.fill(path, with: bodyGrad)
        
        // === 绘制胸口 Arc Reactor 发光核心 ===
        let coreRect = CGRect(x: cx - 1.5, y: cy + 7.2, width: 3.0, height: 3.0)
        let corePath = Path(ellipseIn: coreRect)
        
        let coreColor: Color
        let pulseOpacity: Double
        
        switch state {
        case .idle:
            coreColor = Color(red: 0.25, green: 0.95, blue: 1.0)
            pulseOpacity = 0.35 + 0.45 * sin(t * 3.0)
        case .working:
            coreColor = Color(red: 1.0, green: 0.70, blue: 0.15)
            pulseOpacity = 0.4 + 0.6 * sin(t * 9.0)
        case .music:
            coreColor = Color(red: 1.0, green: 0.30, blue: 0.60)
            pulseOpacity = 0.5 + 0.5 * abs(sin(t * 5.0))
        }
        
        var coreCtx = context
        coreCtx.addFilter(.shadow(color: coreColor.opacity(pulseOpacity), radius: 1.8, x: 0, y: 0))
        coreCtx.fill(corePath, with: .color(coreColor.opacity(0.4 + 0.6 * pulseOpacity)))
    }

    // 6. 悬浮磁吸双手（磁悬浮小圆球）
    private func drawFloatingHands(
        context: inout GraphicsContext,
        cx: CGFloat,
        cy: CGFloat,
        t: Double,
        state: MascotState
    ) {
        let leftBaseX = cx - 11.8
        let rightBaseX = cx + 11.8
        let handY: CGFloat
        let deltaX: CGFloat
        
        switch state {
        case .idle:
            // 极慢的微重力滞后上下浮动
            handY = cy + 4.5 + sin(t * 2.0) * 0.8
            deltaX = 0
        case .working:
            // 高频飞舞起伏
            handY = cy + 4.5 + sin(t * 9.0) * 2.0
            deltaX = sin(t * 9.0) * 0.4
        case .music:
            // 随音乐节拍张开和闭合收拢，画椭圆舞动轨迹
            handY = cy + 4.5 + cos(t * 5.0) * 1.5
            deltaX = sin(t * 5.0) * 1.5
        }
        
        let leftHandRect = CGRect(x: leftBaseX - deltaX - 1.8, y: handY - 1.8, width: 3.6, height: 3.6)
        let rightHandRect = CGRect(x: rightBaseX + deltaX - 1.8, y: handY - 1.8, width: 3.6, height: 3.6)
        
        let leftPath = Path(ellipseIn: leftHandRect)
        let rightPath = Path(ellipseIn: rightHandRect)
        
        let handGradLeft = GraphicsContext.Shading.radialGradient(
            Gradient(colors: [Color(red: 0.85, green: 0.88, blue: 0.94), Color(red: 0.38, green: 0.42, blue: 0.48)]),
            center: CGPoint(x: leftBaseX - deltaX - 0.6, y: handY - 0.6),
            startRadius: 0,
            endRadius: 1.8
        )
        let handGradRight = GraphicsContext.Shading.radialGradient(
            Gradient(colors: [Color(red: 0.85, green: 0.88, blue: 0.94), Color(red: 0.38, green: 0.42, blue: 0.48)]),
            center: CGPoint(x: rightBaseX + deltaX - 0.6, y: handY - 0.6),
            startRadius: 0,
            endRadius: 1.8
        )
        
        // 绘制双手本体
        context.fill(leftPath, with: handGradLeft)
        context.fill(rightPath, with: handGradRight)
        
        // 叠加微弱的手部稳定霓虹光点
        let glowColor = state == .idle ? Color(red: 0.25, green: 0.95, blue: 1.0) : (state == .working ? Color(red: 1.0, green: 0.70, blue: 0.15) : Color(red: 1.0, green: 0.30, blue: 0.60))
        let glowL = CGRect(x: leftBaseX - deltaX - 0.8, y: handY - 0.8, width: 1.6, height: 1.6)
        let glowR = CGRect(x: rightBaseX + deltaX - 0.8, y: handY - 0.8, width: 1.6, height: 1.6)
        
        var glowCtx = context
        glowCtx.addFilter(.shadow(color: glowColor, radius: 1.0, x: 0, y: 0))
        glowCtx.fill(Path(ellipseIn: glowL), with: .color(glowColor.opacity(0.8)))
        glowCtx.fill(Path(ellipseIn: glowR), with: .color(glowColor.opacity(0.8)))
    }

    // ==========================================
    // ============= 眼睛状态渲染 =============
    // ==========================================

    // 1. Idle 眼睛：温柔长亮的荧光细条，带呼吸微动
    private func drawEyesIdle(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat) {
        let eyeY = cy - 2.8
        let leftX = cx - 3.2
        let rightX = cx + 3.2
        let ew: CGFloat = 2.4
        let eh: CGFloat = 1.0
        
        let color = Color(red: 0.25, green: 0.95, blue: 1.0)
        
        var eyeCtx = context
        eyeCtx.addFilter(.shadow(color: color, radius: 1.2, x: 0, y: 0))
        
        let leftRect = CGRect(x: leftX - ew / 2, y: eyeY - eh / 2, width: ew, height: eh)
        let rightRect = CGRect(x: rightX - ew / 2, y: eyeY - eh / 2, width: ew, height: eh)
        
        eyeCtx.fill(Path(roundedRect: leftRect, cornerRadius: 0.4), with: .color(color.opacity(0.88)))
        eyeCtx.fill(Path(roundedRect: rightRect, cornerRadius: 0.4), with: .color(color.opacity(0.88)))
    }

    // 2. Working 眼睛：高度专注的双核高亮圆角方点，带有概率快速眨眼
    private func drawEyesWorking(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat, t: Double) {
        let eyeY = cy - 2.8
        let leftX = cx - 3.2
        let rightX = cx + 3.2
        
        // 基于时间周期的偶发快速眨眼
        let phase = t.truncatingRemainder(dividingBy: 2.0)
        let isBlinking = phase < 0.12
        
        let color = Color(red: 0.25, green: 0.95, blue: 1.0)
        var eyeCtx = context
        eyeCtx.addFilter(.shadow(color: color, radius: 1.5, x: 0, y: 0))
        
        if isBlinking {
            // 眨眼状态为一条极细缝
            let leftRect = CGRect(x: leftX - 1.2, y: eyeY - 0.4, width: 2.4, height: 0.8)
            let rightRect = CGRect(x: rightX - 1.2, y: eyeY - 0.4, width: 2.4, height: 0.8)
            eyeCtx.fill(Path(leftRect), with: .color(color.opacity(0.4)))
            eyeCtx.fill(Path(rightRect), with: .color(color.opacity(0.4)))
        } else {
            // 专注状态大矩形
            let size: CGFloat = 2.2
            let leftRect = CGRect(x: leftX - size / 2, y: eyeY - size / 2, width: size, height: size)
            let rightRect = CGRect(x: rightX - size / 2, y: eyeY - size / 2, width: size, height: size)
            eyeCtx.fill(Path(roundedRect: leftRect, cornerRadius: 0.4), with: .color(color))
            eyeCtx.fill(Path(roundedRect: rightRect, cornerRadius: 0.4), with: .color(color))
        }
    }

    // 3. Music 眼睛：高科技电子音乐频谱仪（左右两个独立的动态均衡器柱状图波形！）
    private func drawEyesMusic(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat, t: Double) {
        let baseEyeY = cy - 1.2
        let leftStartX = cx - 4.6
        let rightStartX = cx + 1.8
        let barW: CGFloat = 1.0
        let spacing: CGFloat = 0.5
        
        let activeColor = Color(red: 0.25, green: 0.95, blue: 1.0)
        var eyeCtx = context
        eyeCtx.addFilter(.shadow(color: activeColor.opacity(0.7), radius: 1.2, x: 0, y: 0))
        
        // 左右眼各由 3 根跳动的频谱条组成，波形错开
        for i in 0..<3 {
            let leftIdx = Double(i)
            let rightIdx = Double(2 - i)
            
            // 三角函数公式计算频谱高度 [1.0, 4.8]
            let leftH = 1.0 + abs(sin(t * 11.0 + leftIdx * 1.6)) * 3.8
            let rightH = 1.0 + abs(cos(t * 12.5 + rightIdx * 1.3)) * 3.8
            
            // 绘制左眼频谱条（从基准线下方向上长高）
            let leftX = leftStartX + CGFloat(i) * (barW + spacing)
            let leftRect = CGRect(x: leftX, y: baseEyeY - leftH, width: barW, height: leftH)
            eyeCtx.fill(Path(roundedRect: leftRect, cornerRadius: 0.3), with: .color(activeColor))
            
            // 绘制右眼频谱条
            let rightX = rightStartX + CGFloat(i) * (barW + spacing)
            let rightRect = CGRect(x: rightX, y: baseEyeY - rightH, width: barW, height: rightH)
            eyeCtx.fill(Path(roundedRect: rightRect, cornerRadius: 0.3), with: .color(activeColor))
        }
    }

    // ==========================================
    // ============= 辅助动画函数 =============
    // ==========================================

    // Z 字呼吸气泡
    private func drawZs(
        context: inout GraphicsContext,
        t: Double,
        originX: CGFloat,
        originY: CGFloat
    ) {
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

    // Working 状态浮动 Loading 思考点
    private func drawLoadingDots(
        context: inout GraphicsContext,
        t: Double,
        cx: CGFloat,
        topY: CGFloat
    ) {
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
