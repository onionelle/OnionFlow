import AppKit
import SwiftUI

// expanded 状态下的播放器界面。这里只转发用户动作，不直接接触 AVPlayer 或文件系统。
struct MusicExpandedView: View {
    @ObservedObject var viewModel: IslandViewModel
    @ObservedObject var musicViewModel: MusicPlayerViewModel
    @ObservedObject var quickLaunchViewModel: QuickLaunchViewModel
    @ObservedObject var temporaryTrayViewModel: TemporaryTrayViewModel
    @ObservedObject var systemMetricsViewModel: SystemMetricsViewModel
    private let sectionSpacing: CGFloat = 12
    private let separatorLineHeight: CGFloat = 0.6
    private let separatorVerticalPadding: CGFloat = 4
    /// 播放器、列表、快捷启动、临时暂存和底部系统状态共用的左右边距。
    private let expandedContentInset: CGFloat = 36

    enum ExpandedTab {
        case local
        case online
        case lyrics
    }
    @Binding var selectedTab: ExpandedTab

    var body: some View {
        VStack(spacing: sectionSpacing) {

            // 顶部高保真仪表盘：左侧黑胶歌词卡，右侧风琴控制台，充分利用横向黄金比例
            HStack(alignment: .center, spacing: 0) {
                // 左侧：黑胶唱片与歌曲信息卡
                HStack(spacing: 16) {
                    ZStack {
                        // 静态发光底盘：使用静态模糊圆代替动态阴影修饰符，避免高频刷新下每一帧重复执行 GPU 阴影光栅化
                        if musicViewModel.state == .playing {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            musicAccentColor.opacity(0.42),
                                            musicAccentColor.opacity(0)
                                        ],
                                        center: .center,
                                        startRadius: 6,
                                        endRadius: 26
                                    )
                                )
                                .frame(width: 52, height: 52)
                        }

                        VinylRecordView(isPlaying: musicViewModel.state == .playing)
                            .frame(width: 64, height: 64)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text(musicViewModel.titleText)
                            .font(IslandTypography.display)
                            .foregroundStyle(.white.opacity(0.92))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: 240, alignment: .leading)

                        HStack(spacing: 6) {
                            playbackStatusBadge
                            playbackModeBadge
                        }
                    }
                }

                Spacer(minLength: 20)

                // 右侧：媒体控制控制台 (Pure 3-Button Playback Console)
                HStack(spacing: 12) {
                    // 1. 上一首 (32pt)
                    playerIconButton(
                        systemName: "backward.fill",
                        title: "上一首",
                        size: 32,
                        iconSize: 12,
                        backgroundColor: Color.white.opacity(0.04)
                    ) {
                        musicViewModel.playPreviousTrack()
                    }
                    .disabled(!musicViewModel.canPlayPrevious)
                    .opacity(musicViewModel.canPlayPrevious ? 1 : 0.3)

                    // 2. 播放/暂停 (48pt)
                    playerButton(
                        systemName: musicViewModel.playPauseSystemName,
                        title: musicViewModel.state == .playing ? "暂停" : "播放",
                        isPrimary: true
                    ) {
                        musicViewModel.togglePlayPause()
                    }
                    .disabled(musicViewModel.state == .loading)
                    .opacity(musicViewModel.state == .loading ? 0.45 : 1)

                    // 3. 下一首 (32pt)
                    playerIconButton(
                        systemName: "forward.fill",
                        title: "下一首",
                        size: 32,
                        iconSize: 12,
                        backgroundColor: Color.white.opacity(0.04)
                    ) {
                        musicViewModel.playNextTrack()
                    }
                    .disabled(!musicViewModel.canPlayNext)
                    .opacity(musicViewModel.canPlayNext ? 1 : 0.3)
                }
            }
            .frame(height: 64)
            .padding(.bottom, -14)

            MusicPlaybackTimelineView(musicViewModel: musicViewModel)
                .padding(.top, 4)



            if viewModel.isPlaylistEnabled {
                // 播放列表整体组件（头部与滚动列表一体化毛玻璃卡片，极致协调与整洁）
                MusicPlaylistPanelView(
                    musicViewModel: musicViewModel,
                    selectedTab: $selectedTab,
                    previewHeight: playlistPreviewHeight
                )
            }

            if viewModel.isQuickLaunchEnabled {
                // 快捷 App 启动器面板 (独立拖拽接收靶区)
                QuickLaunchView(viewModel: quickLaunchViewModel)
            }

            if viewModel.isTemporaryTrayEnabled {
                if viewModel.isPlaylistEnabled || viewModel.isQuickLaunchEnabled {
                    // 仅当上方有播放列表或快捷启动时，才显示分割线
                    gradientSeparator()
                }
                TemporaryTrayView(viewModel: temporaryTrayViewModel)
            }
        }
        .padding(.horizontal, expandedContentInset)
        .padding(.top, 18)
        .padding(.bottom, currentBottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.98)) {
                        viewModel.collapseIsland()
                    }
                }
        )
        .overlay(alignment: .top) {
            if !viewModel.isPlaylistEnabled || selectedTab != .lyrics {
                CompactLyricHintView(lyricsViewModel: musicViewModel.lyricsViewModel)
                    .padding(.horizontal, expandedContentInset)
                    .padding(.top, 0)
            }
        }
        .onHover { hovering in
            if hovering {
                NSCursor.arrow.set()
            }
        }
        .onAppear {
            musicViewModel.showLyrics()
        }
        .onChange(of: musicViewModel.currentTrack?.url) {
            musicViewModel.showLyrics()
        }
        .onChange(of: viewModel.isPlaylistEnabled) { _, isEnabled in
            if !isEnabled {
                musicViewModel.dropFrame = .zero
            }
            musicViewModel.showLyrics()
        }
        .onChange(of: viewModel.isQuickLaunchEnabled) { _, isEnabled in
            if !isEnabled {
                quickLaunchViewModel.dropFrame = .zero
            }
        }
        .onChange(of: viewModel.isTemporaryTrayEnabled) { _, isEnabled in
            if !isEnabled {
                temporaryTrayViewModel.dropFrame = .zero
            }
        }
        .overlay(alignment: .bottom) {
            HStack(spacing: 4) {
                LayoutToggleButton(
                    systemName: "list.bullet.rectangle.portrait",
                    title: viewModel.isPlaylistEnabled ? "隐藏播放列表与歌词" : "显示播放列表与歌词",
                    isActive: viewModel.isPlaylistEnabled,
                    activeColor: Color(red: 0.33, green: 0.57, blue: 0.94)
                ) {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                        viewModel.setPlaylistEnabled(!viewModel.isPlaylistEnabled)
                    }
                }

                LayoutToggleButton(
                    systemName: "bolt.fill",
                    title: viewModel.isQuickLaunchEnabled ? "隐藏快捷启动" : "显示快捷启动",
                    isActive: viewModel.isQuickLaunchEnabled,
                    activeColor: Color(red: 0.98, green: 0.68, blue: 0.22)
                ) {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                        viewModel.setQuickLaunchEnabled(!viewModel.isQuickLaunchEnabled)
                    }
                }

                LayoutToggleButton(
                    systemName: "tray.full.fill",
                    title: viewModel.isTemporaryTrayEnabled ? "隐藏临时暂存" : "显示临时暂存",
                    isActive: viewModel.isTemporaryTrayEnabled,
                    activeColor: Color(red: 0.45, green: 0.72, blue: 0.96)
                ) {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                        viewModel.setTemporaryTrayEnabled(!viewModel.isTemporaryTrayEnabled)
                    }
                }
            }
            .padding(.bottom, 8)
        }
        .overlay(alignment: .bottomLeading) {
            SystemMetricsStripView(viewModel: systemMetricsViewModel, placement: .hardware)
                .allowsHitTesting(false)
                .padding(.leading, expandedContentInset)
                .padding(.bottom, 14)
        }
        .overlay(alignment: .bottomTrailing) {
            SystemMetricsStripView(viewModel: systemMetricsViewModel, placement: .network)
                .allowsHitTesting(false)
                .padding(.trailing, expandedContentInset)
                .padding(.bottom, 14)
        }
    }

    private var playlistPreviewHeight: CGFloat {
        174
    }

    private var currentBottomPadding: CGFloat {
        if viewModel.isTemporaryTrayEnabled {
            // 留白设为 12pt。由于临时暂存虚线框向下偏移了 8pt，
            // 这样虚线框底边与灵动岛底沿刚好留出 4pt 的精致微小边距，既美观又防止圆角裁切
            return 12
        } else {
            // 临时暂存关闭时，底部无论是快捷启动还是播放列表，均保留与仅开快捷启动完全一致的 26pt 优雅大留白，维持极致开阔的视觉张力
            return 26
        }
    }



    @ViewBuilder
    private var playbackStatusBadge: some View {
        if musicViewModel.hasPlaybackError {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 9, weight: .regular))
                Text(musicViewModel.errorText ?? "无法播放")
                    .font(.system(size: 9, weight: .regular))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 160, alignment: .leading)
            }
            .foregroundStyle(Color(red: 0.98, green: 0.58, blue: 0.16))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color(red: 0.98, green: 0.58, blue: 0.16).opacity(0.12))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color(red: 0.98, green: 0.58, blue: 0.16).opacity(0.24), lineWidth: 0.5)
            )
            .help(musicViewModel.errorText ?? "")
        } else {
            HStack(spacing: 4) {
                Circle()
                    .fill(musicViewModel.state == .playing ? musicAccentColor : Color.white.opacity(0.35))
                    .frame(width: 4.5, height: 4.5)
                    .shadow(color: musicViewModel.state == .playing ? musicAccentColor.opacity(0.6) : Color.clear, radius: 3)

                Text(musicViewModel.stateText)
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.48))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.04))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
        }
    }

    @ViewBuilder
    private var playbackModeBadge: some View {
        Button(action: {
            musicViewModel.togglePlaybackMode()
        }) {
            HStack(spacing: 4) {
                Image(systemName: musicViewModel.playbackModeSystemName)
                    .font(.system(size: 9, weight: .regular))
                Text(musicViewModel.playbackModeText)
                    .font(.system(size: 9, weight: .regular))
            }
            .foregroundStyle(musicAccentColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.04))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(musicAccentColor.opacity(0.24), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func playerButton(
        systemName: String,
        title: String,
        isPrimary: Bool,
        foregroundStyle: Color = .white,
        hoverFill: Color = Color.white.opacity(0.14),
        action: @escaping () -> Void
    ) -> some View {
        let size: CGFloat = isPrimary ? 48 : 32

        let button = Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: isPrimary ? 20 : 13, weight: .light))
                .foregroundStyle(foregroundStyle)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(isPrimary ? musicAccentColor.opacity(0.92) : Color.clear)
                )
                .shadow(color: isPrimary ? musicAccentColor.opacity(0.34) : Color.clear, radius: 8, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .help(title)

        if isPrimary {
            return AnyView(button)
        }
        return AnyView(button.modifier(MusicButtonHoverEffect(fill: hoverFill)))
    }

    private func playerIconButton(
        systemName: String,
        title: String,
        size: CGFloat = 32,
        iconSize: CGFloat = 13,
        backgroundColor: Color = Color.clear,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .regular))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(backgroundColor)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .help(title)
        .modifier(MusicButtonHoverEffect(fill: Color.white.opacity(0.12)))
    }

    // Sleek 渐变半透明分割线
    private func gradientSeparator() -> some View {
        LinearGradient(
            colors: [.clear, .white.opacity(0.12), .clear],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: separatorLineHeight)
        .padding(.vertical, separatorVerticalPadding)
    }

}

