import AppKit
import SwiftUI

/// 原生文件拖出桥接负责构造真实 `fileURL` 拖拽项和批量拖动反馈。
struct TemporaryTrayDragSource: NSViewRepresentable {
    let item: TemporaryTrayItem
    let viewModel: TemporaryTrayViewModel
    let previewImage: NSImage

    func makeNSView(context: Context) -> TemporaryTrayDragSourceView {
        TemporaryTrayDragSourceView(item: item, viewModel: viewModel, previewImage: previewImage)
    }

    func updateNSView(_ nsView: TemporaryTrayDragSourceView, context: Context) {
        nsView.configure(item: item, viewModel: viewModel, previewImage: previewImage)
    }
}

final class TemporaryTrayDragSourceView: NSView, NSDraggingSource {
    private var item: TemporaryTrayItem
    private weak var viewModel: TemporaryTrayViewModel?
    private var previewImage: NSImage
    private var draggedItemIDs: [String] = []
    private var mouseDownPoint: NSPoint?
    private var startedDragging = false
    private var collapsesSelectionOnClick = false
    private var dragOperation: NSDragOperation = []

    init(item: TemporaryTrayItem, viewModel: TemporaryTrayViewModel, previewImage: NSImage) {
        self.item = item
        self.viewModel = viewModel
        self.previewImage = previewImage
        super.init(frame: .zero)
        toolTip = "\(item.displayName)\n\(item.url.path)"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(item: TemporaryTrayItem, viewModel: TemporaryTrayViewModel, previewImage: NSImage) {
        self.item = item
        self.viewModel = viewModel
        self.previewImage = previewImage
        toolTip = "\(item.displayName)\n\(item.url.path)"
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let usesCommand = modifiers.contains(.command)
        let usesShift = modifiers.contains(.shift)
        collapsesSelectionOnClick = !usesCommand && !usesShift && (viewModel?.isSelected(item.id) == true)
        if !collapsesSelectionOnClick {
            viewModel?.selectItem(id: item.id, command: usesCommand, shift: usesShift)
        }
        mouseDownPoint = convert(event.locationInWindow, from: nil)
        startedDragging = false
    }

    override func mouseUp(with event: NSEvent) {
        if !startedDragging, collapsesSelectionOnClick {
            viewModel?.selectOnlyItem(id: item.id)
        }
        mouseDownPoint = nil
        startedDragging = false
        collapsesSelectionOnClick = false
        dragOperation = []
    }

    override func mouseDragged(with event: NSEvent) {
        guard !startedDragging, item.isAvailable, let mouseDownPoint else { return }
        let point = convert(event.locationInWindow, from: nil)
        guard hypot(point.x - mouseDownPoint.x, point.y - mouseDownPoint.y) > 4 else { return }
        guard let dragItems = viewModel?.dragItems(startingAt: item.id), !dragItems.isEmpty else { return }

        startedDragging = true
        draggedItemIDs = dragItems.map(\.id)
        guard let operation = viewModel?.dragOperation(for: dragItems) else {
            startedDragging = false
            draggedItemIDs = []
            return
        }
        dragOperation = operation
        viewModel?.beginDragging(itemIDs: draggedItemIDs)

        let draggingItems = dragItems.enumerated().map { index, draggedItem in
            let draggingItem = NSDraggingItem(pasteboardWriter: draggedItem.url as NSURL)
            let offset = CGFloat(min(index, 4)) * 2
            let frame = NSRect(x: (bounds.width - 34) / 2 + offset, y: bounds.height - 35 - offset, width: 34, height: 34)
            let image = draggedItem.id == item.id ? previewImage : (viewModel?.image(for: draggedItem) ?? previewImage)
            draggingItem.setDraggingFrame(
                frame,
                contents: draggingImage(for: image, count: index == 0 ? dragItems.count : nil)
            )
            return draggingItem
        }
        let session = beginDraggingSession(with: draggingItems, event: event, source: self)
        session.draggingFormation = .stack
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        dragOperation
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        // 只有目标实际接收后才移除引用；取消拖拽或投回临时暂存自身必须保留原选择。
        viewModel?.finishDragging(itemIDs: draggedItemIDs, succeeded: operation != [])
        draggedItemIDs = []
        mouseDownPoint = nil
        startedDragging = false
        collapsesSelectionOnClick = false
        dragOperation = []
    }

    private func draggingImage(for previewImage: NSImage, count: Int?) -> NSImage {
        let image = NSImage(size: NSSize(width: 34, height: 34))
        image.lockFocus()
        previewImage.draw(in: NSRect(x: 2, y: 2, width: 28, height: 28))
        if let count, count > 1 {
            let badgeRect = NSRect(x: 20, y: 20, width: 14, height: 14)
            NSColor.white.withAlphaComponent(0.82).setFill()
            NSBezierPath(ovalIn: badgeRect).fill()
            let countText = String(count) as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 8, weight: .regular),
                .foregroundColor: NSColor.black
            ]
            let textSize = countText.size(withAttributes: attributes)
            countText.draw(
                at: NSPoint(x: badgeRect.midX - textSize.width / 2, y: badgeRect.midY - textSize.height / 2),
                withAttributes: attributes
            )
        }
        image.unlockFocus()
        return image
    }
}
