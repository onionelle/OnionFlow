import AppKit
import SwiftUI

/// 角色姿态由 Canvas 绘制。
/// idle / music：先画 SwiftUI Canvas（保证首帧有图），再截成位图交给 CALayer。
/// 位移用合成器插值，切帧只换 contents，播放时也能保持流畅且不跟屏幕刷新重画点阵。
struct MascotRenderedCanvas: View {
    let size: CGFloat
    let isStatic: Bool
    let state: MascotState
    var idleAmplitude: CGFloat = 0.6
    let draw: (inout GraphicsContext, CGSize, Date) -> Void

    private static let frozenDate = Date(timeIntervalSinceReferenceDate: 0)
    private static let musicFrameCount = 16
    // 按原版 12fps 取样并回放，避免位图切帧比 Canvas 更快。
    private static let musicFrameRate: TimeInterval = 12
    private static let musicLoopDuration: TimeInterval = Double(musicFrameCount) / musicFrameRate

    @State private var idleFrames: [NSImage] = []
    @State private var musicFrames: [NSImage] = []

    var body: some View {
        Group {
            if !isStatic, state == .music, !musicFrames.isEmpty {
                MascotSpriteLayerView(
                    frames: musicFrames,
                    poseInterval: 1.0 / Self.musicFrameRate,
                    // 跳跃和横移已经画进位图，不再叠一层更快的 CA 位移。
                    bounceAmplitude: 0,
                    bounceDuration: 0,
                    driftAmplitude: 0,
                    driftDuration: 0
                )
            } else if !isStatic, state == .idle, !idleFrames.isEmpty {
                MascotSpriteLayerView(
                    frames: idleFrames,
                    poseInterval: 1.2,
                    bounceAmplitude: max(idleAmplitude, 1.6),
                    bounceDuration: 1.65,
                    driftAmplitude: 0,
                    driftDuration: 0
                )
            } else if !isStatic, state == .music {
                TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { timeline in
                    poseCanvas(date: timeline.date)
                }
            } else {
                poseCanvas(date: Self.frozenDate)
            }
        }
        .frame(width: size, height: size)
        .onAppear(perform: captureFramesIfNeeded)
        .onChange(of: size) { _, _ in
            idleFrames = []
            musicFrames = []
            captureFramesIfNeeded()
        }
        .onChange(of: state) { _, _ in
            captureFramesIfNeeded()
        }
        .onChange(of: isStatic) { _, _ in
            captureFramesIfNeeded()
        }
    }

    private func poseCanvas(date: Date) -> some View {
        Canvas { context, canvasSize in
            draw(&context, canvasSize, date)
        }
    }

    private func captureFramesIfNeeded() {
        guard !isStatic else { return }
        if state == .idle {
            captureIdleFramesIfNeeded()
        } else if state == .music {
            captureMusicFramesIfNeeded()
        }
    }

    private func captureIdleFramesIfNeeded() {
        guard idleFrames.isEmpty else { return }
        DispatchQueue.main.async {
            guard !isStatic, state == .idle, idleFrames.isEmpty else { return }
            let frames = [0.0, 1.2, 2.4].compactMap { timestamp in
                snapshotPose(date: Date(timeIntervalSinceReferenceDate: timestamp))
            }
            if !frames.isEmpty {
                idleFrames = frames
            }
        }
    }

    private func captureMusicFramesIfNeeded() {
        guard musicFrames.isEmpty else { return }
        Task { @MainActor in
            guard !isStatic, state == .music, musicFrames.isEmpty else { return }
            var frames: [NSImage] = []
            frames.reserveCapacity(Self.musicFrameCount)
            for index in 0..<Self.musicFrameCount {
                let timestamp = Self.musicLoopDuration * Double(index) / Double(Self.musicFrameCount)
                if let image = snapshotPose(date: Date(timeIntervalSinceReferenceDate: timestamp)) {
                    frames.append(image)
                }
                await Task.yield()
            }
            if !frames.isEmpty {
                musicFrames = frames
            }
        }
    }

    private func snapshotPose(date: Date) -> NSImage? {
        let content = poseCanvas(date: date)
            .frame(width: size, height: size)
            .colorScheme(.dark)

        let renderer = ImageRenderer(content: content)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        renderer.proposedSize = ProposedViewSize(width: size, height: size)
        if let image = renderer.nsImage, image.size.width > 1, image.size.height > 1 {
            return image
        }

        let host = NSHostingView(rootView: content)
        host.appearance = NSAppearance(named: .darkAqua)
        host.frame = NSRect(x: 0, y: 0, width: size, height: size)
        host.layoutSubtreeIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            return nil
        }
        host.cacheDisplay(in: host.bounds, to: rep)
        let image = NSImage(size: NSSize(width: size, height: size))
        image.addRepresentation(rep)
        return image.size.width > 1 ? image : nil
    }
}

private struct MascotSpriteLayerView: NSViewRepresentable {
    let frames: [NSImage]
    let poseInterval: TimeInterval
    let bounceAmplitude: CGFloat
    let bounceDuration: TimeInterval
    let driftAmplitude: CGFloat
    let driftDuration: TimeInterval