// ==========================================
// 底部极简指示灯快捷开关（支持物理回弹悬停光晕）
// ==========================================
private struct LayoutToggleButton: View {
    @State private var isHovered = false
    let systemName: String
    let title: String
    let isActive: Bool
    let activeColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 8, weight: .regular))
                .foregroundStyle(
                    isActive
                        ? (isHovered ? activeColor : activeColor.opacity(0.85))
                        : (isHovered ? Color.white.opacity(0.68) : Color.white.opacity(0.24))
                )
                .scaleEffect(isHovered ? 1.22 : 1.0)
                // 悬停时柔和点亮微型霓虹散射阴影，增加视觉深度
                .shadow(
                    color: isActive
                        ? activeColor.opacity(isHovered ? 0.82 : 0.0)
                        : Color.white.opacity(isHovered ? 0.35 : 0.0),
                    radius: 3.5
                )
                .frame(width: 16, height: 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
        .onHover { hovering in
            withAnimation(.spring(response: 0.22, dampingFraction: 0.76)) {
                isHovered = hovering
            }
            if hovering {
                NSCursor.arrow.set()
            }
        }
    }
}

private struct MusicPlaybackTimelineView: View {
    @ObservedObject var progressClock: MusicProgressClock
    let duration: TimeInterval
    let hasTrack: Bool
    let onScrubbingChanged: (Double) -> Void
    let onScrubbingEnded: (Double) -> Void

