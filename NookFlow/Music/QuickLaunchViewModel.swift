import SwiftUI
import AppKit
import Combine

/// 快捷启动器业务控制层。
/// 支持以 JSON 字符串形式持久化持久存储本地应用程序路径到 AppStorage，
/// 提供 App 添加、移除、极速一键启动，以及系统高分辨率图标的提取。
@MainActor
final class QuickLaunchViewModel: ObservableObject {
    /// 持久化底层存储 (JSON 字符串形式)
    @AppStorage("quickLaunchAppsJson") private var appsJson: String = "[]"
    
    /// 当前快捷启动器中的 App 路径列表 (最多支持 9 个，以充分利用 expanded 横向空间)
    @Published var apps: [String] = []
    
    /// AppKit 层是否捕获拖拽悬浮状态，用于实时高亮天空蓝虚线边框
    @Published var isDropTargeted: Bool = false
    @Published var dropInsertionIndex: Int?
    
    @Published var dropFrame: CGRect = .zero
    
    init() {
        loadApps()
    }
    
    /// 从持久化存储读取
    func loadApps() {
        guard let data = appsJson.data(using: .utf8) else { return }
        if let decoded = try? JSONDecoder().decode([String].self, from: data) {
            self.apps = decoded
        }
    }
    
    /// 同步持久化写入
    private func saveApps() {
        if let data = try? JSONEncoder().encode(apps),
           let json = String(data: data, encoding: .utf8) {
            appsJson = json
        }
    }
    
    /// 添加 App 快捷方式
    func addApp(from url: URL, at preferredIndex: Int? = nil) {
        var path = url.path
        // 关键修复：Finder 拖拽目录型包体时，URL 路径末尾往往带有 "/" 斜杠，需要进行规整化剥离
        if path.hasSuffix("/") {
            path = String(path.dropLast())
        }
        
        // 只允许添加以 .app 结尾的应用程序路径
        guard path.lowercased().hasSuffix(".app") else { return }
        if let existingIndex = apps.firstIndex(of: path) {
            apps.remove(at: existingIndex)
        }
        
        let insertionIndex = min(max(preferredIndex ?? 0, 0), apps.count)
        apps.insert(path, at: insertionIndex)
        
        // 限制最多 9 个 App；满位时优先保留用户本次拖放指定的位置。
        if apps.count > 9 {
            if insertionIndex >= 9 {
                apps.removeFirst()
            } else {
                apps.removeLast()
            }
        }
        saveApps()
    }
    
    /// 移除 App 快捷方式
    func removeApp(path: String) {
        if let idx = apps.firstIndex(of: path) {
            apps.remove(at: idx)
            saveApps()
        }
    }
    
    func moveApp(path: String, to preferredIndex: Int) {
        guard let currentIndex = apps.firstIndex(of: path) else { return }
        
        apps.remove(at: currentIndex)
        let adjustedIndex = currentIndex < preferredIndex ? preferredIndex - 1 : preferredIndex
        let insertionIndex = min(max(adjustedIndex, 0), apps.count)
        apps.insert(path, at: insertionIndex)
        saveApps()
    }
    
    /// 一键启动 App
    func launchApp(path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.open(url)
    }
    
    /// 获取精美剔除后缀的 App 显示名称
    func displayName(for path: String) -> String {
        let url = URL(fileURLWithPath: path)
        return url.deletingPathExtension().lastPathComponent
    }
    
    /// 设置拖拽悬浮高亮状态
    func setDropTargeted(_ targeted: Bool) {
        self.isDropTargeted = targeted
        if !targeted {
            dropInsertionIndex = nil
        }
    }
    
    func setDropInsertionIndex(_ index: Int?) {
        dropInsertionIndex = index
    }
}
