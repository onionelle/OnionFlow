import AppKit
import SwiftUI

// 顶部 island 不应成为 key/main window；键盘焦点仍留给用户当前应用。
private final class IslandPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }
    override var canBecomeMain: Bool {
        false
    }
}

// 非激活 panel 的第一次鼠标点击默认可能只用于激活窗口；这里让第一次点击直接交给 SwiftUI。
// expanded 期间 AppKit 窗口会暂时大过可见 island，透明区域必须放行给桌面/其它 App。
private final class IslandHostingView: NSHostingView<ContentView> {
    private let viewModel: IslandViewModel
    private let dropCoordinator: IslandDropCoordinator

    init(rootView: ContentView, viewModel: IslandViewModel, musicViewModel: MusicPlayerViewModel, quickLaunchViewModel: QuickLaunchViewModel, temporaryTrayViewModel: TemporaryTrayViewModel) {
        self.viewModel = viewModel
        self.dropCoordinator = IslandDropCoordinator(
            viewModel: viewModel,
            musicViewModel: musicViewModel,
            quickLaunchViewModel: quickLaunchViewModel,
            temporaryTrayViewModel: temporaryTrayViewModel
        )
        super.init(rootView: rootView)
        registerForDraggedTypes(dropCoordinator.registeredPasteboardTypes)
    }

    @available(*, unavailable)
    @MainActor dynamic required init(rootView: ContentView) {
        fatalError("Use init(rootView:viewModel:musicViewModel:quickLaunchViewModel:temporaryTrayViewModel:) instead")
    }

    @available(*, unavailable)
    @MainActor dynamic required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard islandHitPath.contains(point) else { return nil }
        return super.hitTest(point)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(visibleIslandRectInWindow, cursor: .arrow)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        dropCoordinator.operation(for: sender, at: sender.draggingLocation, in: bounds, islandHitPath: islandHitPath)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        dropCoordinator.operation(for: sender, at: sender.draggingLocation, in: bounds, islandHitPath: islandHitPath)
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        dropCoordinator.clearDropTargets()
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        dropCoordinator.performDrop(
            from: sender,
            at: sender.draggingLocation,
            in: bounds,
            islandHitPath: islandHitPath
        )
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        dropCoordinator.clearDropTargets()
    }

    private var visibleIslandRectInWindow: NSRect {
        let width = viewModel.islandWidth
        let height = viewModel.islandHeight
        let originX = bounds.midX - (width / 2)
        // Window coordinates are non-flipped (Y-up), so the top of the window is at bounds.height.
        // The bottom of the island is at bounds.height - height.
        let originY = bounds.height - height
        return NSRect(x: originX, y: originY, width: width, height: height)
    }

    private var islandHitPath: NSBezierPath {
        notchIslandHitPath(in: visibleIslandRectInWindow)
    }

    func containsVisibleIslandPointInScreen(_ screenPoint: NSPoint, panelFrame: NSRect) -> Bool {
        let pointInWindow = NSPoint(
            x: screenPoint.x - panelFrame.minX,
            y: screenPoint.y - panelFrame.minY
        )
        return islandHitPath.contains(pointInWindow)
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
    private let temporaryTrayViewModel: TemporaryTrayViewModel
    private var panel: NSPanel?
    private var screenObserver: NSObjectProtocol?
    private var localMouseMonitor: Any?
    private var globalMouseMonitor: Any?
    private var isSystemModalActive = false

    var currentSettingsAnchorFrame: NSRect? {
        guard let panel else { return nil }
        let width = viewModel.islandWidth
        let height = viewModel.islandHeight
        // 设置页沿用展开态既定的视觉贴合位置，右侧补偿与投影预留保持一致。
        let settingsTrailingInset = viewModel.isExpanded ? viewModel.horizontalShadowMargin : 0
        return NSRect(
            x: panel.frame.midX - (width / 2),
            y: panel.frame.maxY - height,
            width: width - settingsTrailingInset,
            height: height
        )
    }

    init(viewModel: IslandViewModel, musicViewModel: MusicPlayerViewModel, quickLaunchViewModel: QuickLaunchViewModel, temporaryTrayViewModel: TemporaryTrayViewModel) {
        self.viewModel = viewModel
        self.musicViewModel = musicViewModel
        self.quickLaunchViewModel = quickLaunchViewModel
        self.temporaryTrayViewModel = temporaryTrayViewModel
        self.viewModel.onLayoutChange = { [weak self] in
            // AppKit frame 不做动画，顶部固定感交给 SwiftUI 内部壳体动画实现。
            self?.updatePanelLayout()
            self?.updateMousePassthrough()
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
        installMousePassthroughMonitorsIfNeeded()
        updateMousePassthrough()
        panel?.orderFrontRegardless()
    }

    func lowerPanelForSystemModal() {
        isSystemModalActive = true
    }

    func restorePanelAfterSystemModal() {
        isSystemModalActive = false
        panel?.level = .statusBar
        updateMousePassthrough()
        panel?.orderFrontRegardless()
    }

    private func createPanel() {
        let contentView = ContentView(
            viewModel: viewModel,
            musicViewModel: musicViewModel,
            quickLaunchViewModel: quickLaunchViewModel,
            temporaryTrayViewModel: temporaryTrayViewModel
        )
        let hostingView = IslandHostingView(
            rootView: contentView,
            viewModel: viewModel,
            musicViewModel: musicViewModel,
            quickLaunchViewModel: quickLaunchViewModel,
            temporaryTrayViewModel: temporaryTrayViewModel
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
        panel.acceptsMouseMovedEvents = true
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

    private func installMousePassthroughMonitorsIfNeeded() {
        guard localMouseMonitor == nil, globalMouseMonitor == nil else { return }
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDown, .rightMouseDown, .otherMouseDown, .leftMouseDragged, .rightMouseDragged]
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.updateMousePassthrough()
            return event
        }
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateMousePassthrough()
            }
        }
    }

    private func updateMousePassthrough() {
        guard let panel else { return }
        guard !isSystemModalActive else {
            panel.ignoresMouseEvents = false
            return
        }
        let mouseLocation = NSEvent.mouseLocation
        // NSPanel 是矩形窗口；当 SwiftUI 壳体收缩后，剩余透明区域必须在窗口级别穿透。
        // contentView 的 hitTest 只能影响窗口内部路由，窗口级穿透也要使用同一份 notch 路径。
        if let hostingView = panel.contentView as? IslandHostingView {
            panel.ignoresMouseEvents = !hostingView.containsVisibleIslandPointInScreen(mouseLocation, panelFrame: panel.frame)
        } else {
            panel.ignoresMouseEvents = false
        }
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
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
        }
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
        }
    }
}
