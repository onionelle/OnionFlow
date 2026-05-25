import AppKit
import SwiftUI

// 支持通过背景空白/非交互区域进行原生鼠标拖动窗口的 HostingView 子类
private final class DraggableHostingView<Content: View>: NSHostingView<Content> {
    override var mouseDownCanMoveWindow: Bool {
        true
    }
}

// 独立设置面板，层级高于顶部 island，并在失去焦点后自动关闭。
@MainActor
final class SettingsWindowController: NSObject {
    private var panel: NSPanel?
    private var resignObserver: NSObjectProtocol?
    
    func show() {
        if let panel {
            showPanel(panel)
            return
        }
        
        // 创建 Mascot 设置视图，并注入关闭回调以支持自绘界面的关闭按钮
        let pickerView = MascotPickerView { [weak self] in
            self?.close()
        }
        
        let hostingView = DraggableHostingView(rootView: pickerView)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.setFrameSize(NSSize(width: 420, height: 330))
        
        // 使用 borderless 无边框面板，尺寸为 420×330
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 330),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        // 关键设置：允许通过窗口背景鼠标点击拖拽移动窗口
        panel.isMovableByWindowBackground = true
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.center()
        panel.becomesKeyOnlyIfNeeded = false
        panel.isReleasedWhenClosed = false
        panel.contentView = hostingView
        
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.close()
            }
        }

        self.panel = panel
        showPanel(panel)
    }

    private func showPanel(_ panel: NSPanel) {
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    private func close() {
        if let resignObserver {
            NotificationCenter.default.removeObserver(resignObserver)
            self.resignObserver = nil
        }
        panel?.close()
        panel = nil
    }
}
