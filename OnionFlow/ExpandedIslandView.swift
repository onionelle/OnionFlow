import SwiftUI

// expanded 内容壳体负责背景、空白收起手势和播放器内容承载。
struct ExpandedIslandView: View {
    @ObservedObject var viewModel: IslandViewModel
    @ObservedObject var musicViewModel: MusicPlayerViewModel
    @ObservedObject var quickLaunchViewModel: QuickLaunchViewModel
    @ObservedObject var temporaryTrayViewModel: TemporaryTrayViewModel
    @AppStorage("backgroundNebulaEnabled") private var backgroundNebulaEnabled = false
    @AppStorage("backgroundParticlesEnabled") private var backgroundParticlesEnabled = false
    @AppStorage("backgroundNebulaTheme") private var backgroundNebulaThemeRawValue = "charcoal"
    @Binding var selectedExpandedTab: MusicExpandedView.ExpandedTab
    let onCollapse: () -> Void

    var body: some View {
        ZStack {
            // Antigravity 动态粒子与星云特效背景层，根据开关按需开启；关闭时切到纯暗色静止背景以降低 CPU/GPU 负载。
            if backgroundNebulaEnabled || backgroundParticlesEnabled {
                AntigravityBackgroundView(
                    musicViewModel: musicViewModel,
                    showNebula: backgroundNebulaEnabled,
                    showParticles: backgroundParticlesEnabled,
                    nebulaTheme: NebulaTheme(rawValue: backgroundNebulaThemeRawValue) ?? .charcoal
                )
                .allowsHitTesting(false)
            } else {
                Color(red: 0.04, green: 0.04, blue: 0.06)
                    .allowsHitTesting(false)
            }

            // 顶部 50pt 黑色羽化渐变：用于在 Compact（纯黑）与下方 Expanded（气氛渐变）交界处建立平滑的视觉过渡
            VStack {
                LinearGradient(
                    colors: [.black, .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 50)
                Spacer()
            }
            .allowsHitTesting(false)

            // 播放器主体视图（空白收起手势由其根部 VStack 的背景承载，防止 ZStack 遮挡）
            MusicExpandedView(
                viewModel: viewModel,
                musicViewModel: musicViewModel,
                quickLaunchViewModel: quickLaunchViewModel,
                temporaryTrayViewModel: temporaryTrayViewModel,
                selectedTab: $selectedExpandedTab
            )
            .allowsHitTesting(true)
        }
    }
}
