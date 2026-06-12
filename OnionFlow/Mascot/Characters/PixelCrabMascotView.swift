import SwiftUI

/// Canvas 绘制的 8-bit 复古电子宠物小螃蟹（Pixel Crab - 致敬 Clawd）；
/// 具备高精格栅发光点阵、横向左右踱步爬行、双螯交替律动及像素吹泡泡动效。
struct PixelCrabMascotView: View {
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

    // --- 1. IDLE 状态（安静打盹/吐像素泡泡） ---
    private func drawIdle(context: inout GraphicsContext, t: Double, cx: CGFloat, cy: CGFloat) {
        // 轻微呼吸浮沉
        let floatY = sin(t * 1.5) * 0.5
        let curCY = cy + floatY
        
        // 缓慢交替 Frame A (防守) 与 Frame B (小缩)
        let frameIndex = Int(t * 0.8) % 2
        let pixels = (frameIndex == 0) ? frameA : frameB
        
        let pixelColor = Color(red: 0.98, green: 0.36, blue: 0.26) // 复古发光红橘色
        
        drawLattice(context: &context, cx: cx, cy: curCY, pixels: pixels, color: pixelColor)
        
        // 吹出可爱的 8-bit 像素小泡泡
        drawPixelBubbles(context: &context, t: t, originX: cx - 3.0, originY: curCY - 2.0)
        
        // 像素 Z 字符上浮
        drawPixelZs(context: &context, t: t, originX: cx + 11.0, originY: curCY - 5.0)
    }

    // --- 2. WORKING 状态（疯狂敲键盘/双螯狂舞） ---
    private func drawWorking(context: inout GraphicsContext, t: Double, cx: CGFloat, cy: CGFloat) {
        // 身体快频上下小跳动
        let bounceY = abs(sin(t * 4.5)) * 0.8
        let curCY = cy - bounceY
        
        // 高频交替 A、B、C 三帧
        let frameIndex = Int(t * 10.0) % 3
        let pixels = (frameIndex == 0) ? frameA : ((frameIndex == 1) ? frameB : frameC)
        
        let pixelColor = Color(red: 0.98, green: 0.36, blue: 0.26)
        
        drawLattice(context: &context, cx: cx, cy: curCY, pixels: pixels, color: pixelColor)
        
        // 顶部 Loading 点
        drawPixelLoading(context: &context, t: t, cx: cx, topY: curCY - 13.0)
    }

    // --- 3. MUSIC 状态（魔性横行踱步/大舞双螯） ---
    private func drawMusic(context: inout GraphicsContext, t: Double, cx: CGFloat, cy: CGFloat) {
        // 强律动上下蹦迪
        let bounceY = abs(sin(t * 5.5)) * 1.2
        let curCY = cy - bounceY
        
        // 魔性横向踱步方程：经典螃蟹左右横移爬行！(移动范围约 -3.5pt 到 +3.5pt)
        let driftX = sin(t * 4.0) * 3.5
        let curCX = cx + driftX
        
        // 极快动作交替
        let frameIndex = Int(t * 12.0) % 3
        let pixels = (frameIndex == 0) ? frameA : ((frameIndex == 1) ? frameB : frameC)
        
        let pixelColor = Color(red: 0.98, green: 0.36, blue: 0.26)
        
        drawLattice(context: &context, cx: curCX, cy: curCY, pixels: pixels, color: pixelColor)
        
        // 音符环绕
        MascotMusicNotesEffect.draw(context: &context, t: t, cx: curCX, cy: curCY)
    }

    // ==========================================
    // ============= 8-bit 点阵绘制器 =============
    // ==========================================

    /// 核心像素格阵列绘制，带黑线微缝隙格栅，还原 authentic LCD 质感
    private func drawLattice(
        context: inout GraphicsContext,
        cx: CGFloat,
        cy: CGFloat,
        pixels: [String],
        color: Color
    ) {
        let pixelSize: CGFloat = 1.3 // chunky 像素粒径
        let rows = pixels.count
        let cols = pixels[0].count
        
        // 定位起点
        let startX = cx - CGFloat(cols) * pixelSize / 2
        let startY = cy - CGFloat(rows) * pixelSize / 2
        
        for r in 0..<rows {
            let rowStr = pixels[r]
            let chars = Array(rowStr)
            for c in 0..<cols {
                if c < chars.count && chars[c] == "#" {
                    let rect = CGRect(
                        x: startX + CGFloat(c) * pixelSize,
                        y: startY + CGFloat(r) * pixelSize,
                        width: pixelSize - 0.22, // 扣除 0.22pt 的微缝间隙，展现完美的复古 LED 发光格栅视觉
                        height: pixelSize - 0.22
                    )
                    
                    // 双层发光质感
                    var glowCtx = context
                    glowCtx.addFilter(.shadow(color: color.opacity(0.48), radius: 0.8, x: 0, y: 0))
                    glowCtx.fill(Path(rect), with: .color(color))
                }
            }
        }
    }

