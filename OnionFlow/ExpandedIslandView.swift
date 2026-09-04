import SwiftUI

// expanded 内容壳体负责背景、空白收起手势和播放器内容承载。
struct ExpandedIslandView: View {
    @ObservedObject var viewModel: IslandViewModel
    @ObservedObject var musicViewModel: MusicPlayerViewModel
    @ObservedObject var quickLaunchViewModel: QuickLaunchViewModel
    @ObservedObject var temporaryTrayViewModel: TemporaryTrayViewModel
    @ObservedObject var systemMetricsViewModel: SystemMetricsViewModel
    @Binding var selectedExpandedTab: MusicExpandedView.ExpandedTab
    let onCollapse: () -> Void

    var body: some View {
        // 气氛背景改由 ContentView 铺满整岛；这里只承载播放器，避免顶栏和内容各画一层底。
        MusicExpandedView(
            viewModel: viewModel,
            musicViewModel: musicViewModel,
            quickLaunchViewModel: quickLaunchViewModel,
            temporaryTrayViewModel: temporaryTrayViewModel,
            systemMetricsViewModel: systemMetricsViewModel,
            selectedTab: $selectedExpandedTab
        )
    }
}
