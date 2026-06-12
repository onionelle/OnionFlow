import AppKit

/// 协调 expanded 内三个投放区域的 AppKit 拖放分发，避免窗口控制器承担功能路由。
@MainActor
final class IslandDropCoordinator {
    private enum TargetZone {
        case playlist
        case launcher
        case tray
        case none
    }

    private let viewModel: IslandViewModel
    private let musicViewModel: MusicPlayerViewModel
    private let quickLaunchViewModel: QuickLaunchViewModel
    private let temporaryTrayViewModel: TemporaryTrayViewModel

    let registeredPasteboardTypes: [NSPasteboard.PasteboardType] = [
        .fileURL,
        NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType"),
        .quickLaunchInternalSlot
    ]

    init(
        viewModel: IslandViewModel,
        musicViewModel: MusicPlayerViewModel,
        quickLaunchViewModel: QuickLaunchViewModel,
        temporaryTrayViewModel: TemporaryTrayViewModel
    ) {
        self.viewModel = viewModel
        self.musicViewModel = musicViewModel
        self.quickLaunchViewModel = quickLaunchViewModel
        self.temporaryTrayViewModel = temporaryTrayViewModel
    }

    func operation(
        for sender: NSDraggingInfo,
        at location: NSPoint,
        in bounds: NSRect,
        islandHitPath: NSBezierPath
    ) -> NSDragOperation {
        let zone = targetZone(at: location, in: bounds, islandHitPath: islandHitPath)
        let urls = fileURLs(from: sender.draggingPasteboard)

        if internalLauncherSourceSlot(from: sender.draggingPasteboard) != nil {
            guard case .launcher = zone else {
                clearDropTargets()
                return []
            }
            musicViewModel.setDropTargeted(false)
            temporaryTrayViewModel.setDropTargeted(false)
            quickLaunchViewModel.setDropTargeted(true)
            quickLaunchViewModel.setDropInsertionIndex(launcherTargetSlot(for: location, in: bounds))
            return .move
        }

        guard !urls.isEmpty else {
            clearDropTargets()
            return []
        }
        if temporaryTrayViewModel.isDraggingItems {
            clearDropTargets()
            return []
        }

        switch zone {
        case .tray:
            musicViewModel.setDropTargeted(false)
            quickLaunchViewModel.setDropTargeted(false)
            quickLaunchViewModel.setDropInsertionIndex(nil)
            temporaryTrayViewModel.setDropTargeted(true)
            return trayTransferMode(from: sender).dragOperation
        case .launcher:
            guard urls.count == 1,
                  let appURL = urls.first,
                  isAppBundle(url: appURL) else {
                clearDropTargets()
                return []
            }
            musicViewModel.setDropTargeted(false)
            temporaryTrayViewModel.setDropTargeted(false)
            quickLaunchViewModel.setDropTargeted(true)
            quickLaunchViewModel.setDropInsertionIndex(launcherTargetSlot(for: location, in: bounds))
            return .copy
        case .playlist:
            let candidateURLs = urls.filter { !isAppBundle(url: $0) }
            let acceptsDrop = musicViewModel.canAcceptPlaylistDrop(from: candidateURLs)
            guard acceptsDrop else {
                clearDropTargets()
                return []
            }
            quickLaunchViewModel.setDropTargeted(false)
            quickLaunchViewModel.setDropInsertionIndex(nil)
            temporaryTrayViewModel.setDropTargeted(false)
            musicViewModel.setDropTargeted(true)
            return .copy
        case .none:
            clearDropTargets()
            return []
        }
    }

    func performDrop(
        from sender: NSDraggingInfo,
        at location: NSPoint,
        in bounds: NSRect,
        islandHitPath: NSBezierPath
    ) -> Bool {
        let zone = targetZone(at: location, in: bounds, islandHitPath: islandHitPath)
        clearDropTargets()

        if let sourceSlot = internalLauncherSourceSlot(from: sender.draggingPasteboard) {
            guard case .launcher = zone else { return false }
            quickLaunchViewModel.moveApp(from: sourceSlot, to: launcherTargetSlot(for: location, in: bounds))
            return true
        }

        let urls = fileURLs(from: sender.draggingPasteboard)
        guard !urls.isEmpty else { return false }
        if temporaryTrayViewModel.isDraggingItems {
            return false
        }

        switch zone {
        case .tray:
            temporaryTrayViewModel.addItems(from: urls, transferMode: trayTransferMode(from: sender))
            return true
        case .launcher:
            guard urls.count == 1,
                  let appURL = urls.first,
                  isAppBundle(url: appURL) else {
                return false
            }
            quickLaunchViewModel.placeApp(from: appURL, at: launcherTargetSlot(for: location, in: bounds))
            return true
        case .playlist:
            let musicURLs = urls.filter { !isAppBundle(url: $0) }
            guard !musicURLs.isEmpty else { return false }
            return musicViewModel.addFilesOrDirectoriesToPlaylist(from: musicURLs)
        case .none:
            return false
        }
    }

