import AppKit
import SwiftUI

/// 将 SwiftUI 投放热区转换为 AppKit 拖放协调器使用的内容坐标，避免无标题栏面板下命中偏移。
struct DropFrameReporter: NSViewRepresentable {
    let onFrameChange: (CGRect) -> Void

    func makeNSView(context: Context) -> ReportingView {
        let view = ReportingView()
        view.onFrameChange = onFrameChange

        // 允许并引导 NSView 自动扩展以填充 SwiftUI 父级容器空间，防止其坍塌为 .zero 尺寸导致上报 bounds 始终为空。
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        return view
    }

    func updateNSView(_ nsView: ReportingView, context: Context) {
        nsView.onFrameChange = onFrameChange
        nsView.reportFrame()
    }

    final class ReportingView: NSView {
        var onFrameChange: ((CGRect) -> Void)?
        private var lastReportedFrame: CGRect = .null

        override var isFlipped: Bool {
            true
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            reportFrame()
        }

        override func setFrameSize(_ newSize: NSSize) {
            super.setFrameSize(newSize)
            reportFrame()
        }

        override func setFrameOrigin(_ newOrigin: NSPoint) {
            super.setFrameOrigin(newOrigin)
            reportFrame()
        }

        override func layout() {
            super.layout()
            reportFrame()
        }

        func reportFrame() {
            guard window?.contentView != nil else { return }
            let frameInWindow = convert(bounds, to: nil)
            guard frameInWindow != lastReportedFrame else { return }
            lastReportedFrame = frameInWindow
            DispatchQueue.main.async { [weak self] in
                self?.onFrameChange?(frameInWindow)
            }
        }
    }
}
