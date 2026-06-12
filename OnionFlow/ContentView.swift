import AppKit
import SwiftUI

// 主 island 视图。这里同时处理 SwiftUI 可见壳体和 AppKit 透明窗口尺寸不同步的问题。
struct ContentView: View {
    @ObservedObject var viewModel: IslandViewModel
    @ObservedObject var musicViewModel: MusicPlayerViewModel
    @ObservedObject var quickLaunchViewModel: QuickLaunchViewModel
    @ObservedObject var temporaryTrayViewModel: TemporaryTrayViewModel
    // expanded 内容会在收起时卸载；标签状态留在常驻父视图，重新展开后保持用户上次选择。
    @State private var selectedExpandedTab: MusicExpandedView.ExpandedTab = .local

    var body: some View {
        ZStack(alignment: .top) {
            // AppKit 窗口可以先保留 expanded 尺寸；可见黑色壳体用 Spacer 锁在窗口中心，避免展开前向左跳。
            HStack(alignment: .top, spacing: 0) {
                Spacer(minLength: 0)
                islandContainer {
                    expandedLayout
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(width: viewModel.panelWidth, height: viewModel.panelHeight, alignment: .top)
    }

    // expanded 内容仍挂在同一个 island 壳体里，避免形成第二层卡片。
    private var expandedLayout: some View {
        VStack(spacing: 0) {
            CompactIslandView(
                viewModel: viewModel,
                musicViewModel: musicViewModel,
                onToggleExpansion: toggleIslandExpansion
            )

            if viewModel.isExpanded {
                ExpandedIslandView(
                    viewModel: viewModel,
                    musicViewModel: musicViewModel,
                    quickLaunchViewModel: quickLaunchViewModel,
                    temporaryTrayViewModel: temporaryTrayViewModel,
                    selectedExpandedTab: $selectedExpandedTab,
                    onCollapse: {
                        viewModel.collapseIsland()
                    }
                )
                .transition(expandedPanelTransition)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var islandOpenAnimation: Animation {
        .interactiveSpring(response: 0.34, dampingFraction: 0.90, blendDuration: 0.08)
    }

    private var islandCloseAnimation: Animation {
        .spring(response: 0.30, dampingFraction: 0.98)
    }

    // 展开分两步：先放大 AppKit 透明窗口，再在下一帧展开 SwiftUI 壳体。
    // 这样可以避免窗口 frame 变化和 SwiftUI 形变同时发生导致顶部漂移。
    private func toggleIslandExpansion() {
        if viewModel.isExpanded {
            withAnimation(islandCloseAnimation) {
                viewModel.collapseIsland()
            }
        } else {
            viewModel.reserveWindowForExpansion()
            #if arch(x86_64)
            // Intel 架构：延迟 80ms 以避开显卡重绘和窗口大小调整瓶颈
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(islandOpenAnimation) {
                    viewModel.expandIsland()
                }
            }
            #else
            // Apple Silicon 架构：0 延迟瞬间展开
            DispatchQueue.main.async {
                withAnimation(islandOpenAnimation) {
                    viewModel.expandIsland()
                }
            }
            #endif
        }
    }

    private var expandedPanelTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity,
            removal: .offset(y: -6)
                .combined(with: .blurFade)
                .combined(with: .opacity)
        )
    }

    private var islandShape: some InsettableShape {
        NotchIslandShape(
            shoulderRadius: viewModel.shoulderRadius,
            bottomRadius: viewModel.bottomCornerRadius
        )
    }

    private func islandContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            // 背景层：保持单层黑色壳体，并仅在展开态绘制外侧投影以强化层次。
            islandShape
                .fill(Color.black)
                .shadow(
                    color: Color.black.opacity(viewModel.isExpanded ? 0.9 : 0.0),
                    radius: viewModel.isExpanded ? 8 : 0,
                    x: 0,
                    y: 0
                )

            // 内容层：必须单独裁剪，防止子视图溢出灵动岛的弧线圆角边界。
            content()
                .clipShape(islandShape)
        }
        .frame(width: viewModel.islandWidth, height: viewModel.islandHeight, alignment: .top)
        .onHover { hovering in
            if hovering {
                NSCursor.arrow.set()
            }
        }
    }
}

private struct BlurFadeModifier: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        content
            .blur(radius: active ? 4 : 0)
            .opacity(active ? 0 : 1)
    }
}

extension AnyTransition {
    static var blurFade: AnyTransition {
        .modifier(
            active: BlurFadeModifier(active: true),
            identity: BlurFadeModifier(active: false)
        )
    }
}

// 预览只负责快速检查壳体轮廓和默认布局，不代表运行时窗口层级。
#if DEBUG
#Preview {
    ContentView(
        viewModel: IslandViewModel(),
        musicViewModel: MusicPlayerViewModel(restoresPlaylistOnInit: false),
        quickLaunchViewModel: QuickLaunchViewModel(),
        temporaryTrayViewModel: TemporaryTrayViewModel()
    )
    .padding()
    .background(Color.gray.opacity(0.3))
}
#endif
