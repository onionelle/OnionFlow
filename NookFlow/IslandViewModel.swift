import Combine
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
    private var collapseReservationTask: Task<Void, Never>?
    var onLayoutChange: (() -> Void)?
    var onIsExpandedChange: ((Bool) -> Void)?
    var onOpenSettings: (() -> Void)?
    var onRequestQuit: (() -> Void)?
    let collapsedWidth: CGFloat = 280
    let expandedWidth: CGFloat = 525
    let collapsedHeight: CGFloat = 32
    let expandedHeight: CGFloat = 580
    // 阴影的外延边距；底部比左右多留一点，避免 expanded 下沿投影被窗口裁出硬边。
    let horizontalShadowMargin: CGFloat = 8
    let bottomShadowMargin: CGFloat = 15

    var bottomCornerRadius: CGFloat {
        isExpanded ? 40 : 15
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
        // 展开时增加左右两侧的阴影边距，收起时保持紧凑尺寸
        reservesExpandedWindow ? (expandedWidth + horizontalShadowMargin * 2) : collapsedWidth
    }
    var panelHeight: CGFloat {
        // 展开时增加底部的阴影边距（顶部不留白以供物理贴边和阴影裁剪），收起时保持紧凑
        reservesExpandedWindow ? (expandedHeight + bottomShadowMargin) : collapsedHeight
    }

    func reserveWindowForExpansion() {
        collapseReservationTask?.cancel()
        reservesExpandedWindow = true
    }
    func openSettings() {
        onOpenSettings?()
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
