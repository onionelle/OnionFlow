import SwiftUI

// Canvas 绘制的高清萌系云朵小羊（Fluffy Sheep）；
// 具备层叠云朵蓬松身体（音乐模式下呈重低音音箱般收缩膨胀的弹性动效）、精巧金色螺旋羊角与慵懒睡眼。
struct NoodleMascotView: View {
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

    // --- 1. IDLE 状态（软绵绵云朵小憩） ---
    private func drawIdle(context: inout GraphicsContext, t: Double, cx: CGFloat, cy: CGFloat) {
        let floatY = sin(t * 1.2) * 0.6
        let breath = 0.98 + 0.02 * sin(t * 1.5)
        
        var bodyCtx = context
        bodyCtx.translateBy(x: cx, y: cy + floatY)
        bodyCtx.scaleBy(x: breath, y: breath)
        bodyCtx.translateBy(x: -cx, y: -(cy + floatY))
        
        let curCY = cy + floatY

        drawHorns(context: &bodyCtx, cx: cx, cy: curCY, scale: 1.0)
        drawSheepWool(context: &bodyCtx, cx: cx, cy: curCY, scale: 1.0)
        drawFace(context: &bodyCtx, cx: cx, cy: curCY, open: false, state: .idle)
        
        // Z 睡眠气泡
        drawZs(context: &context, t: t, originX: cx + 11, originY: curCY - 6)
    }

    // --- 2. WORKING 状态（小绵羊吃青草中） ---
    private func drawWorking(context: inout GraphicsContext, t: Double, cx: CGFloat, cy: CGFloat) {
        let bounceY = abs(sin(t * 3.5)) * 1.0
        let curCY = cy - bounceY
        
        // 吃草时左右轻轻蠕动
        let lean = sin(t * 8.0) * 0.03
        
        var bodyCtx = context
        bodyCtx.translateBy(x: cx, y: curCY)
        bodyCtx.rotate(by: Angle(radians: Double(lean)))
        bodyCtx.translateBy(x: -cx, y: -curCY)

        drawHorns(context: &bodyCtx, cx: cx, cy: curCY, scale: 1.0)
        drawSheepWool(context: &bodyCtx, cx: cx, cy: curCY, scale: 1.0)
        drawFace(context: &bodyCtx, cx: cx, cy: curCY, open: true, state: .working)
        
        // 头部出现浮动小草点
        drawLoadingDots(context: &context, t: t, cx: cx, topY: curCY - 13)
    }

    // --- 3. MUSIC 状态（重低音音响式羊毛弹性膨胀！） ---
    private func drawMusic(context: inout GraphicsContext, t: Double, cx: CGFloat, cy: CGFloat) {
        let bounceY = abs(sin(t * 5.0)) * 1.6
        let curCY = cy - bounceY
        
        let lean = sin(t * 5.0) * 0.06
        
        // 羊毛随节奏弹性极具动感地缩放
        let woolScale = 1.0 + abs(sin(t * 5.0)) * 0.12 // [1.0, 1.12] 随重低音律动

        var bodyCtx = context
        bodyCtx.translateBy(x: cx, y: curCY)
        bodyCtx.rotate(by: Angle(radians: Double(lean)))
        bodyCtx.translateBy(x: -cx, y: -curCY)

        // 羊角保持基础大小，云朵羊毛发生动态膨胀
        drawHorns(context: &bodyCtx, cx: cx, cy: curCY, scale: 1.0)
        drawSheepWool(context: &bodyCtx, cx: cx, cy: curCY, scale: woolScale)
        drawFace(context: &bodyCtx, cx: cx, cy: curCY, open: MascotMusicNotesEffect.isEyeOpen(t: t, seed: 5), state: .music)
        
        MascotMusicNotesEffect.draw(context: &context, t: t, cx: cx, cy: curCY)
    }

    // ==========================================
    // ============= 绵羊组件绘制 =============
    // ==========================================

    // 1. 螺旋黄金羊角
    private func drawHorns(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat, scale: CGFloat) {
        let hornColor = Color(red: 0.94, green: 0.74, blue: 0.28)
        let outlineColor = Color(red: 0.05, green: 0.05, blue: 0.07)
        
        // 左羊角（螺旋弧线）
        var hornL = Path()
        hornL.move(to: CGPoint(x: cx - 5.0, y: cy - 2.8))
        hornL.addQuadCurve(to: CGPoint(x: cx - 11.2, y: cy - 4.5), control: CGPoint(x: cx - 9.5, y: cy - 7.5))
        hornL.addQuadCurve(to: CGPoint(x: cx - 8.5, y: cy + 0.5), control: CGPoint(x: cx - 12.5, y: cy - 1.0))
        hornL.addQuadCurve(to: CGPoint(x: cx - 7.2, y: cy - 1.5), control: CGPoint(x: cx - 7.5, y: cy + 0.8))
        
        context.stroke(hornL, with: .color(outlineColor), lineWidth: 2.2)
        context.stroke(hornL, with: .color(hornColor), lineWidth: 1.2)
        
        // 右羊角
        var hornR = Path()
        hornR.move(to: CGPoint(x: cx + 5.0, y: cy - 2.8))
        hornR.addQuadCurve(to: CGPoint(x: cx + 11.2, y: cy - 4.5), control: CGPoint(x: cx + 9.5, y: cy - 7.5))
        hornR.addQuadCurve(to: CGPoint(x: cx + 8.5, y: cy + 0.5), control: CGPoint(x: cx + 12.5, y: cy - 1.0))
        hornR.addQuadCurve(to: CGPoint(x: cx + 7.2, y: cy - 1.5), control: CGPoint(x: cx + 7.5, y: cy + 0.8))
        
        context.stroke(hornR, with: .color(outlineColor), lineWidth: 2.2)
        context.stroke(hornR, with: .color(hornColor), lineWidth: 1.2)
    }