    // ==========================================
    // ============= 8-bit 动作点阵阵列 =============
    // ==========================================

    // Frame A：防守平稳帧（双螯平行，小腿微立）
    private var frameA: [String] {
        [
            "....#......#....",
            "....#......#....",
            "..###.####.###..",
            ".#.##.####.##.#.",
            ".#.############.",
            "..##############",
            "..##############",
            "...############.",
            "....##########..",
            "....##########..",
            "....#..##..#....",
            "....#..##..#...."
        ]
    }

    // Frame B：双螯挥舞上张帧（大爪举起，小腿紧缩）
    private var frameB: [String] {
        [
            "..#...#..#...#..",
            ".##...#..#...##.",
            ".##...####...##.",
            "......####......",
            "....########....",
            "...##########...",
            "..############..",
            "..############..",
            "...##########...",
            "....#..##..#....",
            ".....##..##.....",
            "....#......#...."
        ]
    }

    // Frame C：奔跑跃动帧（双螯收缩，双腿往两侧极速扒拉）
    private var frameC: [String] {
        [
            "....#......#....",
            "....#......#....",
            "......####......",
            "..##..####..##..",
            ".###.######.###.",
            ".##.########.##.",
            "...##########...",
            "..############..",
            "..#..######..#..",
            "....########....",
            "...#..####..#...",
            "..#....##....#.."
        ]
    }

    // ==========================================
    // ============= 复古粒子绘制 =============
    // ==========================================

    // 1. 螃蟹专属：吐出 8-bit 像素小圆圈泡泡
    private func drawPixelBubbles(context: inout GraphicsContext, t: Double, originX: CGFloat, originY: CGFloat) {
        let configs: [(phaseOffset: Double, offsetX: CGFloat, startY: CGFloat)] = [
            (0.0, -1.0, originY - 1.0),
            (0.9, 1.8, originY - 2.5),
            (1.8, -2.5, originY - 4.0),
        ]
        
        for config in configs {
            let phase = (t + config.phaseOffset).truncatingRemainder(dividingBy: 2.7)
            let progress = phase / 2.7
            let floatUp = progress * 6.5
            let driftX = sin((t + config.phaseOffset) * 2.5) * 0.7
            let opacity = max(0.0, 0.88 - progress * 0.8)
            
            // 像素泡泡呈现为 2x2 或 1.5x1.5 的中空像素小方块
            let size = progress < 0.5 ? 1.0 : 1.6
            let rect = CGRect(
                x: originX + config.offsetX + driftX - size / 2,
                y: config.startY - floatUp - size / 2,
                width: size,
                height: size
            )
            
            context.stroke(
                Path(rect),
                with: .color(.white.opacity(opacity)),
                style: StrokeStyle(lineWidth: 0.5)
            )
        }
    }

    // 2. 8-bit 像素睡眠 Zs
    private func drawPixelZs(context: inout GraphicsContext, t: Double, originX: CGFloat, originY: CGFloat) {
        let configs: [(phaseOffset: Double, offsetX: CGFloat, startY: CGFloat)] = [
            (0.0, 0.0, originY + 1),
            (1.0, 2.5, originY - 2),
            (2.0, -2.0, originY - 4),
        ]
        
        for config in configs {
            let phase = (t + config.phaseOffset).truncatingRemainder(dividingBy: 3.0)
            let progress = phase / 3.0
            let floatUp = progress * 7.0
            let driftX = sin((t + config.phaseOffset) * 1.8) * 0.5
            let opacity = max(0.0, 0.82 - progress * 0.8)
            
            // 像素风格的 Z，由 4x4 的点阵堆成，我们直接用发光 Text 简化呈现
            let zText = Text("Z")
                .font(.system(size: 4.2, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(opacity))
            
            context.draw(zText, at: CGPoint(x: originX + config.offsetX + driftX, y: config.startY - floatUp))
        }
    }

    // 3. 8-bit 像素 Loading 指示器
    private func drawPixelLoading(context: inout GraphicsContext, t: Double, cx: CGFloat, topY: CGFloat) {
        let count = 3
        let spacing: CGFloat = 3.0
        let dotSize: CGFloat = 1.3
        let startX = cx - CGFloat(count - 1) * spacing / 2

        for i in 0..<count {
            let phase = (t + Double(i) * 0.28).truncatingRemainder(dividingBy: 1.0)
            let opacity = max(0.15, 0.92 * (sin(phase * 2 * .pi) * 0.5 + 0.5))

            // 像素方块 Loading 点
            let rect = CGRect(
                x: startX + CGFloat(i) * spacing - dotSize / 2,
                y: topY - dotSize / 2,
                width: dotSize,
                height: dotSize
            )
            context.fill(
                Path(rect),
                with: .color(.white.opacity(opacity))
            )
        }
    }
}
