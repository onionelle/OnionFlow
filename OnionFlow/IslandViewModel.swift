import Combine
import Foundation
import SwiftUI

@MainActor
final class IslandViewModel: ObservableObject {
    @Published private(set) var isExpanded = false {
        didSet {
            onIsExpandedChange?(isExpanded)
        }
    }
    // AppKit 窗口尺寸和 SwiftUI 壳体尺寸分开管理：展开前先保留大窗口，收起动画结束后再缩回。
    @Published private(set) var reservesExpandedWindow = false {
        didSet {
            onLayoutChange?()
        }
    }
    @Published private(set) var isSettingsPresented = false
    @Published private(set) var isPlaylistEnabled = UserDefaults.standard.object(forKey: "playlistEnabled") as? Bool ?? true
    @Published private(set) var isQuickLaunchEnabled = UserDefaults.standard.object(forKey: "quickLaunchEnabled") as? Bool ?? true
    @Published private(set) var isTemporaryTrayEnabled = UserDefaults.standard.object(forKey: "temporaryTrayEnabled") as? Bool ?? true
    private var collapseReservationTask: Task<Void, Never>?
    var onLayoutChange: (() -> Void)?
    var onIsExpandedChange: ((Bool) -> Void)?
    var onOpenSettings: (() -> Void)?
    var onRequestQuit: (() -> Void)?
    #if arch(x86_64)
    let collapsedWidth: CGFloat = 187
    #else
    let collapsedWidth: CGFloat = 280
    #endif
    let expandedWidth: CGFloat = 525
    #if arch(x86_64)
    let collapsedHeight: CGFloat = 24
    #else
    let collapsedHeight: CGFloat = 32
    #endif
    private let fullExpandedHeight: CGFloat = 627
    private let quickLaunchDisabledHeightReduction: CGFloat = 95.6
    private let temporaryTrayDisabledHeightReduction: CGFloat = 156.6

    var expandedHeight: CGFloat {
        if isPlaylistEnabled {
            if isTemporaryTrayEnabled {
                // 临时暂存开启：高度调整为 585 / 538，配合 12pt 底部留白，使虚线框底边与底沿保持与只开启暂存时完全一致的底留白
                return isQuickLaunchEnabled ? 585 : 538
            } else {
                // 临时暂存关闭：
                // 如果快捷启动开启，配合与仅开快捷启动一致的 26pt 留白，高度调整为 459pt，维持极佳视觉平衡
                // 如果快捷启动关闭，即仅播放列表开启：配合 26pt 留白，高度收敛为 418pt
                return isQuickLaunchEnabled ? 459 : 418
            }
        } else {
            // 播放列表关闭：
            if isTemporaryTrayEnabled {
                // 临时暂存开启：配合 12pt 底部留白，高度调整为 365 / 296，使虚线框底边与底沿保持 4pt 精致边距
                return isQuickLaunchEnabled ? 365 : 296
            } else {
                // 临时暂存关闭：均无须对齐，保留原 26pt 留白
                return isQuickLaunchEnabled ? 238 : 190
            }
        }
    }

    // SwiftUI 外投影需要 AppKit 透明窗口预留空间，否则底部和左右阴影会被裁掉。
    let horizontalShadowMargin: CGFloat = 8
    let bottomShadowMargin: CGFloat = 15

    var bottomCornerRadius: CGFloat {
        guard isExpanded else { return 15 }
        return 40
    }
    var shoulderRadius: CGFloat {
        isExpanded ? 10 : 5
    }
    var islandWidth: CGFloat {
        isExpanded ? expandedWidth : collapsedWidth
    }
    var islandHeight: CGFloat {
        isExpanded ? expandedHeight : collapsedHeight
    }
    var panelWidth: CGFloat {
        // 展开态增加左右投影边距；收起态不保留这段透明区域。
        reservesExpandedWindow ? (expandedWidth + horizontalShadowMargin * 2) : collapsedWidth
    }
    var panelHeight: CGFloat {
        // 展开期间固定保留最大窗口高度，避免功能开关造成 AppKit frame 跟随 SwiftUI 高度动画抖动。
        // 多余透明区域的鼠标穿透由 `IslandHostingView.hitTest(_:)` 按当前 notch 外轮廓处理。
        reservesExpandedWindow ? (fullExpandedHeight + bottomShadowMargin) : collapsedHeight
    }

    func reserveWindowForExpansion() {
        collapseReservationTask?.cancel()
        reservesExpandedWindow = true
    }
    func openSettings() {
        onOpenSettings?()
    }
    func setSettingsPresented(_ isPresented: Bool) {
        isSettingsPresented = isPresented
    }
    func setPlaylistEnabled(_ isEnabled: Bool) {
        guard isPlaylistEnabled != isEnabled else { return }
        isPlaylistEnabled = isEnabled
        UserDefaults.standard.set(isEnabled, forKey: "playlistEnabled")
        if reservesExpandedWindow {
            onLayoutChange?()
        }
    }
    func setQuickLaunchEnabled(_ isEnabled: Bool) {
        guard isQuickLaunchEnabled != isEnabled else { return }
        isQuickLaunchEnabled = isEnabled
        UserDefaults.standard.set(isEnabled, forKey: "quickLaunchEnabled")
        if reservesExpandedWindow {
            onLayoutChange?()
        }
    }
    func setTemporaryTrayEnabled(_ isEnabled: Bool) {
        guard isTemporaryTrayEnabled != isEnabled else { return }
        isTemporaryTrayEnabled = isEnabled
        UserDefaults.standard.set(isEnabled, forKey: "temporaryTrayEnabled")
        if reservesExpandedWindow {
            onLayoutChange?()
        }
    }
    func requestQuit() {
        onRequestQuit?()
    }
    func expandIsland() {
        isExpanded = true
    }
    func collapseIsland() {
        guard isExpanded else { return }
        collapseReservationTask?.cancel()
        isExpanded = false
        reservesExpandedWindow = true
        // 延迟释放 expanded 窗口空间，避免 SwiftUI 收起动画被 AppKit 窗口提前裁掉。
        collapseReservationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 360_000_000)
            guard !Task.isCancelled else { return }
            if self?.isExpanded == false {
                self?.reservesExpandedWindow = false
            }
        }
    }

    func toggleExpanded() {
        if isExpanded {
            collapseIsland()
        } else {
            reserveWindowForExpansion()
            Task { @MainActor [weak self] in
                await Task.yield()
                self?.expandIsland()
            }
        }
    }
}