    init(musicViewModel: MusicPlayerViewModel) {
        self.progressClock = musicViewModel.progressClock
        self.duration = musicViewModel.duration
        self.hasTrack = musicViewModel.hasTrack
        self.onScrubbingChanged = { musicViewModel.updateScrubbingProgress($0) }
        self.onScrubbingEnded = { musicViewModel.endScrubbing(at: $0) }
    }

    private var progress: Double {
        guard duration > 0 else { return 0 }
        let time = progressClock.scrubbingTime ?? progressClock.currentTime
        return min(max(time / duration, 0), 1)
    }

    var body: some View {
        VStack(spacing: 6) {
            MusicTimelineSlider(
                progress: progress,
                isEnabled: hasTrack,
                onScrubbingChanged: onScrubbingChanged,
                onScrubbingEnded: onScrubbingEnded
            )

            HStack {
                Text(formatTime(progressClock.scrubbingTime ?? progressClock.currentTime))
                Spacer(minLength: 0)
                Text(formatTime(duration))
            }
            .font(IslandTypography.mono)
            .foregroundStyle(.white.opacity(hasTrack ? 0.58 : 0.30))
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "00:00" }
        let totalSeconds = Int(seconds)
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}

private struct CompactLyricHintView: View {
    @ObservedObject var lyricsViewModel: LyricsViewModel

