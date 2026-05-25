import SwiftUI

// Canvas 绘制的高清萌系蹦迪石像（Synthwave Moai）；
// 具备硬朗黑曜石板反光渐变、高耸石鼻梁、以及在音乐模式下戴上的“爆笑发光霓虹太阳镜”（粉蓝荧光渐变与外发光辉光）。
struct MoaiMascotView: View {
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

    // --- 1. IDLE 状态（巨石深沉吐纳） ---
    private func drawIdle(context: inout GraphicsContext, t: Double, cx: CGFloat, cy: CGFloat) {
        // 极稳健、微幅的 2.0s 慢浮沉
        let floatY = sin(t * 1.0) * 0.45
        let breath = 0.985 + 0.015 * sin(t * 1.0)
        
        var bodyCtx = context
        bodyCtx.translateBy(x: cx, y: cy + floatY)
        bodyCtx.scaleBy(x: breath, y: breath)
        bodyCtx.translateBy(x: -cx, y: -(cy + floatY))
        
        let curCY = cy + floatY

        drawMoaiStone(context: &bodyCtx, cx: cx, cy: curCY, t: t, state: .idle)
        drawFace(context: &bodyCtx, cx: cx, cy: curCY, t: t, state: .idle)
        
        // Z 气泡
        drawZs(context: &context, t: t, originX: cx + 9, originY: curCY - 9)
    }

    // --- 2. WORKING 状态（石像发光深度运算中） ---
    private func drawWorking(context: inout GraphicsContext, t: Double, cx: CGFloat, cy: CGFloat) {
        // 沉重的短冲弹跳
        let bounceY = abs(sin(t * 3.0)) * 0.8
        let curCY = cy - bounceY
        
        var bodyCtx = context
        bodyCtx.translateBy(x: cx, y: curCY)
        bodyCtx.translateBy(x: -cx, y: -curCY)

        drawMoaiStone(context: &bodyCtx, cx: cx, cy: curCY, t: t, state: .working)
        drawFace(context: &bodyCtx, cx: cx, cy: curCY, t: t, state: .working)
        
        // 顶部浮现思维 Loading 石块
        drawLoadingDots(context: &context, t: t, cx: cx, topY: curCY - 14)
    }

    // --- 3. MUSIC 状态（戴上炫酷霓虹眼镜蹦迪！） ---
    private func drawMusic(context: inout GraphicsContext, t: Double, cx: CGFloat, cy: CGFloat) {
        // 极富节奏、强烈的蹦迪弹跳
        let bounceY = abs(sin(t * 4.8)) * 2.0
        let curCY = cy - bounceY
        
        // 随低音炮节奏剧烈上下摇摆
        let lean = sin(t * 4.8) * 0.05
        
        var bodyCtx = context
        bodyCtx.translateBy(x: cx, y: curCY)
        bodyCtx.rotate(by: Angle(radians: Double(lean)))
        bodyCtx.translateBy(x: -cx, y: -curCY)

        drawMoaiStone(context: &bodyCtx, cx: cx, cy: curCY, t: t, state: .music)
        drawFace(context: &bodyCtx, cx: cx, cy: curCY, t: t, state: .music)
        
        MascotMusicNotesEffect.draw(context: &context, t: t, cx: cx, cy: curCY)
    }

    // ==========================================
    // ============= 石像组件绘制 =============
    // ==========================================

