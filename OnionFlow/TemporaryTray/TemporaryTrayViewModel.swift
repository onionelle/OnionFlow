import AppKit
import Combine
import CoreGraphics
import Foundation

/// 临时暂存只保存当前会话中的文件引用，不移动、复制或持久化用户文件。
@MainActor
final class TemporaryTrayViewModel: ObservableObject {
    @Published private(set) var items: [TemporaryTrayItem] = []
    @Published private(set) var isDropTargeted = false
    @Published private(set) var selectedItemIDs: Set<String> = []
    @Published private(set) var draggedItemIDs: Set<String> = []
    @Published private(set) var statusText: String?
    @Published private(set) var previewImages: [String: NSImage] = [:]
    @Published private(set) var selectionRect: CGRect?
    @Published var dropFrame: CGRect = .zero

    let capacity = 20
    private let fileService: TemporaryTrayFileService
    private var selectionAnchorID: String?
    private var statusTask: Task<Void, Never>?
    @Published var statusIsSelectionWarning = false
    private var itemFrames: [String: CGRect] = [:]
    private var baseSelectionIDs: Set<String> = []
    private var marqueeStartPoint: CGPoint?

    init(fileService: TemporaryTrayFileService? = nil) {
        self.fileService = fileService ?? TemporaryTrayFileService()
    }

    func addItems(from urls: [URL], transferMode: TemporaryTrayTransferMode) {
        let existingPaths = Set(items.map(\.id))
        var insertedPaths = existingPaths
        var nextItems = items
        var insertedCount = 0
        var exceededCapacity = false

        for url in urls {
            let item = fileService.makeItem(from: url, transferMode: transferMode)
            let path = item.id
            guard !insertedPaths.contains(path) else { continue }
            guard nextItems.count < capacity else {
                exceededCapacity = true
                continue
            }
            insertedPaths.insert(path)
            nextItems.append(item)
            insertedCount += 1
        }

        items = nextItems
        pruneItemFrames()

        if exceededCapacity, insertedCount > 0 {
            showStatus("已加入 \(insertedCount) 个，临时暂存已满")
        } else if exceededCapacity {
            showStatus("临时暂存最多保留 \(capacity) 个项目")
        } else if insertedCount > 0 {
            let modeText = transferMode == .copy ? "复制" : "移动"
            showStatus(insertedCount == 1 ? "已加入 1 个项目 · \(modeText)" : "已加入 \(insertedCount) 个项目 · \(modeText)")
        } else {
            showStatus("项目已在临时暂存中")
        }
    }

    func removeItem(id: String) {
        items.removeAll { $0.id == id }
        itemFrames.removeValue(forKey: id)
        previewImages.removeValue(forKey: id)
        selectedItemIDs.remove(id)
        draggedItemIDs.remove(id)
        if selectionAnchorID == id {
            selectionAnchorID = nil
        }
    }

    func clearItems() {
        items.removeAll()
        itemFrames.removeAll()
        previewImages.removeAll()
        clearSelection()
        draggedItemIDs.removeAll()
        showStatus("临时暂存已清空")
    }

    func setDropTargeted(_ targeted: Bool) {
        isDropTargeted = targeted
    }

    func isSelected(_ id: String) -> Bool {
        selectedItemIDs.contains(id)
    }

    func selectItem(id: String, command: Bool, shift: Bool) {
        guard items.contains(where: { $0.id == id }) else { return }

        if shift, let anchorID = selectionAnchorID,
           let anchorIndex = items.firstIndex(where: { $0.id == anchorID }),
           let itemIndex = items.firstIndex(where: { $0.id == id }) {
            let range = min(anchorIndex, itemIndex)...max(anchorIndex, itemIndex)
            let rangedIDs = Set(range.map { items[$0].id })
            selectedItemIDs = command ? selectedItemIDs.union(rangedIDs) : rangedIDs
            updateMixedSelectionFeedback()
            return
        }

        if command {
            if selectedItemIDs.contains(id) {
                selectedItemIDs.remove(id)
            } else {
                selectedItemIDs.insert(id)
                selectionAnchorID = id
            }
            updateMixedSelectionFeedback()
            return
        }

        selectOnlyItem(id: id)
    }

    func selectOnlyItem(id: String) {
        selectedItemIDs = [id]
        selectionAnchorID = id
        updateMixedSelectionFeedback()
    }

    func clearSelection() {
        selectedItemIDs.removeAll()
        selectionAnchorID = nil
        statusTask?.cancel()
        statusText = nil
    }