    // 2. 蓬松的堆砌云朵羊毛身体（利用多颗层叠半透明渐变圆）
    private func drawSheepWool(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat, scale: CGFloat) {
        let woolColor = Color(red: 0.98, green: 0.98, blue: 0.98)
        let woolShade = Color(red: 0.85, green: 0.88, blue: 0.94)
        let outlineColor = Color(red: 0.05, green: 0.05, blue: 0.07)
        
        var woolCtx = context
        woolCtx.translateBy(x: cx, y: cy)
        woolCtx.scaleBy(x: scale, y: scale)
        woolCtx.translateBy(x: -cx, y: -cy)
        
        // 羊毛由 6 颗圆滑的重叠小圆圈组成，在 32pt 下形成一个萌系云朵外廓
        let bubbles: [(rect: CGRect, isShade: Bool)] = [
            (CGRect(x: cx - 11.2, y: cy - 5.5, width: 8.5, height: 8.5), true),   // 左下
            (CGRect(x: cx + 2.7, y: cy - 5.5, width: 8.5, height: 8.5), true),    // 右下
            (CGRect(x: cx - 5.0, y: cy - 10.8, width: 10.0, height: 10.0), false), // 顶
            (CGRect(x: cx - 10.8, y: cy - 9.0, width: 7.5, height: 7.5), false),   // 左上
            (CGRect(x: cx + 3.3, y: cy - 9.0, width: 7.5, height: 7.5), false),    // 右上
            (CGRect(x: cx - 7.5, y: cy + 1.2, width: 15.0, height: 9.5), true),   // 底部大座
        ]
        
        // 先统一描一遍粗外框，确保堆叠后外沿呈清晰一体的线条
        for bubble in bubbles {
            let path = Path(ellipseIn: bubble.rect)
            context.stroke(path, with: .color(outlineColor.opacity(0.85)), lineWidth: 0.7)
        }
        
        // 依次用白-蓝灰渐变填充，营造蓬松柔软的体积质感
        for bubble in bubbles {
            let path = Path(ellipseIn: bubble.rect)
            let grad = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [woolColor, bubble.isShade ? woolShade : Color.white]),
                startPoint: CGPoint(x: bubble.rect.minX, y: bubble.rect.minY),
                endPoint: CGPoint(x: bubble.rect.maxX, y: bubble.rect.maxY)
            )
            context.fill(path, with: grad)
        }
    }

    // 3. 羊脸（藏在云朵中央的害羞小羊脸）
    private func drawFace(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat, open: Bool, state: MascotState) {
        let leftEyeX = cx - 3.2
        let rightEyeX = cx + 3.2
        let eyeY = cy - 1.6
        let outlineColor = Color(red: 0.05, green: 0.05, blue: 0.07)
        let faceColor = Color(red: 0.98, green: 0.90, blue: 0.84)
        
        // A. 羊皮脸部本体圆角矩形
        let faceRect = CGRect(x: cx - 5.5, y: cy - 3.8, width: 11.0, height: 8.0)
        let facePath = Path(roundedRect: faceRect, cornerRadius: 3.5)
        context.fill(facePath, with: .color(faceColor))
        
        // B. 眼睛
        if open {
            // 睁眼：豆豆眼，透露出温顺
            let size: CGFloat = 1.8
            let left = Path(ellipseIn: CGRect(x: leftEyeX - size / 2, y: eyeY - size / 2, width: size, height: size))
            let right = Path(ellipseIn: CGRect(x: rightEyeX - size / 2, y: eyeY - size / 2, width: size, height: size))
            context.fill(left, with: .color(outlineColor))
            context.fill(right, with: .color(outlineColor))
        } else {
            // 眯眼：两道温顺平缓的细月牙
            let ew: CGFloat = 2.0
            let eh: CGFloat = 0.8
            context.fill(Path(roundedRect: CGRect(x: leftEyeX - ew / 2, y: eyeY - eh / 2, width: ew, height: eh), cornerRadius: 0.4), with: .color(outlineColor.opacity(0.72)))
            context.fill(Path(roundedRect: CGRect(x: rightEyeX - ew / 2, y: eyeY - eh / 2, width: ew, height: eh), cornerRadius: 0.4), with: .color(outlineColor.opacity(0.72)))
        }
        
        // C. 标志性的粉红羊咩腮红
        let pinkCheek = Color(red: 0.98, green: 0.44, blue: 0.54)
        let cheekL = CGRect(x: leftEyeX - 1.8, y: eyeY + 1.2, width: 1.8, height: 1.2)
        let cheekR = CGRect(x: rightEyeX, y: eyeY + 1.2, width: 1.8, height: 1.2)
        context.fill(Path(ellipseIn: cheekL), with: .color(pinkCheek.opacity(0.48)))
        context.fill(Path(ellipseIn: cheekR), with: .color(pinkCheek.opacity(0.48)))
        
        // D. 三角形温驯小鼻子
        let noseRect = CGRect(x: cx - 0.7, y: cy + 0.2, width: 1.4, height: 1.0)
        context.fill(Path(ellipseIn: noseRect), with: .color(outlineColor.opacity(0.68)))
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

    // Working Loading 草点
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
            // 青草发光绿 Loading 点
            let grassColor = Color(red: 0.16, green: 0.82, blue: 0.50)
            context.fill(
                Path(ellipseIn: rect),
                with: .color(grassColor.opacity(opacity))
            )
        }
    }
}
