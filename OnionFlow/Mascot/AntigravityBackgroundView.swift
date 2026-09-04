import AppKit
import SwiftUI

// 星云用径向渐变代替实时 blur；粒子用 CALayer 位移，避免展开态整幅 Canvas 跟帧。
struct AntigravityBackgroundView: View {
    let isPlaying: Bool
    var isLoading: Bool = false
    let showNebula: Bool
    let showParticles: Bool
    let nebulaTheme: NebulaTheme

    var body: some View {
        ZStack {
            nebulaTheme.baseBackground

            if showNebula {
                GeometryReader { geo in
                    let width = geo.size.width
                    let height = geo.size.height
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [nebulaTheme.color1, nebulaTheme.color1.opacity(0)],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: width * 0.42
                                )
                            )
                            .frame(width: width * 0.8, height: width * 0.8)
                            .offset(x: -width * 0.15, y: height * 0.12)

                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [nebulaTheme.color2, nebulaTheme.color2.opacity(0)],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: width * 0.38
                                )
                            )
                            .frame(width: width * 0.7, height: width * 0.7)
                            .offset(x: width * 0.15, y: -height * 0.08)
                    }
                    .frame(width: width, height: height)
                }
            }

            if showParticles, isPlaying || isLoading {
                ParticleFieldView()
            }
        }
        .allowsHitTesting(false)
    }
}

private struct ParticleFieldView: NSViewRepresentable {
    func makeNSView(context: Context) -> ParticleFieldNSView {
        ParticleFieldNSView()
    }

    func updateNSView(_ nsView: ParticleFieldNSView, context: Context) {}
}

private struct ParticleSpec {
    let size: CGFloat
    let peakOpacity: Float
    let glow: Bool
}

private final class ParticleFieldNSView: NSView {
    private var particleLayers: [CALayer] = []
    private var particleSpecs: [ParticleSpec] = []
    private let particleCount = 16
    /// 按整岛最大高度飞，开关只改变裁剪区域，不重起动画。
    private let travelHeight: CGFloat = 720

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        if particleLayers.isEmpty {
            buildParticles()
        }
        startIfNeeded()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            particleLayers.forEach { $0.removeAllAnimations() }
        } else {
            startIfNeeded()
        }
    }

    /// 按序号拉开尘点 / 中点 / 亮点，避免所有粒子同一亮度。
    private func spec(for index: Int) -> ParticleSpec {
        switch index % 8 {
        case 0:
            return ParticleSpec(size: 4.5, peakOpacity: 0.95, glow: true)
        case 4:
            return ParticleSpec(size: 3.4, peakOpacity: 0.72, glow: true)
        case 2, 6:
            return ParticleSpec(size: 2.4, peakOpacity: 0.40, glow: false)
        default:
            return ParticleSpec(size: 1.4, peakOpacity: 0.18, glow: false)
        }
    }

    private func buildParticles() {
        guard let host = layer else { return }
        for index in 0..<particleCount {
            let spec = spec(for: index)
            let particle = CALayer()
            particle.bounds = CGRect(x: 0, y: 0, width: spec.size, height: spec.size)
            particle.cornerRadius = spec.size / 2
            particle.backgroundColor = NSColor.white.cgColor
            if spec.glow {
                particle.shadowColor = NSColor.white.cgColor
                particle.shadowRadius = spec.size * 1.1
                particle.shadowOpacity = 0.85
                particle.shadowOffset = .zero
            }
            host.addSublayer(particle)
            particleLayers.append(particle)
            particleSpecs.append(spec)
        }
    }

    private func startIfNeeded() {
        guard window != nil, !bounds.isEmpty, !particleLayers.isEmpty else { return }
        for (index, particle) in particleLayers.enumerated() {
            guard particle.animation(forKey: "rise") == nil else { continue }
            let spec = particleSpecs[index]
            let seed = CGFloat(index)
            let startX = bounds.width * (0.07 + (seed * 0.063).truncatingRemainder(dividingBy: 0.86))
            particle.position = CGPoint(x: startX, y: -4)
            let duration = spec.glow ? 9.5 + Double(index % 3) * 1.2 : 6.2 + Double(index % 5) * 0.8
            let drift: CGFloat = spec.glow ? 6 : (index % 2 == 0 ? 12 : -12)
            let move = CABasicAnimation(keyPath: "position")
            move.fromValue = NSValue(point: CGPoint(x: startX, y: -6))
            move.toValue = NSValue(point: CGPoint(x: startX + drift, y: travelHeight))
            move.timingFunction = CAMediaTimingFunction(name: .linear)

            let fade = CAKeyframeAnimation(keyPath: "opacity")
            if spec.glow {
                fade.values = [0, spec.peakOpacity, spec.peakOpacity * 0.88, 0]
                fade.keyTimes = [0, 0.28, 0.62, 1]
            } else {
                fade.values = [0, spec.peakOpacity, 0]
                fade.keyTimes = [0, 0.5, 1]
            }

            let group = CAAnimationGroup()
            group.animations = [move, fade]
            group.duration = duration
            group.repeatCount = .infinity
            group.beginTime = CACurrentMediaTime() + CFTimeInterval(index) * 0.22
            group.isRemovedOnCompletion = false
            particle.add(group, forKey: "rise")
        }
    }
}
