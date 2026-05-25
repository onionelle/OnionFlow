import AppKit
import SwiftUI

// 顶部 island 不应成为 key/main window；键盘焦点仍留给用户当前应用。
private final class IslandPanel: NSPanel {
    override var canBecomeKey: Bool {
        false
    }
    override var canBecomeMain: Bool {
        false
    }
}

// 非激活 panel 的第一次鼠标点击默认可能只用于激活窗口；这里让第一次点击直接交给 SwiftUI。
// expanded 期间 AppKit 窗口会暂时大过可见 island，透明区域必须放行给桌面/其它 App。
private final class IslandHostingView: NSHostingView<ContentView> {
    private let viewModel: IslandViewModel
    private let musicViewModel: MusicPlayerViewModel
    private let quickLaunchViewModel: QuickLaunchViewModel

    init(rootView: ContentView, viewModel: IslandViewModel, musicViewModel: MusicPlayerViewModel, quickLaunchViewModel: QuickLaunchViewModel) {
        self.viewModel = viewModel
        self.musicViewModel = musicViewModel
        self.quickLaunchViewModel = quickLaunchViewModel
        super.init(rootView: rootView)
        
        // 注册双重拖拽类型，使用原始字符串以规整兼容 legacy 的 NSFilenamesPboardType
        let filenamesType = NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")
        registerForDraggedTypes([.fileURL, filenamesType])
    }

    @available(*, unavailable)
    @MainActor dynamic required init(rootView: ContentView) {
        fatalError("Use init(rootView:viewModel:musicViewModel:quickLaunchViewModel:) instead")
    }