    func setItemFrame(id: String, frame: CGRect) {
        guard items.contains(where: { $0.id == id }) else { return }
        itemFrames[id] = frame
    }

    func itemFrameContains(_ point: CGPoint) -> Bool {
        let currentIDs = Set(items.map(\.id))
        return itemFrames.contains { id, frame in
            currentIDs.contains(id) && frame.contains(point)
        }
    }

    func beginMarqueeSelection(at point: CGPoint, command: Bool, option: Bool) {
        baseSelectionIDs = (command || option) ? selectedItemIDs : []
        marqueeStartPoint = point
        selectionRect = CGRect(origin: point, size: .zero)
        updateMarqueeSelection(to: point, command: command, option: option)
    }

    func updateMarqueeSelection(to point: CGPoint, command: Bool, option: Bool) {
        guard let start = marqueeStartPoint else { return }
        let rect = CGRect(
            x: min(start.x, point.x),
            y: min(start.y, point.y),
            width: abs(point.x - start.x),
            height: abs(point.y - start.y)
        )
        selectionRect = rect
        let currentIDs = Set(items.map(\.id))
        let hitIDs = Set(itemFrames.compactMap { id, frame in
            currentIDs.contains(id) && frame.intersects(rect) ? id : nil
        })
        if option {
            selectedItemIDs = baseSelectionIDs.subtracting(hitIDs)
        } else if command {
            selectedItemIDs = baseSelectionIDs.union(hitIDs)
        } else {
            selectedItemIDs = hitIDs
        }
        updateMixedSelectionFeedback()
    }

    func endMarqueeSelection() {
        selectionRect = nil
        marqueeStartPoint = nil
        baseSelectionIDs.removeAll()
        selectionAnchorID = selectedItemIDs.compactMap { id in
            items.contains(where: { $0.id == id }) ? id : nil
        }.first
        updateMixedSelectionFeedback()
    }

    func dragItems(startingAt id: String) -> [TemporaryTrayItem] {
        refreshAvailability()
        if !selectedItemIDs.contains(id) {
            selectOnlyItem(id: id)
        }
        return items.filter { selectedItemIDs.contains($0.id) && $0.isAvailable }
    }

    func beginDragging(itemIDs: [String]) {
        draggedItemIDs = Set(itemIDs)
    }

    func dragOperation(for dragItems: [TemporaryTrayItem]) -> NSDragOperation? {
        let modes = Set(dragItems.map(\.transferMode))
        guard modes.count <= 1, let mode = modes.first else {
            showStatus("移 / 拷暂不支持混合，请分开拖出")
            return nil
        }
        return mode == .move ? .move : .copy
    }

    func finishDragging(itemIDs: [String], succeeded: Bool) {
        if succeeded {
            let ids = Set(itemIDs)
            items.removeAll { ids.contains($0.id) }
            selectedItemIDs.subtract(ids)
            if let selectionAnchorID, ids.contains(selectionAnchorID) {
                self.selectionAnchorID = nil
            }
        }
        draggedItemIDs.removeAll()
    }

    var isDraggingItems: Bool {
        !draggedItemIDs.isEmpty
    }

    func refreshAvailability() {
        items = items.map(fileService.refreshedItem)
        pruneItemFrames()
    }

    func image(for item: TemporaryTrayItem) -> NSImage {
        previewImages[item.id] ?? fileService.icon(for: item)
    }

    func loadPreview(for item: TemporaryTrayItem) {
        fileService.loadPreview(for: item) { [weak self] image in
            self?.previewImages[item.id] = image
        }
    }

    private func showStatus(_ text: String) {
        statusTask?.cancel()
        statusIsSelectionWarning = false
        statusText = text
        statusTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            guard !Task.isCancelled else { return }
            self?.statusText = nil
        }
    }

    private func updateMixedSelectionFeedback() {
        if hasMixedSelectedTransferModes {
            statusTask?.cancel()
            statusIsSelectionWarning = true
            statusText = "移 / 拷暂不支持混合，请分开拖出"
        } else if statusIsSelectionWarning {
            statusIsSelectionWarning = false
            statusText = nil
        }
    }

    private var hasMixedSelectedTransferModes: Bool {
        let selectedModes = Set(items.compactMap { item in
            selectedItemIDs.contains(item.id) ? item.transferMode : nil
        })
        return selectedModes.count > 1
    }


    private func pruneItemFrames() {
        let currentIDs = Set(items.map(\.id))
        itemFrames = itemFrames.filter { currentIDs.contains($0.key) }
        selectedItemIDs = selectedItemIDs.intersection(currentIDs)
    }
}
