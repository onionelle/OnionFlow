import AppKit
import Combine
import Foundation

/// 快捷启动状态层只编排槽位变化与投放反馈；持久化及系统打开能力由独立依赖提供。
@MainActor
final class QuickLaunchViewModel: ObservableObject {
    private let store: QuickLaunchStore
    private let appController: QuickLaunchAppController

    @Published private(set) var slots: [String?] = Array(repeating: nil, count: 10)
    @Published var isDropTargeted: Bool = false
    @Published var dropInsertionIndex: Int?
    @Published private(set) var draggedSourceSlot: Int?
    @Published var dropFrame: CGRect = .zero

    let slotCount = 10

    var isEmpty: Bool {
        slots.allSatisfy { $0 == nil }
    }

    init(
        store: QuickLaunchStore? = nil,
        appController: QuickLaunchAppController? = nil
    ) {
        self.store = store ?? QuickLaunchStore()
        self.appController = appController ?? QuickLaunchAppController()
        loadApps()
    }

    func loadApps() {
        guard let storedSlots = store.loadSlots() else { return }
        slots = normalizedSlots(from: storedSlots)
    }

    private func saveApps() {
        store.saveSlots(slots)
    }

    private func normalizedSlots(from storedSlots: [String?]) -> [String?] {
        let retainedSlots = Array(storedSlots.prefix(slotCount))
        return retainedSlots + Array(repeating: nil, count: max(0, slotCount - retainedSlots.count))
    }

    /// 将外部拖入的 App 放入目标槽位：落在已有图标上时替换，落在空槽位时新增。
    func placeApp(from url: URL, at targetSlot: Int) {
        var path = url.standardizedFileURL.path
        // Finder 可能为目录型 `.app` 包追加末尾斜杠，规整后才能稳定判定和去重。
        if path.hasSuffix("/") {
            path = String(path.dropLast())
        }

        guard path.lowercased().hasSuffix(".app") else { return }
        let placementIndex = min(max(targetSlot, 0), slotCount - 1)
        if let existingIndex = slots.firstIndex(where: { $0 == path }) {
            slots[existingIndex] = nil
        }
        slots[placementIndex] = path
        saveApps()
    }

    func removeApp(path: String) {
        if let idx = slots.firstIndex(where: { $0 == path }) {
            slots[idx] = nil
            saveApps()
        }
    }

    func moveApp(from sourceSlot: Int, to targetSlot: Int) {
        let currentIndex = min(max(sourceSlot, 0), slotCount - 1)
        guard let movingPath = slots[currentIndex] else { return }
        let placementIndex = min(max(targetSlot, 0), slotCount - 1)
        guard currentIndex != placementIndex else { return }

        let replacedPath = slots[placementIndex]
        slots[placementIndex] = movingPath
        slots[currentIndex] = replacedPath
        saveApps()
    }

    func launchApp(path: String) {
        appController.openApp(at: path)
    }

    func icon(for path: String) -> NSImage {
        appController.icon(for: path)
    }

    func displayName(for path: String) -> String {
        let url = URL(fileURLWithPath: path)
        return url.deletingPathExtension().lastPathComponent
    }

    func setDropTargeted(_ targeted: Bool) {
        self.isDropTargeted = targeted
        if !targeted {
            dropInsertionIndex = nil
        }
    }

    func setDropInsertionIndex(_ index: Int?) {
        dropInsertionIndex = index
    }

    func setDraggedSourceSlot(_ index: Int?) {
        draggedSourceSlot = index
    }
}