    @available(*, unavailable)
    @MainActor dynamic required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let isInside = containsVisibleIsland(at: point)
        guard isInside else { return nil }
        return super.hitTest(point)
    }

    func containsVisibleIsland(at point: NSPoint) -> Bool {
        islandHitPath.contains(point)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(visibleIslandRect, cursor: .arrow)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        dragOperation(for: sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        dragOperation(for: sender)
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        clearDropTargets()
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let location = convert(sender.draggingLocation, from: nil)
        let zone = targetZone(for: location)
        clearDropTargets()
        
        let urls = fileURLs(from: sender.draggingPasteboard)
        guard !urls.isEmpty else { return false }
        
        switch zone {
        case .launcher:
            // 应用程序路由至快捷启动栏
            let appUrls = urls.filter { isAppBundle(url: $0) }
            guard !appUrls.isEmpty else { return false }
            let insertionIndex = launcherInsertionIndex(for: location)
            for (offset, appUrl) in appUrls.enumerated() {
                quickLaunchViewModel.addApp(from: appUrl, at: insertionIndex + offset)
            }
            return true
        case .playlist:
            // 非应用程序（音频文件/文件夹）路由至音乐播放列表
            let musicUrls = urls.filter { !isAppBundle(url: $0) }
            guard !musicUrls.isEmpty else { return false }
            musicViewModel.addFilesOrDirectoriesToPlaylist(from: musicUrls)
            return true
        case .none:
            return false
        }
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        clearDropTargets()
    }

    // 独立拖拽靶区定义
    private enum DragTargetZone {
        case playlist
        case launcher
        case none
    }

    // 判断拖拽的文件是否为 .app 应用程序包（智能剔除 Finder 自动追加的末尾 "/" 斜杠）
    private func isAppBundle(url: URL) -> Bool {
        var path = url.path
        if path.hasSuffix("/") {
            path = String(path.dropLast())
        }
        return path.lowercased().hasSuffix(".app")
    }

    // 精确判定鼠标拖拽落入的物理区域（播放列表 or 快捷启动栏）。
    // SwiftUI 中的 .global 坐标空间是 top-left based，而 NSHostingView 默认是 bottom-left based (isFlipped = false)。
    // 这里将 SwiftUI 的 top-left 坐标转换为 NSHostingView 的 bottom-left 坐标进行匹配。
    private func targetZone(for location: NSPoint) -> DragTargetZone {
        let launcherFrame = quickLaunchViewModel.dropFrame
        let playlistFrame = musicViewModel.dropFrame
        
        func toLocal(_ globalFrame: CGRect) -> NSRect {
            let localY = bounds.height - globalFrame.maxY
            return NSRect(x: globalFrame.minX, y: localY, width: globalFrame.width, height: globalFrame.height)
        }
        
        let launcherRect = toLocal(launcherFrame)
        let playlistRect = toLocal(playlistFrame)
        
        guard viewModel.isExpanded, islandHitPath.contains(location) else {
            return .none
        }
        
        if !launcherRect.isEmpty && launcherRect.contains(location) {
            return .launcher
        } else if !playlistRect.isEmpty && playlistRect.contains(location) {
            return .playlist
        } else {
            return .none
        }
    }

    private func dragOperation(for sender: NSDraggingInfo) -> NSDragOperation {
        let location = convert(sender.draggingLocation, from: nil)
        let zone = targetZone(for: location)
        
        let urls = fileURLs(from: sender.draggingPasteboard)
        guard !urls.isEmpty else {
            clearDropTargets()
            return []
        }
        
        switch zone {
        case .launcher:
            // 启动器靶区：仅高亮启动器框，只接收应用程序 (.app)
            let hasApp = urls.contains { isAppBundle(url: $0) }
            if hasApp {
                musicViewModel.setDropTargeted(false)
                quickLaunchViewModel.setDropTargeted(true)
                quickLaunchViewModel.setDropInsertionIndex(launcherInsertionIndex(for: location))
                return .copy
            }
        case .playlist:
            // 音乐播放列表靶区：仅高亮播放列表框，只接收非应用程序（音频）
            let hasMusic = urls.contains { !isAppBundle(url: $0) }
            if hasMusic {
                quickLaunchViewModel.setDropTargeted(false)
                quickLaunchViewModel.setDropInsertionIndex(nil)
                musicViewModel.setDropTargeted(true)
                return .copy
            }
        case .none:
            break
        }
        
        clearDropTargets()
        return []
    }

    private func clearDropTargets() {
        musicViewModel.setDropTargeted(false)
        quickLaunchViewModel.setDropTargeted(false)
        quickLaunchViewModel.setDropInsertionIndex(nil)
    }

    private func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
        // 优先从 filenames 属性列表读取，以兼容本地拖动 .app 目录包（如 Finder 拖拽）
        let filenamesType = NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")
        if let filenames = pasteboard.propertyList(forType: filenamesType) as? [String] {
            return filenames.map { URL(fileURLWithPath: $0) }
        }
        
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [NSURL]
        return urls?.map { $0 as URL } ?? []
    }

    // 快速启动栏按 9 个停放位计算固定间距；AppKit 拖拽层必须按同一布局换算插入顺序。
    private func launcherInsertionIndex(for location: NSPoint) -> Int {
        let launcherFrame = quickLaunchViewModel.dropFrame
        let launcherRect = NSRect(
            x: launcherFrame.minX,
            y: bounds.height - launcherFrame.maxY,
            width: launcherFrame.width,
            height: launcherFrame.height
        )
        guard !launcherRect.isEmpty else { return 0 }
        
        let itemWidth: CGFloat = 38
        let itemCount = quickLaunchViewModel.apps.count
        let maxItemCount: CGFloat = 9
        let availableSpacing = launcherRect.width - itemWidth * maxItemCount
        let itemSpacing = max(6, availableSpacing / (maxItemCount + 1))
        let itemStep = itemWidth + itemSpacing
        let localX = location.x - launcherRect.minX
        
        for index in 0..<itemCount {
            let itemCenterX = itemSpacing + (itemWidth / 2) + CGFloat(index) * itemStep
            if localX < itemCenterX {
                return index
            }
        }
        
        return itemCount
    }

    private var visibleIslandRect: NSRect {
        let width = viewModel.islandWidth
        let height = viewModel.islandHeight
        let originX = bounds.midX - (width / 2)
        // 由于 isFlipped = false，可见岛屿贴顶，底边 Y 坐标从 bounds.height - height 开始，向上延伸至 bounds.height
        let originY = bounds.height - height
        return NSRect(x: originX, y: originY, width: width, height: height)
    }

    private var islandHitPath: NSBezierPath {
        notchIslandHitPath(in: visibleIslandRect)
    }

    // AppKit 层必须复刻 SwiftUI 的 notch 外轮廓做命中测试；否则透明阴影和肩部空白会挡住桌面鼠标事件。
    private func notchIslandHitPath(in rect: NSRect) -> NSBezierPath {
        let shoulderRadius = min(max(3, viewModel.shoulderRadius), rect.width * 0.16)
        let bottomRadius = min(max(10, viewModel.bottomCornerRadius), rect.height / 2)
        let shoulderDepth = min(max(shoulderRadius * 0.84, 5), rect.height - bottomRadius - 6)
        let curveTightness: CGFloat = 0.82

        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.minX, y: rect.maxY))
        path.line(to: NSPoint(x: rect.maxX, y: rect.maxY))
        path.curve(
            to: NSPoint(x: rect.maxX - shoulderRadius, y: rect.maxY - shoulderDepth),
            controlPoint1: NSPoint(x: rect.maxX - shoulderRadius * 0.82, y: rect.maxY),
            controlPoint2: NSPoint(x: rect.maxX - shoulderRadius, y: rect.maxY - shoulderDepth * curveTightness)
        )
        path.line(to: NSPoint(x: rect.maxX - shoulderRadius, y: rect.minY + bottomRadius))
        path.curve(
            to: NSPoint(x: rect.maxX - shoulderRadius - bottomRadius, y: rect.minY),
            controlPoint1: NSPoint(x: rect.maxX - shoulderRadius, y: rect.minY + bottomRadius * (1 - curveTightness)),
            controlPoint2: NSPoint(x: rect.maxX - shoulderRadius - bottomRadius * (1 - curveTightness), y: rect.minY)
        )
        path.line(to: NSPoint(x: rect.minX + shoulderRadius + bottomRadius, y: rect.minY))
        path.curve(
            to: NSPoint(x: rect.minX + shoulderRadius, y: rect.minY + bottomRadius),
            controlPoint1: NSPoint(x: rect.minX + shoulderRadius + bottomRadius * (1 - curveTightness), y: rect.minY),
            controlPoint2: NSPoint(x: rect.minX + shoulderRadius, y: rect.minY + bottomRadius * (1 - curveTightness))
        )
        path.line(to: NSPoint(x: rect.minX + shoulderRadius, y: rect.maxY - shoulderDepth))
        path.curve(
            to: NSPoint(x: rect.minX, y: rect.maxY),
            controlPoint1: NSPoint(x: rect.minX + shoulderRadius, y: rect.maxY - shoulderDepth * curveTightness),
            controlPoint2: NSPoint(x: rect.minX + shoulderRadius * 0.82, y: rect.maxY)
        )
        path.close()
        return path
    }

}

