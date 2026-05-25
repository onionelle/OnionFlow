import SwiftUI

/// NookFlow 专属的高级紧凑态音乐活动指示器 (Premium Equalizer Waveform)
/// 采用了横向色彩渐变、霓虹外发光投影以及独特的「多频率波形合成算法」，呈现极具灵动和弹性的声波律动。
/// 特别设计了基于 SwiftUI Spring 的过渡衰减机制：当音乐暂停或加载时，波形会顺滑地过渡到静态正弦曲线，而不是突兀冻结。
struct CompactMusicActivityIndicator: View {
    /// 播放状态
    let state: MusicPlayerState

    /// 是否正在播放
    private var isPlaying: Bool {
        state == .playing
    }

    /// 是否有处于激活的音乐播放上下文（播放中、已暂停、加载中均算有上下文）
    private var hasMusicContext: Bool {
        switch state {
        case .playing, .paused, .loading:
            return true
        case .idle, .failed:
            return false
        }
    }

    var body: some View {
        if isPlaying {
            // 播放状态下：利用 TimelineView 以高帧率 (60Hz/120Hz) 驱动时间线，实现细腻平滑的动态声波
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                indicatorView(time: time)
            }
        } else {
            // 暂停/加载/静止状态下：通过恒定时间戳 0 展现静态曲线，且在 isPlaying 改变时享受 SwiftUI 默认的弹簧过渡动画
            indicatorView(time: 0)
                .animation(.spring(response: 0.45, dampingFraction: 0.75), value: isPlaying)
        }
    }

    /// 构建指示器主体布局
    /// - Parameter time: 驱动动画的累积时间戳。静态态传入 0。
    @ViewBuilder
    private func indicatorView(time: TimeInterval) -> some View {
        HStack(spacing: 1.8) {
            ForEach(0..<5, id: \.self) { index in
                Capsule()
                    .fill(barColor(index: index))
                    // 高度计算采用插值与非线性缩放，以获得弹性的峰值移动质感
                    .frame(width: 2.2, height: barHeight(index: index, time: time))
                    // 播放时附加霓虹发光阴影以增强视觉存在感，阴影颜色与音量条颜色完美匹配
                    .shadow(color: barColor(index: index).opacity(isPlaying ? 0.45 : 0.0), radius: 1.5)
            }
        }
        .frame(width: 33, height: 18)
        .background(
            // 带有轻微半透明度的 Capsule 作为毛玻璃质感的背板容器
            Capsule()
                .fill(Color.white.opacity(hasMusicContext ? 0.06 : 0.03))
        )
        .overlay(
            // 精细的极细高光描边，体现 macOS 原生应用的高级雕琢感
            Capsule()
                .stroke(Color.white.opacity(hasMusicContext ? 0.12 : 0.05), lineWidth: 0.6)
        )
    }

    /// 计算每个音量条独特的色彩梯度，从深蓝到荧光绿、再到柠檬黄，实现横跨 5 根音量条的流线渐变
    /// - Parameter index: 音量条索引 (0 到 4)
    private func barColor(index: Int) -> Color {
        guard hasMusicContext else {
            // 无音乐上下文时返回极低对比度的半透明灰色
            return Color.white.opacity(0.24)
        }

        if !isPlaying {
            // 暂停状态下采用柔和的静止灰色，避免视觉喧宾夺主
            return Color.white.opacity(0.48)
        }

        // 充满科技感与生命力的靛蓝到荧光绿渐变调色板 (NookFlow Premium Palette)
        let colors = [
            Color(red: 0.18, green: 0.50, blue: 0.95), // 0: 深邃靛蓝 (Deep Indigo Blue)
            Color(red: 0.18, green: 0.68, blue: 0.90), // 1: 清澈天蓝 (Sky Blue)
            Color(red: 0.15, green: 0.80, blue: 0.75), // 2: 极光青绿 (Cyan/Teal)
            Color(red: 0.16, green: 0.82, blue: 0.50), // 3: 荧光翡翠 (Neon Emerald Green)
            Color(red: 0.60, green: 0.88, blue: 0.30)  // 4: 琥珀酸绿 (Amber Green/Lime)
        ]
        return colors[index]
    }

    /// 高级声波波形高度合成算法
    /// - Parameters:
    ///   - index: 音量条索引
    ///   - time: 驱动正弦波的时间偏移量
    /// - Returns: 计算出的高度值 (CGSize/CGFloat)
    private func barHeight(index: Int, time: TimeInterval) -> CGFloat {
        guard hasMusicContext else {
            // 没有任何音乐上下文时，退化为统一的最小圆点 (2.2pt)
            return 2.2
        }

        guard isPlaying else {
            // 暂停状态：返回一个优雅起伏的对称静态声波，并由外层 SwiftUI Spring 动画执行淡出与高度缩减
            return [5, 9, 4, 7, 3][index]
        }

        // 多重频率谐波合成 (Multi-Harmonic Synthesis)：
        // 混合了 3 组具有不同角速度与空间相位偏移的正弦/余弦曲线。
        // 这避免了单一正弦波单调、死板的简谐振动感，更接近真实音频的无规则跳跃与动态质感。
        let baseSpeed = 7.2
        let phase1 = time * baseSpeed + Double(index) * 1.45
        let phase2 = time * (baseSpeed * 0.55) - Double(index) * 0.85
        let phase3 = time * (baseSpeed * 1.35) + Double(index) * 2.10

        let val1 = sin(phase1)
        let val2 = cos(phase2)
        let val3 = sin(phase3) * 0.4

        // 累加混合波形并标准化至 [0, 1] 空间
        let combined = (val1 + val2 + val3) / 2.4
        let normalized = (combined + 1.0) / 2.0

        // 幂函数非线性整形 (Cubic Response Curve)：
        // 利用 `pow(x, 1.4)` 稍微压制低振幅，同时突起高振幅。
        // 这样可以使波形跳跃时"触顶"更迅速，下落更有顿挫感，呈现出极具弹性和爆发力的视觉质感。
        let cubic = pow(normalized, 1.4)

        // 高度范围锁定在 2.5pt 到 12.5pt 之间，确保在 18pt 容器内留有呼吸感
        return 2.5 + cubic * 10
    }
}
