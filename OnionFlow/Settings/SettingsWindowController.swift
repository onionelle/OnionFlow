import AppKit
import SwiftUI

private final class InteractiveSettingsPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// 非泛型类继承 NSHostingView<AnyView> 以避开 macOS 15.0 部署目标下的编译器 Optimizer Crash Bug
private final class SettingsHostingView: NSHostingView<AnyView> {
    @MainActor required dynamic init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    @MainActor required init(rootView: AnyView) {
        super.init(rootView: rootView)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        super.hitTest(point) ?? self
    }
}

// 独立设置面板，层级高于顶部 island，并在失去焦点后自动关闭。
@MainActor
final class SettingsWindowController: NSObject {
    private var panel: NSPanel?
    private var resignObserver: NSObjectProtocol?
    var onVisibilityChange: ((Bool) -> Void)?
    private var suppressImmediateReopen = false
    private let panelWidth: CGFloat = 440
    private let minimumPanelHeight: CGFloat = 320
    private let islandSpacing: CGFloat = 1
    private let topSpacing: CGFloat = 3

    func toggle(alignedTo islandFrame: NSRect?) {
        if suppressImmediateReopen {
            suppressImmediateReopen = false
            return
        }
        if panel != nil {
            close()
        } else {
            show(alignedTo: islandFrame)
        }
    }

    func show(alignedTo islandFrame: NSRect?) {
        if let panel {
            position(panel, alignedTo: islandFrame)
            showPanel(panel)
            return
        }

        // 创建 Mascot 设置视图，并注入关闭回调以支持自绘界面的关闭按钮
        let pickerView = MascotPickerView(
            onClose: { [weak self] in
                self?.close()
            },
            onHeightChange: { [weak self] height in
                Task { @MainActor [weak self] in
                    self?.resizePanel(toContentHeight: height)
                }
            }
        )

        let hostingView = SettingsHostingView(rootView: AnyView(pickerView))
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        let initialSize = NSSize(width: panelWidth, height: sanitizedPanelHeight(hostingView.fittingSize.height))
        hostingView.setFrameSize(initialSize)

        // 设置页需要完整接收鼠标并可拖动，不使用会保持底层交互语义的 nonactivating panel。
        let panel = InteractiveSettingsPanel(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        // 原生阴影在面板覆盖顶部 island 时会显著增加合成开销。
        panel.hasShadow = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true
        panel.isMovable = true
        panel.isMovableByWindowBackground = false
        panel.isReleasedWhenClosed = false
        panel.isRestorable = false
        panel.contentView = hostingView

        // 延迟注册失去焦点的关闭事件，避免第一次由于 SwiftUI 渲染耗时导致焦点跳跃而瞬间触发“闪退”（弹窗秒关）的 Bug
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self, weak panel] in
            guard let self = self, let panel = panel else { return }
            self.resignObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification,
                object: panel,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.close(suppressingImmediateReopen: true)
                }
            }
        }

        self.panel = panel
        position(panel, alignedTo: islandFrame)
        showPanel(panel)
        onVisibilityChange?(true)
    }

    /// island 的投影余量变化时，保持已打开的设置窗口继续贴合当前可见壳体。
    func realignIfVisible(to islandFrame: NSRect?) {
        guard let panel else { return }
        position(panel, alignedTo: islandFrame)
    }

    private func position(_ panel: NSPanel, alignedTo islandFrame: NSRect?) {
        guard let islandFrame else {
            panel.center()
            return
        }
        let origin = NSPoint(
            x: islandFrame.maxX + islandSpacing,
            y: islandFrame.maxY - topSpacing - panel.frame.height
        )
        panel.setFrameOrigin(origin)
    }

    private func resizePanel(toContentHeight contentHeight: CGFloat) {
        guard let panel else { return }
        let targetHeight = sanitizedPanelHeight(contentHeight)
        guard abs(panel.frame.height - targetHeight) > 0.5 else { return }

        let oldFrame = panel.frame
        let resizedFrame = NSRect(
            x: oldFrame.minX,
            y: oldFrame.maxY - targetHeight,
            width: panelWidth,
            height: targetHeight
        )
        panel.setFrame(resizedFrame, display: true)
        panel.contentView?.setFrameSize(resizedFrame.size)
    }

    private func sanitizedPanelHeight(_ height: CGFloat) -> CGFloat {
        max(minimumPanelHeight, ceil(height))
    }

    private func showPanel(_ panel: NSPanel) {
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    func close(suppressingImmediateReopen: Bool = false) {
        guard panel != nil else { return }
        suppressImmediateReopen = suppressingImmediateReopen
        if suppressingImmediateReopen {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.suppressImmediateReopen = false
            }
        }
        if let resignObserver {
            NotificationCenter.default.removeObserver(resignObserver)
            self.resignObserver = nil
        }
        panel?.close()
        panel = nil
        onVisibilityChange?(false)
    }
}
