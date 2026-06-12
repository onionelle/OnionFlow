import SwiftUI

/// compact 右侧的单线 + 音谱律动指示器。
/// 遵循 DESIGN.md 规范，支持多种频谱风格的选择并可在设置中切换和持久化：
/// 1. 翡翠晶柱 ("columns")：经典 5 栏垂直霓虹跳跃音轨。
/// 2. 极简声波 ("wave")：优雅流畅的多重谐波正弦曲线，随低中高音频段波动。
/// 3. 灵动呼吸 ("breathing")：中间一个悬浮的极简胶囊，尺寸和发光度随重低音重拍起落而向外呼吸晕染。
/// 4. 科幻脉冲 ("pulse")：5 栏垂直上下对称双向跳动的晶柱。
struct CompactMusicActivityIndicator: View {
    @ObservedObject var musicViewModel: MusicPlayerViewModel
    @AppStorage("spectrumStyle") private var spectrumStyle = "columns"

    private var state: MusicPlayerState {
        musicViewModel.state
    }

    private var isPlaying: Bool {
        state == .playing
    }

    private var hasMusicContext: Bool {
        switch state {
        case .playing, .paused, .loading:
            return true
        case .idle, .failed:
            return false
        }
    }

    var body: some View {
        ZStack {
            if isPlaying {
                TimelineView(.periodic(from: Date(), by: 1.0 / 30.0)) { timeline in
                    indicatorCanvas(time: timeline.date.timeIntervalSinceReferenceDate)
                }
            } else {
                indicatorCanvas(time: 0)
            }
        }
        .frame(width: 30, height: 14)
    }

