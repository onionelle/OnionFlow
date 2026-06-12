import AppKit

/// 封装快捷启动依赖的系统 App 能力，避免 View 和 ViewModel 直接调用 `NSWorkspace`。
@MainActor
final class QuickLaunchAppController {
    func openApp(at path: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    func icon(for path: String) -> NSImage {
        NSWorkspace.shared.icon(forFile: path)
    }
}
