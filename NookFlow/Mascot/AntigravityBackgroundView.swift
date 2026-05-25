import SwiftUI

// Antigravity 风格的深空星云与漂浮粒子特效背景。
// 结合 TimelineView 与 Canvas 绘制无状态、高性能的失重上升粒子，并配合音乐播放联动速度。
struct AntigravityBackgroundView: View {
    @ObservedObject var musicViewModel: MusicPlayerViewModel
    
    // 配色定义，使用靛蓝与深紫构建优雅的深空星云感
    private let spaceBackground = Color(red: 0.035, green: 0.035, blue: 0.065)
    private let indigoNebula = Color(red: 0.12, green: 0.08, blue: 0.26).opacity(0.42)
    private let purpleNebula = Color(red: 0.20, green: 0.06, blue: 0.30).opacity(0.38)
    
    private let particleCount = 18

    var body: some View {
        TimelineView(.animation) { timeline in
            let date = timeline.date
            let t = date.timeIntervalSinceReferenceDate
            
            // 播放状态下速度增加 1.5 倍，带来更充沛的流动感；未播放时维持 0.8 倍的静谧流动
            let speedMultiplier = musicViewModel.state == .playing ? 1.5 : 0.8
            let animatedTime = t * speedMultiplier
            
            ZStack {
                // 1. 基础深色背景
                spaceBackground
                
                // 2. 动态星云呼吸渐变（通过两个不同相位和方向的渐变圆慢速平移，构成星云交融的呼吸感）
                GeometryReader { geo in
                    let width = geo.size.width
                    let height = geo.size.height
                    
                    // 慢周期的平移与微幅摆动
                    let offset1X = sin(t * 0.10) * (width * 0.14)
                    let offset1Y = cos(t * 0.07) * (height * 0.10)
                    let offset2X = cos(t * 0.09) * (width * 0.16)
                    let offset2Y = sin(t * 0.12) * (height * 0.08)
                    
                    ZStack {
                        Circle()
                            .fill(indigoNebula)
                            .frame(width: width * 0.8, height: width * 0.8)
                            .blur(radius: width * 0.18)
                            .offset(x: -width * 0.15 + offset1X, y: height * 0.12 + offset1Y)
                        
                        Circle()
                            .fill(purpleNebula)
                            .frame(width: width * 0.7, height: width * 0.7)
                            .blur(radius: width * 0.20)
                            .offset(x: width * 0.15 + offset2X, y: -height * 0.08 + offset2Y)
                    }
                    .frame(width: width, height: height)
                }
                
                // 3. 高性能失重上升粒子层
                Canvas { context, size in
                    for i in 0..<particleCount {
                        // 基于 seed 的数学确定性伪随机分配，避免无状态 Canvas 每一帧重置状态导致的闪烁
                        let seed = Double(i) * 31.82
                        let randomSpeed = randomUnit(seed: seed + 5.3)
                        let randomXFactor = randomUnit(seed: seed + 12.7)
                        let randomScale = 0.5 + randomUnit(seed: seed + 25.1) * 0.7
                        let randomOpacityFactor = 0.25 + randomUnit(seed: seed + 42.9) * 0.45
                        
                        // 每个粒子的漂浮时长（在 6 到 11 秒之间）
                        let duration = 6.0 + randomSpeed * 5.0
                        // 计算当前粒子在所属生命周期内的归一化进度 [0.0, 1.0)
                        let progress = (animatedTime + seed).truncatingRemainder(dividingBy: duration) / duration
                        
                        // y 轴位置：从画布底部匀速漂浮至顶部
                        let y = size.height - (progress * size.height)
                        
                        // x 轴位置：横向基准分配 + 慢速正弦左右漂移
                        let wobbleAngle = animatedTime * (0.4 + randomSpeed * 0.4) + seed
                        let wobble = sin(wobbleAngle) * 10.0
                        let x = (randomXFactor * size.width) + wobble
                        
                        // 粒子物理属性：中间最亮、上下边缘渐变淡入淡出
                        let radius = 2.4 * randomScale
                        let opacity = sin(progress * .pi) * randomOpacityFactor
                        
                        let rect = CGRect(
                            x: x - radius,
                            y: y - radius,
                            width: radius * 2,
                            height: radius * 2
                        )
                        
                        var path = Path()
                        path.addEllipse(in: rect)
                        
                        // 绘制带有对应透明度的漂浮微粒
                        context.opacity = opacity
                        context.fill(path, with: .color(Color.white.opacity(0.85)))
                    }
                }
            }
        }
        .allowsHitTesting(false) // 完全穿透鼠标事件，保证灵动岛的其余手势不受影响
    }
    
    // 基于正弦波的高效无状态伪随机数生成器
    private func randomUnit(seed: Double) -> Double {
        let value = sin(seed * 12.9898 + 78.233) * 43758.5453
        return value - floor(value)
    }
}
