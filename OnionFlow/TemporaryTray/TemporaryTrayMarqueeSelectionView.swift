import AppKit
import SwiftUI

/// 临时暂存空白区域框选覆盖层；只在非 item 命中位置启动，避免抢走文件拖出事件。
struct TemporaryTrayMarqueeSelectionView: NSViewRepresentable {
    let viewModel: TemporaryTrayViewModel

    func makeNSView(context: Context) -> MarqueeSelectionNSView {
        MarqueeSelectionNSView(viewModel: viewModel)
    }

    func updateNSView(_ nsView: MarqueeSelectionNSView, context: Context) {
        nsView.viewModel = viewModel
    }
}

final class MarqueeSelectionNSView: NSView {
    weak var viewModel: TemporaryTrayViewModel?
    private var isSelecting = false
    private var commandMode = false
    private var optionMode = false

    init(viewModel: TemporaryTrayViewModel) {
        self.viewModel = viewModel
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool {
        true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard viewModel?.itemFrameContains(point) == false else { return nil }
        return super.hitTest(point)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let viewModel else { return }
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        commandMode = modifiers.contains(.command)
        optionMode = modifiers.contains(.option)
        isSelecting = true
        viewModel.beginMarqueeSelection(at: point, command: commandMode, option: optionMode)
    }

    override func mouseDragged(with event: NSEvent) {
        guard isSelecting else { return }
        let point = convert(event.locationInWindow, from: nil)
        viewModel?.updateMarqueeSelection(to: point, command: commandMode, option: optionMode)
    }

    override func mouseUp(with event: NSEvent) {
        guard isSelecting else { return }
        isSelecting = false
        viewModel?.endMarqueeSelection()
    }
}