    // 1. 棱角分明的 Moai 巨石雕像本体
    private func drawMoaiStone(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat, t: Double, state: MascotState) {
        let outlineColor = Color(red: 0.05, green: 0.05, blue: 0.07)
        let rockBaseColor = Color(red: 0.58, green: 0.62, blue: 0.68)
        let rockShadowColor = Color(red: 0.28, green: 0.32, blue: 0.38)
        
        // A. 刚毅的方下巴高耸长方形脸庞
        let rect = CGRect(x: cx - 6.5, y: cy - 10.5, width: 13.0, height: 21.0)
        let path = Path(roundedRect: rect, cornerRadius: 2.8)
        context.stroke(path, with: .color(outlineColor), lineWidth: 0.85)
        
        let rockGrad = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [rockBaseColor, rockShadowColor]),
            startPoint: CGPoint(x: cx - 6.5, y: cy - 10.5),
            endPoint: CGPoint(x: cx + 6.5, y: cy + 10.5)
        )
        context.fill(path, with: rockGrad)
        
        // B. 坚硬高耸的直鼻梁石块
        let noseRect = CGRect(x: cx - 1.6, y: cy - 4.5, width: 3.2, height: 9.0)
        let nosePath = Path(roundedRect: noseRect, cornerRadius: 0.8)
        context.stroke(nosePath, with: .color(outlineColor.opacity(0.4)), lineWidth: 0.5)
        context.fill(nosePath, with: .color(Color(red: 0.72, green: 0.76, blue: 0.82)))
        
        // C. 石像粗壮凸出的额骨眉弓阴影
        let brow = Path(CGRect(x: cx - 5.5, y: cy - 5.5, width: 11.0, height: 1.0))
        context.fill(brow, with: .color(outlineColor.opacity(0.35)))
    }

    // 2. 嘴唇、发光双眼，以及音乐状态下瞬间戴上的复古霓虹太阳镜 (Synthwave Glasses)
    private func drawFace(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat, t: Double, state: MascotState) {
        let leftEyeX = cx - 3.8
        let rightEyeX = cx + 3.8
        let eyeY = cy - 2.8
        let outlineColor = Color(red: 0.05, green: 0.05, blue: 0.07)
        
        // A. 嘴唇：深嵌的一字形石缝嘴
        let mouthRect = CGRect(x: cx - 3.2, y: cy + 6.6, width: 6.4, height: 1.2)
        context.fill(Path(roundedRect: mouthRect, cornerRadius: 0.4), with: .color(outlineColor.opacity(0.72)))
        
        // B. 脸部眼部/墨镜层绘制
        if state == .music {
            // === 音乐模式下的爆笑亮点：发光霓虹墨镜（由荧光粉到亮蓝的双色发光渐变） ===
            let glassesColorLeft = Color(red: 1.0, green: 0.15, blue: 0.58)  // 荧光粉
            let glassesColorRight = Color(red: 0.15, green: 0.85, blue: 1.0) // 荧光蓝
            
            let gSizeW: CGFloat = 5.2
            let gSizeH: CGFloat = 3.6
            let gY = eyeY - 0.4
            
            let leftLensRect = CGRect(x: leftEyeX - gSizeW / 2 - 0.6, y: gY - gSizeH / 2, width: gSizeW, height: gSizeH)
            let rightLensRect = CGRect(x: rightEyeX - gSizeW / 2 + 0.6, y: gY - gSizeH / 2, width: gSizeW, height: gSizeH)
            
            let pathL = Path(roundedRect: leftLensRect, cornerRadius: 0.8)
            let pathR = Path(roundedRect: rightLensRect, cornerRadius: 0.8)
            
            // 荧光渐变色
            let glassGrad = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [glassesColorLeft, glassesColorRight]),
                startPoint: CGPoint(x: cx - 6.0, y: gY),
                endPoint: CGPoint(x: cx + 6.0, y: gY)
            )
            
            var glassesCtx = context
            let glow = 1.2 + CGFloat(abs(sin(t * 9.0)) * 2.2) // 眼镜外发光随动
            glassesCtx.addFilter(.shadow(color: glassesColorLeft.opacity(0.7), radius: glow, x: -1.0, y: 0))
            glassesCtx.addFilter(.shadow(color: glassesColorRight.opacity(0.7), radius: glow, x: 1.0, y: 0))
            
            glassesCtx.fill(pathL, with: glassGrad)
            glassesCtx.fill(pathR, with: glassGrad)
            
            // 链接墨镜左右的白色发光细梁
            let bridgeRect = CGRect(x: cx - 1.2, y: gY - 0.4, width: 2.4, height: 0.8)
            glassesCtx.fill(Path(bridgeRect), with: .color(.white))
            
            // 镜面炫酷反光白斜线条
            let rW: CGFloat = 0.6
            let rH: CGFloat = 2.4
            context.fill(Path(CGRect(x: leftEyeX - 1.2, y: gY - 0.6, width: rW, height: rH)), with: .color(.white.opacity(0.48)))
            context.fill(Path(CGRect(x: rightEyeX + 0.4, y: gY - 0.6, width: rW, height: rH)), with: .color(.white.opacity(0.48)))
        } else {
            // C. 非音乐模式下：深陷的石质眼眶阴影
            let leftSocket = CGRect(x: leftEyeX - 1.8, y: eyeY - 1.0, width: 3.6, height: 2.0)
            let rightSocket = CGRect(x: rightEyeX - 1.8, y: eyeY - 1.0, width: 3.6, height: 2.0)
            context.fill(Path(roundedRect: leftSocket, cornerRadius: 0.6), with: .color(outlineColor.opacity(0.45)))
            context.fill(Path(roundedRect: rightSocket, cornerRadius: 0.6), with: .color(outlineColor.opacity(0.45)))
            
            if state == .working {
                // 工作深度计算中：眼眶中心冒出高亮发光的琥珀色能量计算核心
                let energyColor = Color(red: 1.0, green: 0.70, blue: 0.15)
                let coreL = Path(ellipseIn: CGRect(x: leftEyeX - 0.8, y: eyeY - 0.8, width: 1.6, height: 1.6))
                let coreR = Path(ellipseIn: CGRect(x: rightEyeX - 0.8, y: eyeY - 0.8, width: 1.6, height: 1.6))
                
                var eCtx = context
                eCtx.addFilter(.shadow(color: energyColor, radius: 1.2, x: 0, y: 0))
                eCtx.fill(coreL, with: .color(energyColor))
                eCtx.fill(coreR, with: .color(energyColor))
            } else {
                // 眯眼微眠缝隙
                context.fill(Path(CGRect(x: leftEyeX - 1.2, y: eyeY - 0.3, width: 2.4, height: 0.6)), with: .color(outlineColor.opacity(0.75)))
                context.fill(Path(CGRect(x: rightEyeX - 1.2, y: eyeY - 0.3, width: 2.4, height: 0.6)), with: .color(outlineColor.opacity(0.75)))
            }
        }
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

    // Working Loading 碎石
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
            // 灰石色 Loading 碎石点
            context.fill(
                Path(ellipseIn: rect),
                with: .color(Color(red: 0.65, green: 0.68, blue: 0.72).opacity(opacity))
            )
        }
    }
}
