import SwiftUI

// 播放中状态共用的音符特效：4 到 6 个音符围绕角色跳动，位置按周期伪随机变化。
enum MascotMusicNotesEffect {
    static func draw(context: inout GraphicsContext, t: Double, cx: CGFloat, cy: CGFloat) {
        let symbols = ["♪", "♫", "♬", "♩"]
        let shuffleInterval = 2.4
        let shuffleCycle = floor(t / shuffleInterval)
        let anchors: [(x: Double, y: Double)] = [
            (-0.65, -1.00),
            (0.10, -1.10),
            (0.78, -0.72),
            (1.00, 0.18),
            (0.62, 0.78),
            (0.18, 0.95),
            (-0.48, 0.78),
            (-0.98, 0.18),
        ]
        let noteCount = 4 + Int(floor(randomUnit(seed: shuffleCycle * 29.0) * 3.0))
        let shuffledAnchorIndexes = shuffledIndexes(count: anchors.count, cycle: shuffleCycle)
        for index in 0..<noteCount {
            let localTime = t + Double(index) * 0.47
            let cycle = floor(localTime / 2.2)
            let progress = localTime.truncatingRemainder(dividingBy: 2.2) / 2.2
            let anchor = anchors[shuffledAnchorIndexes[index]]
            let radius = 10.5 + randomUnit(seed: cycle * 3.0 + Double(index) * 11.0) * 2.6
            let jump = sin(progress * .pi) * 3.8
            let wobbleX = sin(localTime * 4.0 + Double(index)) * 0.85
            let wobbleY = cos(localTime * 3.4 + Double(index) * 0.6) * 0.55
            let x = cx + CGFloat(anchor.x * radius + wobbleX)
            let y = cy + CGFloat(anchor.y * radius - jump + wobbleY)
            let opacity = 0.32 + 0.62 * sin(progress * .pi)
            let fontSize = CGFloat(5.0 + randomUnit(seed: cycle * 5.0 + Double(index) * 7.0) * 2.8)
            let note = Text(symbols[index % symbols.count])
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(opacity))
            context.draw(note, at: CGPoint(x: x, y: y))
        }
    }

    static func isEyeOpen(t: Double, seed: Double) -> Bool {
        let cycleLength = 2.1 + randomUnit(seed: seed) * 1.4
        let phase = (t + seed * 0.37).truncatingRemainder(dividingBy: cycleLength)
        return phase > 0.08 + randomUnit(seed: seed + floor(t / cycleLength)) * 0.08
    }

    private static func shuffledIndexes(count: Int, cycle: Double) -> [Int] {
        (0..<count).sorted {
            randomUnit(seed: cycle * 19.0 + Double($0) * 7.0) < randomUnit(seed: cycle * 19.0 + Double($1) * 7.0)
        }
    }

    private static func randomUnit(seed: Double) -> Double {
        let value = sin(seed * 12.9898 + 78.233) * 43758.5453
        return value - floor(value)
    }
}