    private func indicatorCanvas(time: TimeInterval) -> some View {
        Canvas { context, size in
            let baseColor = Color(red: 0.16, green: 0.82, blue: 0.50) // 翡翠荧光绿，与主视觉高度一致
            let highlightColor = Color(red: 0.55, green: 1.0, blue: 0.78) // 荧光绿亮面高光
            let idleColor = Color.white.opacity(0.24) // 闲时纯白微弱晶体点/线
            let pausedColor = baseColor.opacity(0.38) // 暂停时翡翠绿微弱晶体点/线
            let activeColor = hasMusicContext ? pausedColor : idleColor

            let style = SpectrumStyle(rawValue: spectrumStyle) ?? .columns

            switch style {
            case .columns:
                // 1. 翡翠晶柱风格：底部基准，垂直向上跳跃的 5 栏霓虹柱
                let baseline = size.height - 1.5
                let barWidth: CGFloat = 2.0
                let xPositions: [CGFloat] = [3, 9, 15, 21, 27]

                if isPlaying {
                    let factors: [CGFloat] = [
                        bassValue(time: time),
                        lowMidValue(time: time),
                        midValue(time: time),
                        highMidValue(time: time),
                        trebleValue(time: time)
                    ]

                    var glowContext = context
                    glowContext.addFilter(.shadow(color: baseColor.opacity(0.50), radius: 2.0, x: 0, y: 0))

                    for i in 0..<5 {
                        let x = xPositions[i]
                        let maxJumpHeight = size.height - 3.5
                        let barHeight = max(1.5, factors[i] * maxJumpHeight)

                        var barPath = Path()
                        barPath.move(to: CGPoint(x: x, y: baseline))
                        barPath.addLine(to: CGPoint(x: x, y: baseline - barHeight))

                        glowContext.stroke(
                            barPath,
                            with: .color(baseColor.opacity(0.78)),
                            style: StrokeStyle(lineWidth: 2.0, lineCap: .round)
                        )

                        context.stroke(
                            barPath,
                            with: .color(highlightColor),
                            style: StrokeStyle(lineWidth: 1.6, lineCap: .round)
                        )
                    }
                } else {
                    // 暂停/闲置：极简静态 5 短点
                    for i in 0..<5 {
                        let x = xPositions[i]
                        var dotPath = Path()
                        dotPath.move(to: CGPoint(x: x, y: baseline))
                        dotPath.addLine(to: CGPoint(x: x, y: baseline - 1.5))

                        context.stroke(
                            dotPath,
                            with: .color(activeColor),
                            style: StrokeStyle(lineWidth: barWidth, lineCap: .round)
                        )
                    }
                }

            case .wave:
                // 2. 极简声波风格：优雅的多重谐波正弦波动曲线
                let centerY = size.height / 2.0

                if isPlaying {
                    let bass = bassValue(time: time)
                    let mid = midValue(time: time)
                    let treble = trebleValue(time: time)

                    var glowContext = context
                    glowContext.addFilter(.shadow(color: baseColor.opacity(0.60), radius: 2.5, x: 0, y: 0))

                    var path = Path()
                    let step: CGFloat = 1.0
                    var started = false

                    for x in stride(from: 2.0, through: 28.0, by: step) {
                        let normX = (x - 2.0) / 26.0

                        // 重低音控制第一层慢波振幅，中音控制第二层中波，高音控制第三层快波微震
                        let amp1 = bass * 4.0 * sin(normX * .pi * 2.0 - time * 6.0)
                        let amp2 = mid * 2.5 * sin(normX * .pi * 4.5 + time * 9.0)
                        let amp3 = treble * 1.2 * sin(normX * .pi * 8.0 - time * 16.0)

                        let y = centerY + amp1 + amp2 + amp3

                        if !started {
                            path.move(to: CGPoint(x: x, y: y))
                            started = true
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }

                    glowContext.stroke(
                        path,
                        with: .color(baseColor.opacity(0.80)),
                        style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
                    )

                    context.stroke(
                        path,
                        with: .color(highlightColor),
                        style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round)
                    )
                } else {
                    // 暂停/闲置：一条极其静谧的低透明度基准直线
                    var path = Path()
                    path.move(to: CGPoint(x: 2.0, y: centerY))
                    path.addLine(to: CGPoint(x: 28.0, y: centerY))

                    context.stroke(
                        path,
                        with: .color(activeColor),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                    )
                }

            case .breathing:
                // 3. 灵动呼吸风格：发光呼吸药丸舱，随低音重击发生横向纵向有弹性形变及光晕呼吸
                let center = CGPoint(x: size.width / 2.0, y: size.height / 2.0)

                if isPlaying {
                    let bass = bassValue(time: time)
                    let mid = midValue(time: time)

                    // 以 11x5.5 胶囊为基础
                    let baseW: CGFloat = 11.0
                    let baseH: CGFloat = 5.5

                    // 横向由重低音膨胀，纵向由中音微调
                    let w = baseW * (1.0 + bass * 0.7)
                    let h = baseH * (1.0 + mid * 0.4)

                    let rect = CGRect(x: center.x - w/2.0, y: center.y - h/2.0, width: w, height: h)

                    // 绘制外发光光晕层
                    var glowContext = context
                    let glowRadius = 3.0 + bass * 3.5
                    glowContext.addFilter(.shadow(color: baseColor.opacity(0.45 + bass * 0.45), radius: glowRadius, x: 0, y: 0))

                    let haloRect = rect.insetBy(dx: -1.5 - bass * 2.0, dy: -1.0 - bass * 1.0)
                    glowContext.fill(
                        Path(roundedRect: haloRect, cornerRadius: haloRect.height / 2.0),
                        with: .color(baseColor.opacity(0.24 - bass * 0.10))
                    )

                    // 绘制内层高透高光胶囊
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: rect.height / 2.0),
                        with: .color(highlightColor)
                    )
                } else {
                    // 暂停/闲置：极简收缩为一颗超微型小胶囊
                    let rect = CGRect(x: center.x - 3.5, y: center.y - 1.5, width: 7.0, height: 3.0)
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: 1.5),
                        with: .color(activeColor)
                    )
                }

            case .pulse:
                // 4. 科幻脉冲风格：上下对称、垂直双向拉伸跳跃的 5 栏声谱仪
                let centerY = size.height / 2.0
                let barWidth: CGFloat = 2.0
                let xPositions: [CGFloat] = [3, 9, 15, 21, 27]

                if isPlaying {
                    let factors: [CGFloat] = [
                        bassValue(time: time),
                        lowMidValue(time: time),
                        midValue(time: time),
                        highMidValue(time: time),
                        trebleValue(time: time)
                    ]

                    var glowContext = context
                    glowContext.addFilter(.shadow(color: baseColor.opacity(0.55), radius: 2.0, x: 0, y: 0))

                    for i in 0..<5 {
                        let x = xPositions[i]
                        let maxHalfHeight = (size.height - 3.5) / 2.0
                        let halfHeight = max(1.0, factors[i] * maxHalfHeight)

                        var barPath = Path()
                        barPath.move(to: CGPoint(x: x, y: centerY - halfHeight))
                        barPath.addLine(to: CGPoint(x: x, y: centerY + halfHeight))

                        glowContext.stroke(
                            barPath,
                            with: .color(baseColor.opacity(0.78)),
                            style: StrokeStyle(lineWidth: 2.0, lineCap: .round)
                        )

                        context.stroke(
                            barPath,
                            with: .color(highlightColor),
                            style: StrokeStyle(lineWidth: 1.6, lineCap: .round)
                        )
                    }
                } else {
                    // 暂停/闲置：对称缩为 5 个极矮的微型垂直小晶针
                    for i in 0..<5 {
                        let x = xPositions[i]
                        var dotPath = Path()
                        dotPath.move(to: CGPoint(x: x, y: centerY - 0.75))
                        dotPath.addLine(to: CGPoint(x: x, y: centerY + 0.75))

                        context.stroke(
                            dotPath,
                            with: .color(activeColor),
                            style: StrokeStyle(lineWidth: barWidth, lineCap: .round)
                        )
                    }
                }
            }
        }
    }

    // ==========================================
    // 多频段高能疾速分形与极速大起大落声学引擎
    // ==========================================

    private func bassValue(time: TimeInterval) -> CGFloat {
        // 低音频段：宽、重、爆发力极强。
        let rawBeat = sin(time * .pi * 2.88)
        let swingMod = cos(time * .pi * 0.65) * 0.12 // 大幅调低潮汐占比，凸显清脆的重拍重击
        let baseSignal = rawBeat * 0.88 + swingMod

        // 瞬间暴冲包络：极速起拍，极其平滑利落的摩擦阻尼下落。地板值降至 0.04
        let pulse = pow(max(0.0, baseSignal), 2.6) * 1.15
        let rumble = cos(time * .pi * 2.2) * 0.06 // 极速余响

        return CGFloat(min(1.0, max(0.04, 0.08 + pulse + rumble)))
    }

    private func lowMidValue(time: TimeInterval) -> CGFloat {
        // 中低音：节奏辅拍
        let rawBeat = cos(time * .pi * 3.66 + 0.6)
        let swingMod = sin(time * .pi * 0.85) * 0.12
        let baseSignal = rawBeat * 0.88 + swingMod

        let pulse = pow(max(0.0, baseSignal), 2.2) * 1.05
        let swing = cos(time * .pi * 3.14) * 0.08

        return CGFloat(min(1.0, max(0.03, 0.06 + pulse + swing)))
    }

    private func midValue(time: TimeInterval) -> CGFloat {
        // 中频段：活跃主旋律。呼吸频率提速，喘息起伏感强
        let breath = 0.40 + 0.60 * sin(time * .pi * 0.65)

        // 黄金三层嵌套噪波频率全面跃升
        let v1 = sin(time * .pi * 5.84)
        let v2 = cos(time * .pi * 9.88) * 0.48
        let v3 = sin(time * .pi * 16.5) * 0.25

        let rawMid = abs(v1 + v2 + v3) / 1.45
        let pulse = pow(rawMid, 1.5) * 1.2 * breath

        return CGFloat(min(1.0, max(0.06, 0.06 + pulse)))
    }

    private func highMidValue(time: TimeInterval) -> CGFloat {
        // 中高音：清脆瞬态
        let w = sin(time * .pi * 9.34)
        let j = cos(time * .pi * 18.5) * 0.38
        let raw = max(0.0, w + j)

        let amplitudeMod = 0.55 + 0.45 * cos(time * .pi * 0.95)
        let pulse = pow(raw, 1.7) * 1.2 * amplitudeMod

        return CGFloat(min(1.0, max(0.04, 0.05 + pulse)))
    }

    private func trebleValue(time: TimeInterval) -> CGFloat {
        // 高音频段：极速沙锤闪烁
        let shimmer = sin(time * .pi * 22.4) * 0.6
        let sparkle = cos(time * .pi * 42.8) * 0.4
        let raw = abs(shimmer + sparkle)

        let glitterMod = 0.20 + 0.80 * pow(0.5 + 0.5 * sin(time * .pi * 1.58), 2.0)
        let pulse = raw * glitterMod

        return CGFloat(min(1.0, max(0.02, 0.03 + pulse)))
    }
}