    private var currentLyricText: String {
        switch lyricsViewModel.state {
        case .success:
            if let currentLineIndex = lyricsViewModel.currentLineIndex,
               lyricsViewModel.lyricLines.indices.contains(currentLineIndex) {
                return lyricsViewModel.lyricLines[currentLineIndex].text
            }
            return ""
        case .noLyrics, .onlineDisabled, .failed, .candidates:
            return "暂无歌词，可展开面板进行手动匹配"
        default:
            return ""
        }
    }

    private var isLyricHintText: Bool {
        currentLyricText == "暂无歌词，可展开面板进行手动匹配"
    }

    var body: some View {
        Text(currentLyricText)
            .font(.system(size: isLyricHintText ? 8.5 : 9, weight: .regular))
            .tracking(isLyricHintText ? 0.28 : 0)
            .foregroundStyle(isLyricHintText ? Color.white.opacity(0.36) : musicAccentColor.opacity(currentLyricText.isEmpty ? 0 : 0.95))
            .shadow(color: isLyricHintText ? Color.clear : musicAccentColor.opacity(currentLyricText.isEmpty ? 0 : 0.58), radius: 3.5)
            .lineLimit(1)
            .truncationMode(.tail)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 16, maxHeight: 16, alignment: .center)
            .animation(.easeInOut(duration: 0.18), value: currentLyricText)
    }
}