    func clearDropTargets() {
        musicViewModel.setDropTargeted(false)
        quickLaunchViewModel.setDropTargeted(false)
        quickLaunchViewModel.setDropInsertionIndex(nil)
        temporaryTrayViewModel.setDropTargeted(false)
    }

    private func targetZone(at location: NSPoint, in bounds: NSRect, islandHitPath: NSBezierPath) -> TargetZone {
        // location and islandHitPath are already in bottom-left coordinates (Y=0 at bottom).
        guard viewModel.isExpanded, islandHitPath.contains(location) else { return .none }

        let trayRect = temporaryTrayViewModel.dropFrame
        let launcherRect = quickLaunchViewModel.dropFrame
        let playlistRect = musicViewModel.dropFrame

        let islandRect = NSRect(
            x: bounds.midX - viewModel.islandWidth / 2,
            y: bounds.height - viewModel.islandHeight, // 在 bottom-left 坐标系下，贴顶灵动岛的 Y 原点为 bounds.height - islandHeight
            width: viewModel.islandWidth,
            height: viewModel.islandHeight
        )

        // 暂存区投放热区向下扩充贴近底部壳体内边，在 bottom-left 坐标系下，从 trayRect.maxY (暂存区顶部) 向下延伸至整个灵动岛底边 islandRect.minY
        let trayHitRect: NSRect
        if !trayRect.isEmpty {
            trayHitRect = NSRect(
                x: islandRect.minX,
                y: islandRect.minY,
                width: islandRect.width,
                height: max(trayRect.maxY - islandRect.minY, trayRect.height)
            )
        } else {
            trayHitRect = .zero
        }

        if temporaryTrayEnabled, !trayHitRect.isEmpty && trayHitRect.contains(location) {
            return .tray
        }
        if quickLaunchEnabled, !launcherRect.isEmpty && launcherRect.contains(location) {
            return .launcher
        }
        if playlistEnabled, !playlistRect.isEmpty && playlistRect.contains(location) {
            return .playlist
        }
        return .none
    }

    private var playlistEnabled: Bool {
        viewModel.isPlaylistEnabled
    }

    private var quickLaunchEnabled: Bool {
        viewModel.isQuickLaunchEnabled
    }

    private var temporaryTrayEnabled: Bool {
        viewModel.isTemporaryTrayEnabled
    }

    private func trayTransferMode(from sender: NSDraggingInfo) -> TemporaryTrayTransferMode {
        let modifiers = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers.contains(.option) || !sender.draggingSourceOperationMask.contains(.move) {
            return .copy
        }
        return .move
    }

    private func isAppBundle(url: URL) -> Bool {
        var path = url.standardizedFileURL.path.lowercased()
        if path.hasSuffix("/") {
            path = String(path.dropLast())
        }
        return path.hasSuffix(".app")
    }

    private func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [NSURL], !urls.isEmpty {
            return urls.map { $0 as URL }
        }
        let filenamesType = NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")
        if let filenames = pasteboard.propertyList(forType: filenamesType) as? [String] {
            return filenames.map { URL(fileURLWithPath: $0) }
        }
        return []
    }

    private func internalLauncherSourceSlot(from pasteboard: NSPasteboard) -> Int? {
        guard let value = pasteboard.string(forType: .quickLaunchInternalSlot),
              let index = Int(value),
              (0..<quickLaunchViewModel.slotCount).contains(index) else {
            return nil
        }
        return index
    }

    private func launcherTargetSlot(for location: NSPoint, in bounds: NSRect) -> Int {
        let frame = quickLaunchViewModel.dropFrame
        let launcherRect = frame
        guard !launcherRect.isEmpty else { return 0 }

        let itemWidth: CGFloat = 32
        let itemCount = CGFloat(quickLaunchViewModel.slotCount)
        let availableSpacing = launcherRect.width - itemWidth * itemCount
        let itemSpacing = max(6, availableSpacing / (itemCount - 1))
        let localX = location.x - launcherRect.minX

        return (0..<quickLaunchViewModel.slotCount).min { first, second in
            let firstCenter = itemWidth / 2 + CGFloat(first) * (itemWidth + itemSpacing)
            let secondCenter = itemWidth / 2 + CGFloat(second) * (itemWidth + itemSpacing)
            return abs(localX - firstCenter) < abs(localX - secondCenter)
        } ?? 0
    }
}

private extension TemporaryTrayTransferMode {
    var dragOperation: NSDragOperation {
        switch self {
        case .move:
            return .move
        case .copy:
            return .copy
        }
    }
}