@MainActor
final class FloatingPanelController {
    private let viewModel: IslandViewModel
    private let musicViewModel: MusicPlayerViewModel
    private let quickLaunchViewModel: QuickLaunchViewModel
    private var panel: NSPanel?
    private var screenObserver: NSObjectProtocol?
    private var isSystemModalActive = false

    init(viewModel: IslandViewModel, musicViewModel: MusicPlayerViewModel, quickLaunchViewModel: QuickLaunchViewModel) {
        self.viewModel = viewModel
        self.musicViewModel = musicViewModel
        self.quickLaunchViewModel = quickLaunchViewModel
        self.viewModel.onLayoutChange = { [weak self] in
            // AppKit frame 不做动画，顶部固定感交给 SwiftUI 内部壳体动画实现。
            self?.updatePanelLayout()
        }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updatePanelLayout()
            }
        }
    }

    func show() {
        if panel == nil {
            createPanel()
        }
        updatePanelLayout()
        panel?.orderFrontRegardless()
    }

    func lowerPanelForSystemModal() {
        isSystemModalActive = true
    }

    func restorePanelAfterSystemModal() {
        isSystemModalActive = false
        panel?.level = .statusBar
        panel?.orderFrontRegardless()
    }

    private func createPanel() {
        let contentView = ContentView(
            viewModel: viewModel,
            musicViewModel: musicViewModel,
            quickLaunchViewModel: quickLaunchViewModel
        )
        let hostingView = IslandHostingView(
            rootView: contentView,
            viewModel: viewModel,
            musicViewModel: musicViewModel,
            quickLaunchViewModel: quickLaunchViewModel
        )
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        let panel = IslandPanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: viewModel.panelWidth,
                height: viewModel.panelHeight
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        // 允许 island 出现在所有桌面和全屏空间；它是状态面板，不跟随普通窗口生命周期。
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.contentView = hostingView
        self.panel = panel
    }

    private func updatePanelLayout() {
        guard let panel else { return }
        guard let screen = chosenScreen() else { return }
        let frame = panelFrame(for: screen)
        panel.setFrame(frame, display: true)
        // 自定义 notch 外投影由 SwiftUI 绘制；原生矩形阴影会破坏贴顶形态。
        panel.hasShadow = false
    }

    private func panelFrame(for screen: NSScreen) -> NSRect {
        let width = viewModel.panelWidth
        let height = viewModel.panelHeight
        let originX = screen.frame.midX - (width / 2)
        // 贴顶定位使用完整 screen.frame，不用 visibleFrame，避免被菜单栏安全区再次下推。
        let originY = screen.frame.maxY - height
        return NSRect(x: originX, y: originY, width: width, height: height)
    }

    private func chosenScreen() -> NSScreen? {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return NSScreen.main }
        let mouseLocation = NSEvent.mouseLocation
        // 多屏环境优先跟随鼠标所在屏幕，减少 island 出现在错误显示器上的概率。
        if let hoveredScreen = screens.first(where: { $0.frame.contains(mouseLocation) }) {
            return hoveredScreen
        }
        return NSScreen.main ?? screens.first
    }

    deinit {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }
}
