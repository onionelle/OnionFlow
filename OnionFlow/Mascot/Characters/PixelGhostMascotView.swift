import SwiftUI

/// Canvas 绘制的 8-bit 像素幽灵（Pixel Ghost）；
/// 复刻 Ghost 的圆顶、裙摆和睡意，用与像素螃蟹/小狗相同的发光点阵格栅。
struct PixelGhostMascotView: View {
    let state: MascotState
    let size: CGFloat
    var isStatic: Bool = false

    var body: some View {
        MascotRenderedCanvas(size: size, isStatic: isStatic, state: state, idleAmplitude: 0.8) { context, canvasSize, date in
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

    private func drawIdle(context: inout GraphicsContext, t: Double, cx: CGFloat, cy: CGFloat) {
        let floatY = sin(t * 1.4) * 0.6
        let curCY = cy + floatY
        let frameIndex = Int(t * 0.8) % 2
        let pixels = (frameIndex == 0) ? frameA : frameB
        drawLattice(context: &context, cx: cx, cy: curCY, pixels: pixels, color: pixelColor)
        drawPixelZs(context: &context, t: t, originX: cx + 10.0, originY: curCY - 6.0)
    }

    private func drawWorking(context: inout GraphicsContext, t: Double, cx: CGFloat, cy: CGFloat) {
        let bounceY = abs(sin(t * 3.5)) * 0.8
        let curCY = cy - bounceY
        let frameIndex = Int(t * 10.0) % 3
        let pixels = (frameIndex == 0) ? frameA : ((frameIndex == 1) ? frameB : frameC)
        drawLattice(context: &context, cx: cx, cy: curCY, pixels: pixels, color: pixelColor)
        drawPixelLoading(context: &context, t: t, cx: cx, topY: curCY - 13.0)
    }

    private func drawMusic(context: inout GraphicsContext, t: Double, cx: CGFloat, cy: CGFloat) {
        let bounceY = abs(sin(t * 4.5)) * 1.2
        let curCY = cy - bounceY
        let driftX = sin(t * 3.2) * 2.4
        let curCX = cx + driftX
        let frameIndex = Int(t * 12.0) % 3
        let pixels = (frameIndex == 0) ? frameA : ((frameIndex == 1) ? frameB : frameC)
        drawLattice(context: &context, cx: curCX, cy: curCY, pixels: pixels, color: pixelColor)
        MascotMusicNotesEffect.draw(context: &context, t: t, cx: curCX, cy: curCY)
    }

    private var pixelColor: Color {
        Color(red: 0.70, green: 0.88, blue: 1.0)
    }

    private func drawLattice(
        context: inout GraphicsContext,
        cx: CGFloat,
        cy: CGFloat,
        pixels: [String],
        color: Color
    ) {
        let pixelSize: CGFloat = 1.3
        let rows = pixels.count
        let cols = pixels[0].count
        let startX = cx - CGFloat(cols) * pixelSize / 2
        let startY = cy - CGFloat(rows) * pixelSize / 2

        for r in 0..<rows {
            let chars = Array(pixels[r])
            for c in 0..<cols {
                if c < chars.count && chars[c] == "#" {
                    let rect = CGRect(
                        x: startX + CGFloat(c) * pixelSize,
                        y: startY + CGFloat(r) * pixelSize,
                        width: pixelSize - 0.22,
                        height: pixelSize - 0.22
                    )
                    var glowCtx = context
                    glowCtx.addFilter(.shadow(color: color.opacity(0.48), radius: 0.8, x: 0, y: 0))
                    glowCtx.fill(Path(rect), with: .color(color))
                }
            }
        }
    }

    // Frame A：安静漂浮，三点裙摆
    private var frameA: [String] {
        [
            "....########....",
            "...##########...",
            "..############..",
            "..##..####..##..",
            "..############..",
            "..############..",
            "..############..",
            "...##########...",
            "..###.##.##.###.",
            "..#..#..#..#..#.",
            "................",
            "................"
        ]
    }

    // Frame B：抬手、裙摆错位
    private var frameB: [String] {
        [
            "....########....",
            "...##########...",
            ".##############.",
            ".###..####..###.",
            "..##..####..##..",
            "..############..",
            "..############..",
            "...##########...",
            "...##.##.##.##..",
            "...#..#..#..#...",
            "................",
            "................"
        ]
    }

    // Frame C：张嘴、裙摆散开
    private var frameC: [String] {
        [
            "....########....",
            "...##########...",
            "..############..",
            "..##..####..##..",
            "..############..",
            "..###......###..",
            "..############..",
            "...##########...",
            ".#.##.##.##.##.#",
            "#..#..#..#..#..#",
            "................",
            "................"
        ]
    }

    private func drawPixelZs(context: inout GraphicsContext, t: Double, originX: CGFloat, originY: CGFloat) {
        let configs: [(phaseOffset: Double, offsetX: CGFloat, startY: CGFloat)] = [
            (0.0, 0.0, originY + 1),
            (1.0, 2.5, originY - 2),
            (2.0, -2.0, originY - 4)
        ]

        for config in configs {
            let phase = (t + config.phaseOffset).truncatingRemainder(dividingBy: 3.0)
            let progress = phase / 3.0
            let floatUp = progress * 7.0
            let driftX = sin((t + config.phaseOffset) * 1.8) * 0.5
            let opacity = max(0.0, 0.82 - progress * 0.8)
            let zText = Text("Z")
                .font(.system(size: 4.2, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(opacity))
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
            let rect = CGRect(
                x: startX + CGFloat(i) * spacing - dotSize / 2,
                y: topY - dotSize / 2,
                width: dotSize,
                height: dotSize
            )
            context.fill(Path(rect), with: .color(.white.opacity(opacity)))
        }
    }
}
