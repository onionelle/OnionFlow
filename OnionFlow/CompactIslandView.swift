import SwiftUI

// compact 顶栏负责常驻信息和工具按钮；音乐控制集中在 expanded mini player。
struct CompactIslandView: View {
    @ObservedObject var viewModel: IslandViewModel
    @ObservedObject var musicViewModel: MusicPlayerViewModel
    @AppStorage("mascotKind") private var mascotKindRawValue = "pixelPuppy"
    let onToggleExpansion: () -> Void

    var body: some View {
        ZStack {
            MascotView(
                kind: MascotKind(rawValue: mascotKindRawValue) ?? .pixelPuppy,
                state: mascotState,
                size: 32
            )
            .frame(width: viewModel.collapsedHeight, height: viewModel.collapsedHeight)
            .clipped()
            .allowsHitTesting(false)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, compactLeadingPadding)

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
            CompactMusicActivityIndicator(
                isPlaying: musicViewModel.state == .playing,
                hasMusicContext: {
                    switch musicViewModel.state {
                    case .playing, .paused, .loading:
                        return true
                    case .idle, .failed:
                        return false
                    }
                }()
            )
                .allowsHitTesting(false)
        }
    }

    private var compactExpansionTapLayer: some View {
        Color.clear
            .padding(.trailing, 100)
            .contentShape(Rectangle())
            .onTapGesture {
                onToggleExpansion()
            }
    }

    private var compactLeadingPadding: CGFloat {
        viewModel.isExpanded ? 15 : 10
    }

    private var compactTrailingPadding: CGFloat {
        viewModel.isExpanded ? 20 : 17
    }

    private var mascotState: MascotState {
        // 未播放保持 idle：呼吸走 CALayer，避免 working / music 的 Canvas 时间轴常驻。
        musicViewModel.state == .playing ? .music : .idle
    }
}
