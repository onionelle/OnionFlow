import AppKit
import SwiftUI

// 主 island 视图。这里同时处理 SwiftUI 可见壳体和 AppKit 透明窗口尺寸不同步的问题。
struct ContentView: View {
    @ObservedObject var viewModel: IslandViewModel
    @ObservedObject var musicViewModel: MusicPlayerViewModel
    @ObservedObject var quickLaunchViewModel: QuickLaunchViewModel
    // 设置页通过 AppStorage 写入角色选择，顶部 island 直接读取同一个 key。
    @AppStorage("mascotKind") private var mascotKindRawValue = "sleepCapsule"
    @AppStorage("mascotEnabled") private var mascotEnabled = true
    @AppStorage("mascotSize") private var mascotSize = 32.0
    var body: some View {
        ZStack(alignment: .top) {
            // AppKit 窗口可以先保留 expanded 尺寸；可见黑色壳体用 Spacer 锁在窗口中心，避免展开前向左跳。
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                islandContainer {
                    expandedLayout
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(width: viewModel.panelWidth, height: viewModel.panelHeight, alignment: .top)
        .coordinateSpace(name: "island_panel")
    }
    // expanded 内容仍挂在同一个 island 壳体里，避免形成第二层卡片。
    private var expandedLayout: some View {
        VStack(spacing: 0) {
            compactBar
            if viewModel.isExpanded {
                expandedPanel
                    .transition(expandedPanelTransition)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    private var compactBar: some View {
        defaultCompactBar
    }
    // compact 顶栏负责常驻信息和工具按钮；音乐控制集中在 expanded mini player。
    private var defaultCompactBar: some View {
        ZStack {
            if mascotEnabled {
                MascotView(
                    kind: MascotKind(rawValue: mascotKindRawValue) ?? .sleepCapsule,
                    state: mascotState,
                    size: mascotSize
                )
                .frame(width: viewModel.collapsedHeight, height: viewModel.collapsedHeight)
                .clipped()
                .allowsHitTesting(false)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, compactLeadingPadding)
            }
            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
                .rotationEffect(.degrees(viewModel.isExpanded ? 180 : 0))
                .scaleEffect(viewModel.isExpanded ? 1.04 : 1)
            compactTrailingAccessory
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, compactTrailingPadding)
        }
        .frame(height: viewModel.collapsedHeight)
        // 只把背景层作为展开/收起热区，避免右侧按钮点击被父级手势抢走。
        .background(compactExpansionTapLayer)
    }
    @ViewBuilder
    private var compactTrailingAccessory: some View {
        if viewModel.isExpanded {
            IslandToolButtonsView(
                viewModel: viewModel,
                musicViewModel: musicViewModel
            )
        } else {
            CompactMusicActivityIndicator(state: musicViewModel.state)
                .allowsHitTesting(false)
        }
    }
    private var compactExpansionTapLayer: some View {
        Color.clear
            .padding(.trailing, 100)
            .contentShape(Rectangle())
            .onTapGesture {
                toggleIslandExpansion()
            }
    }
    private var compactLeadingPadding: CGFloat {
        viewModel.isExpanded ? 15 : 10
    }
    private var compactTrailingPadding: CGFloat {
        viewModel.isExpanded ? 20 : 14
    }
    private var mascotState: MascotState {
        if musicViewModel.state == .playing {
            return .music
        }
        return viewModel.isExpanded ? .working : .idle
    }
    // 背景点击层用于收起 expanded；mini player 自己仍可接收按钮和滑杆交互。
    private var expandedPanel: some View {
        ZStack {
            // Antigravity 动态粒子与星云特效背景层，不响应任何手势
            AntigravityBackgroundView(musicViewModel: musicViewModel)
                .allowsHitTesting(false)

            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(islandCloseAnimation) {
                        viewModel.collapseIsland()
                    }
                }
            MusicExpandedView(
                musicViewModel: musicViewModel,
                quickLaunchViewModel: quickLaunchViewModel
            )
                .allowsHitTesting(true)
        }
        .clipShape(islandShape)
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
            DispatchQueue.main.async {
                withAnimation(islandOpenAnimation) {
                    viewModel.expandIsland()
                }
            }
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
            // 背景层：应用扁平黑色填充和星空投影，允许投影外溢
            islandShape
                .fill(Color.black)
                .shadow(
                    color: Color.black.opacity(viewModel.isExpanded ? 0.9 : 0.0),
                    radius: viewModel.isExpanded ? 8 : 0,
                    x: 0,
                    y: 0
                )
            
            // 内容层：必须单独裁剪，防止子视图溢出灵动岛的弧线圆角边界
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
// notch-style 外轮廓。核心约束是顶部贴边、两侧 inward shoulder、底部连续圆角。
private struct NotchIslandShape: InsettableShape {
    var shoulderRadius: CGFloat
    var bottomRadius: CGFloat
    private var insetAmount: CGFloat = 0
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(shoulderRadius, bottomRadius) }
        set {
            shoulderRadius = newValue.first
            bottomRadius = newValue.second
        }
    }
    init(shoulderRadius: CGFloat, bottomRadius: CGFloat) {
        self.shoulderRadius = shoulderRadius
        self.bottomRadius = bottomRadius
    }
    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        // 半径和深度都做夹取，避免 compact 宽高较小时曲线自交或退化成普通 capsule。
        let shoulderRadius = min(max(3, shoulderRadius), rect.width * 0.16)
        let bottomRadius = min(max(10, bottomRadius), rect.height / 2)
        let shoulderDepth = min(max(shoulderRadius * 0.84, 5), rect.height - bottomRadius - 6)
        let curveTightness: CGFloat = 0.82

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        // 左右肩部使用镜像曲线；控制点略收紧，让轮廓保持 notch 感而不是圆角矩形。
        path.addCurve(
            to: CGPoint(x: rect.maxX - shoulderRadius, y: rect.minY + shoulderDepth),
            control1: CGPoint(x: rect.maxX - shoulderRadius * 0.82, y: rect.minY),
            control2: CGPoint(x: rect.maxX - shoulderRadius, y: rect.minY + shoulderDepth * curveTightness)
        )
        path.addLine(to: CGPoint(x: rect.maxX - shoulderRadius, y: rect.maxY - bottomRadius))
        path.addCurve(
            to: CGPoint(x: rect.maxX - shoulderRadius - bottomRadius, y: rect.maxY),
            control1: CGPoint(x: rect.maxX - shoulderRadius, y: rect.maxY - bottomRadius * (1 - curveTightness)),
            control2: CGPoint(x: rect.maxX - shoulderRadius - bottomRadius * (1 - curveTightness), y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + shoulderRadius + bottomRadius, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.minX + shoulderRadius, y: rect.maxY - bottomRadius),
            control1: CGPoint(x: rect.minX + shoulderRadius + bottomRadius * (1 - curveTightness), y: rect.maxY),
            control2: CGPoint(x: rect.minX + shoulderRadius, y: rect.maxY - bottomRadius * (1 - curveTightness))
        )
        path.addLine(to: CGPoint(x: rect.minX + shoulderRadius, y: rect.minY + shoulderDepth))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.minY),
            control1: CGPoint(x: rect.minX + shoulderRadius, y: rect.minY + shoulderDepth * curveTightness),
            control2: CGPoint(x: rect.minX + shoulderRadius * 0.82, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
    func inset(by amount: CGFloat) -> some InsettableShape {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}
// 预览只负责快速检查壳体轮廓和默认布局，不代表运行时窗口层级。
#Preview {
    ContentView(
        viewModel: IslandViewModel(),
        musicViewModel: MusicPlayerViewModel(restoresPlaylistOnInit: false),
        quickLaunchViewModel: QuickLaunchViewModel()
    )
        .padding()
        .background(Color.gray.opacity(0.3))
}
