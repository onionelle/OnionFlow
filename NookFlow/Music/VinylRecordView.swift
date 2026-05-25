import SwiftUI

/// 一个极具质感、动态旋转的黑胶唱片视图。
/// 播放时顺滑匀速旋转 (60Hz/120Hz 满帧刷新)，暂停时优雅静止，并且叠加了不随旋转移动的静态金属高光扫掠，呈现出极其逼真的立体质感。
struct VinylRecordView: View {
    /// 播放状态
    let isPlaying: Bool
    
    /// 当前旋转角度
    @State private var rotationAngle: Double = 0
    /// 上次更新的时间戳，用于高精度计算增量时间
    @State private var lastUpdate: Date = Date()
    
    var body: some View {
        ZStack {
            // 1. 旋转的黑胶唱片主体
            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isPlaying)) { timeline in
                Canvas { context, size in
                    drawVinylDisc(in: context, size: size)
                }
                .rotationEffect(.degrees(rotationAngle))
                .onChange(of: timeline.date) { newDate in
                    if isPlaying {
                        let delta = newDate.timeIntervalSince(lastUpdate)
                        // 每秒旋转 45 度，带来既沉稳又动感的视觉感受
                        rotationAngle = (rotationAngle + delta * 45.0).truncatingRemainder(dividingBy: 360)
                    }
                    lastUpdate = newDate
                }
            }
            
            // 2. 静态金属高光扫掠（不随唱片旋转，从而模拟真实反射光效）
            Canvas { context, size in
                drawStaticGloss(in: context, size: size)
            }
            .blendMode(.overlay)
            .allowsHitTesting(false)
        }
        .frame(width: 44, height: 44)
        .onAppear {
            lastUpdate = Date()
        }
        .onChange(of: isPlaying) { playing in
            if playing {
                lastUpdate = Date()
            }
        }
    }
    
    /// 绘制黑胶盘片主体（唱道、中圈贴纸与轴心）
    private func drawVinylDisc(in context: GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) / 2
        
        let vinylRect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        
        // A. 基础盘身：黑曜石暗灰径向渐变
        let gradient = Gradient(colors: [
            Color(red: 0.12, green: 0.12, blue: 0.14),
            Color(red: 0.05, green: 0.05, blue: 0.06),
            Color(red: 0.12, green: 0.12, blue: 0.14)
        ])
        context.fill(Path(ellipseIn: vinylRect), with: .radialGradient(gradient, center: center, startRadius: 0, endRadius: radius))
        
        // B. 同心音轨线：超细的高质感白线，低透明度
        let grooveColor = Color.white.opacity(0.06)
        for rOffset in [0.88, 0.78, 0.68, 0.58, 0.48] {
            let r = radius * rOffset
            let grooveRect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
            context.stroke(Path(ellipseIn: grooveRect), with: .color(grooveColor), lineWidth: 0.5)
        }
        
        // C. 中间轴心贴纸：NookFlow 标志性荧光绿到天蓝渐变
        let stickerRadius = radius * 0.38
        let stickerRect = CGRect(x: center.x - stickerRadius, y: center.y - stickerRadius, width: stickerRadius * 2, height: stickerRadius * 2)
        let stickerGradient = Gradient(colors: [
            Color(red: 0.16, green: 0.82, blue: 0.50), // 荧光绿
            Color(red: 0.18, green: 0.68, blue: 0.90)  // 天空蓝
        ])
        context.fill(Path(ellipseIn: stickerRect), with: .linearGradient(stickerGradient, startPoint: CGPoint(x: stickerRect.minX, y: stickerRect.minY), endPoint: CGPoint(x: stickerRect.maxX, y: stickerRect.maxY)))
        
        // D. 贴纸内部设计线：白细圆环
        let ringRadius = stickerRadius * 0.7
        let ringRect = CGRect(x: center.x - ringRadius, y: center.y - ringRadius, width: ringRadius * 2, height: ringRadius * 2)
        context.stroke(Path(ellipseIn: ringRect), with: .color(.white.opacity(0.35)), lineWidth: 0.6)
        
        // E. 中心金属轴孔
        let spindleRadius = radius * 0.08
        let spindleRect = CGRect(x: center.x - spindleRadius, y: center.y - spindleRadius, width: spindleRadius * 2, height: spindleRadius * 2)
        context.fill(Path(ellipseIn: spindleRect), with: .color(Color(red: 0.02, green: 0.02, blue: 0.03)))
    }
    
    /// 绘制静态反射高光扫掠，模拟唱片对着灯光时的 45 度双向金属反光
    private func drawStaticGloss(in context: GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) / 2
        
        // 绘制两扇扇形高光区，以 45° 和 225° 为中心对称分布
        var path1 = Path()
        path1.move(to: center)
        path1.addArc(center: center, radius: radius, startAngle: .degrees(-55), endAngle: .degrees(-35), clockwise: false)
        path1.closeSubpath()
        
        var path2 = Path()
        path2.move(to: center)
        path2.addArc(center: center, radius: radius, startAngle: .degrees(125), endAngle: .degrees(145), clockwise: false)
        path2.closeSubpath()
        
        let glossGradient = Gradient(colors: [
            Color.white.opacity(0.20),
            Color.white.opacity(0.0)
        ])
        
        context.fill(path1, with: .radialGradient(glossGradient, center: center, startRadius: 0, endRadius: radius))
        context.fill(path2, with: .radialGradient(glossGradient, center: center, startRadius: 0, endRadius: radius))
    }
}
