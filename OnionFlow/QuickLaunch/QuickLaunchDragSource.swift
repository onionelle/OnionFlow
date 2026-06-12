import AppKit
import SwiftUI

extension NSPasteboard.PasteboardType {
    static let quickLaunchInternalSlot = NSPasteboard.PasteboardType("com.onionflow.quick-launch-slot")
}

/// 快捷启动内部重排使用 AppKit 原生 dragging session，使拖动图像稳定跟随指针。
struct QuickLaunchDragSource: NSViewRepresentable {
    let path: String
    let slotIndex: Int
    let icon: NSImage
    let viewModel: QuickLaunchViewModel

    func makeNSView(context: Context) -> QuickLaunchDragSourceView {
        QuickLaunchDragSourceView(path: path, slotIndex: slotIndex, icon: icon, viewModel: viewModel)
    }

    func updateNSView(_ nsView: QuickLaunchDragSourceView, context: Context) {
        nsView.configure(path: path, slotIndex: slotIndex, icon: icon, viewModel: viewModel)
    }
}

final class QuickLaunchDragSourceView: NSView, NSDraggingSource {
    private var path: String
    private var slotIndex: Int
    private var icon: NSImage
    private weak var viewModel: QuickLaunchViewModel?
    private var mouseDownPoint: NSPoint?
    private var startedDragging = false

    init(path: String, slotIndex: Int, icon: NSImage, viewModel: QuickLaunchViewModel) {
        self.path = path
        self.slotIndex = slotIndex
        self.icon = icon
        self.viewModel = viewModel
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(path: String, slotIndex: Int, icon: NSImage, viewModel: QuickLaunchViewModel) {
        self.path = path
        self.slotIndex = slotIndex
        self.icon = icon
        self.viewModel = viewModel
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownPoint = convert(event.locationInWindow, from: nil)
        startedDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !startedDragging, let mouseDownPoint else { return }
        let point = convert(event.locationInWindow, from: nil)
        guard hypot(point.x - mouseDownPoint.x, point.y - mouseDownPoint.y) > 4 else { return }

        startedDragging = true
        viewModel?.setDraggedSourceSlot(slotIndex)

        let item = NSPasteboardItem()
        item.setString(String(slotIndex), forType: .quickLaunchInternalSlot)
        let draggingItem = NSDraggingItem(pasteboardWriter: item)
        draggingItem.setDraggingFrame(bounds, contents: draggingImage())
        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            mouseDownPoint = nil
            startedDragging = false
        }
        guard !startedDragging else { return }
        viewModel?.launchApp(path: path)
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        .move
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        mouseDownPoint = nil
        viewModel?.setDraggedSourceSlot(nil)
        viewModel?.setDropTargeted(false)
        viewModel?.setDropInsertionIndex(nil)
    }

    private func draggingImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 32, height: 32))
        image.lockFocus()
        let clipPath = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: 32, height: 32), xRadius: 7, yRadius: 7)
        clipPath.addClip()
        NSColor.white.withAlphaComponent(0.10).setFill()
        clipPath.fill()
        icon.draw(in: NSRect(x: -3, y: -3, width: 38, height: 38))
        image.unlockFocus()
        return image
    }
}