    func makeNSView(context: Context) -> MascotSpriteNSView {
        let view = MascotSpriteNSView()
        view.configure(
            frames: frames,
            poseInterval: poseInterval,
            bounceAmplitude: bounceAmplitude,
            bounceDuration: bounceDuration,
            driftAmplitude: driftAmplitude,
            driftDuration: driftDuration
        )
        return view
    }

    func updateNSView(_ nsView: MascotSpriteNSView, context: Context) {
        nsView.configure(
            frames: frames,
            poseInterval: poseInterval,
            bounceAmplitude: bounceAmplitude,
            bounceDuration: bounceDuration,
            driftAmplitude: driftAmplitude,
            driftDuration: driftDuration
        )
    }
}

/// 位图序列 + CA 位移。切帧只换 layer.contents，跳跃/横移由合成器 60fps 插值。
private final class MascotSpriteNSView: NSView {
    private let imageLayer = CALayer()
    private var frames: [NSImage] = []
    private var poseInterval: TimeInterval = 1.2
    private var bounceAmplitude: CGFloat = 0
    private var bounceDuration: TimeInterval = 0
    private var driftAmplitude: CGFloat = 0
    private var driftDuration: TimeInterval = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = false
        layer?.backgroundColor = NSColor.clear.cgColor
        imageLayer.contentsGravity = .resize
        imageLayer.magnificationFilter = .linear
        imageLayer.minificationFilter = .linear
        layer?.addSublayer(imageLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        imageLayer.frame = bounds
        CATransaction.commit()
        updateContentsScale()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            startAnimationsIfNeeded()
        } else {
            stopAnimations()
        }
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateContentsScale()
    }

    func configure(
        frames: [NSImage],
        poseInterval: TimeInterval,
        bounceAmplitude: CGFloat,
        bounceDuration: TimeInterval,
        driftAmplitude: CGFloat,
        driftDuration: TimeInterval
    ) {
        let framesChanged = frames.count != self.frames.count
            || zip(frames, self.frames).contains(where: { $0.0 !== $0.1 })
        if framesChanged {
            self.frames = frames
            imageLayer.contents = frames.first
            updateContentsScale()
        }

        let motionChanged = self.poseInterval != poseInterval
            || abs(self.bounceAmplitude - bounceAmplitude) > 0.01
            || abs(self.bounceDuration - bounceDuration) > 0.01
            || abs(self.driftAmplitude - driftAmplitude) > 0.01
            || abs(self.driftDuration - driftDuration) > 0.01

        self.poseInterval = poseInterval
        self.bounceAmplitude = bounceAmplitude
        self.bounceDuration = bounceDuration
        self.driftAmplitude = driftAmplitude
        self.driftDuration = driftDuration

        if window != nil, framesChanged || motionChanged {
            stopAnimations()
            startAnimationsIfNeeded()
        }
    }

    private func startAnimationsIfNeeded() {
        guard window != nil else { return }
        startBounceIfNeeded()
        startDriftIfNeeded()
        startPoseKeyframe()
    }

    private func startBounceIfNeeded() {
        guard bounceAmplitude > 0, bounceDuration > 0 else { return }
        guard imageLayer.animation(forKey: "spriteBounce") == nil else { return }
        let animation = CABasicAnimation(keyPath: "transform.translation.y")
        animation.fromValue = bounceAmplitude
        animation.toValue = -bounceAmplitude * 0.15
        animation.duration = bounceDuration
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.isRemovedOnCompletion = false
        animation.fillMode = .forwards
        imageLayer.add(animation, forKey: "spriteBounce")
    }

    private func startDriftIfNeeded() {
        guard driftAmplitude > 0, driftDuration > 0 else { return }
        guard imageLayer.animation(forKey: "spriteDrift") == nil else { return }
        let animation = CABasicAnimation(keyPath: "transform.translation.x")
        animation.fromValue = -driftAmplitude
        animation.toValue = driftAmplitude
        animation.duration = driftDuration
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        animation.isRemovedOnCompletion = false
        animation.fillMode = .forwards
        imageLayer.add(animation, forKey: "spriteDrift")
    }

    private func startPoseKeyframe() {
        guard window != nil, frames.count > 1 else { return }
        guard imageLayer.animation(forKey: "spritePose") == nil else { return }
        let images = frames.compactMap { image -> CGImage? in
            var rect = CGRect(origin: .zero, size: image.size)
            return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        }
        guard images.count > 1 else { return }
        let animation = CAKeyframeAnimation(keyPath: "contents")
        animation.values = images
        animation.duration = poseInterval * Double(images.count)
        animation.repeatCount = .infinity
        animation.calculationMode = .discrete
        animation.isRemovedOnCompletion = false
        imageLayer.add(animation, forKey: "spritePose")
    }

    private func stopAnimations() {
        imageLayer.removeAnimation(forKey: "spriteBounce")
        imageLayer.removeAnimation(forKey: "spriteDrift")
        imageLayer.removeAnimation(forKey: "spritePose")
    }

    private func updateContentsScale() {
        imageLayer.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
    }

}
