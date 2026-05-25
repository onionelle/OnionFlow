import AppKit
import SwiftUI

// expanded 状态下的播放器界面。这里只转发用户动作，不直接接触 AVPlayer 或文件系统。
struct MusicExpandedView: View {
    @ObservedObject var musicViewModel: MusicPlayerViewModel
    @ObservedObject var quickLaunchViewModel: QuickLaunchViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            // 顶部高保真仪表盘：左侧黑胶歌词卡，右侧风琴控制台，充分利用横向黄金比例
            HStack(alignment: .center, spacing: 0) {
                // 左侧：黑胶唱片与歌曲信息卡
                HStack(spacing: 16) {
                    VinylRecordView(isPlaying: musicViewModel.state == .playing)
                        .frame(width: 64, height: 64)
                        .shadow(color: musicAccentColor.opacity(musicViewModel.state == .playing ? 0.35 : 0), radius: 12)
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text(musicViewModel.titleText)
                            .font(.system(size: 15, weight: .bold))
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
            .padding(.bottom, 6)
            
            // 进度条与时间控制
            VStack(spacing: 6) {
                // 精致无缝滑动进度条，Knob 仅在 Hover/Scrubbing 时才平滑显示，减少视觉噪音
                MusicTimelineSlider(
                    progress: musicViewModel.progress,
                    isEnabled: musicViewModel.hasTrack,
                    onScrubbingChanged: { progress in
                        musicViewModel.updateScrubbingProgress(progress)
                    },
                    onScrubbingEnded: { progress in
                        musicViewModel.endScrubbing(at: progress)
                    }
                )
                
                HStack {
                    Text(musicViewModel.currentTimeText)
                    Spacer(minLength: 0)
                    Text(musicViewModel.durationText)
                }
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(.white.opacity(musicViewModel.hasTrack ? 0.58 : 0.30))
            }
            .padding(.top, 4)
            
            // 播放列表整体组件（头部与滚动列表一体化毛玻璃卡片，极致协调与整洁）
            playlistComponent()
                .padding(.top, 4)
            
            // 视觉隔离：精致渐变半透明分割线
            gradientSeparator()
            
            // 快捷 App 启动器面板 (独立拖拽接收靶区)
            quickLauncherPanel()
        }
        .padding(.horizontal, 54)
        .padding(.top, 30)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onHover { hovering in
            if hovering {
                NSCursor.arrow.set()
            }
        }
    }
    
    @ViewBuilder
    private var playbackStatusBadge: some View {
        if musicViewModel.hasPlaybackError {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 9, weight: .bold))
                Text(musicViewModel.errorText ?? "无法播放")
                    .font(.system(size: 9.5, weight: .semibold))
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
        } else {
            HStack(spacing: 4) {
                Circle()
                    .fill(musicViewModel.state == .playing ? musicAccentColor : Color.white.opacity(0.35))
                    .frame(width: 4.5, height: 4.5)
                    .shadow(color: musicViewModel.state == .playing ? musicAccentColor.opacity(0.6) : Color.clear, radius: 3)
                
                Text(musicViewModel.stateText)
                    .font(.system(size: 9.8, weight: .semibold))
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
                    .font(.system(size: 9, weight: .bold))
                Text(musicViewModel.playbackModeText)
                    .font(.system(size: 9.5, weight: .semibold))
            }
            .foregroundStyle((musicViewModel.playbackMode == .loop || musicViewModel.playbackMode == .singleLoop) ? musicAccentColor : Color.white.opacity(0.48))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.04))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(((musicViewModel.playbackMode == .loop || musicViewModel.playbackMode == .singleLoop) ? musicAccentColor.opacity(0.24) : Color.white.opacity(0.08)), lineWidth: 0.5)
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
                .font(.system(size: isPrimary ? 20 : 13, weight: .semibold))
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
        return AnyView(button.modifier(ButtonHoverEffect(fill: hoverFill)))
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
                .font(.system(size: iconSize, weight: .semibold))
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
        .modifier(ButtonHoverEffect(fill: Color.white.opacity(0.12)))
    }
    
    // 一体化播放列表整体组件（头部与滚动列表高度协同）
    private func playlistComponent() -> some View {
        VStack(spacing: 0) {
            playlistHeaderBar()
            playlistPreview()
        }
        .background(playlistContainerBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(playlistContainerBorder)
        .overlay(dropTargetOverlay)
        // 将播放列表卡片在 hosting view 坐标系下的 frame 实时上报给 ViewModel，
        // 供 AppKit 拖拽热区判断使用，避免硬编码坐标与实际视图位置偏移。
        .overlay(
            DropFrameReporter { frame in
                musicViewModel.dropFrame = frame
            }
        )
    }
    
    // 精美的一体化卡片头部导航统计栏
    private func playlistHeaderBar() -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Text("播放列表")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                    
                    if !musicViewModel.playlist.isEmpty {
                        Text("\(musicViewModel.playlist.count)")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(musicAccentColor)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(musicAccentColor.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                
                Spacer()
                
                // 右侧功能键：[ 添加 ] 和 [ 清空 ]
                HStack(spacing: 6) {
                    MiniAddButton {
                        Task {
                            await musicViewModel.addFilesOrDirectoriesToPlaylist()
                        }
                    }
                    
                    if !musicViewModel.playlist.isEmpty {
                        MiniTrashButton {
                            musicViewModel.clearPlaylistAndPlayback()
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(Color.white.opacity(0.025))
            
            // 极细半透明白色边界线，呈现精致微刻感
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 0.6)
        }
    }
    
    private func playlistPreview() -> some View {
        GeometryReader { geometry in
            ScrollView(showsIndicators: false) {
                if musicViewModel.playlist.isEmpty {
                    emptyPlaylistRow()
                        .frame(width: geometry.size.width)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(musicViewModel.playlist.indices, id: \.self) { index in
                            PlaylistPreviewItem(
                                url: musicViewModel.playlist[index],
                                currentIndex: musicViewModel.currentIndex,
                                index: index,
                                onPlay: { idx in
                                    musicViewModel.playTrack(at: idx)
                                },
                                onRemove: { idx in
                                    musicViewModel.removeTrack(at: idx)
                                }
                            )
                            .frame(width: geometry.size.width)
                        }
                    }
                    .padding(.vertical, 2)
                    .frame(width: geometry.size.width, alignment: .leading)
                }
            }
        }
        .frame(height: playlistPreviewHeight)
    }
    
    private var playlistPreviewHeight: CGFloat {
        // 调整为 112pt 紧凑舒适显示 5 首歌曲，完美消除空间冗余
        return 112
    }
    
    private var playlistContainerBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.white.opacity(musicViewModel.playlist.isEmpty ? 0.01 : 0.024))
    }
    
    private var playlistContainerBorder: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(
                Color.white.opacity(musicViewModel.playlist.isEmpty ? 0.06 : 0.08),
                lineWidth: 0.5
            )
            .allowsHitTesting(false)
    }
    
    private var dropTargetOverlay: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(
                musicAccentColor.opacity(musicViewModel.isDropTargeted ? 0.72 : 0),
                style: StrokeStyle(lineWidth: 1.2, dash: [5, 4])
            )
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(musicAccentColor.opacity(musicViewModel.isDropTargeted ? 0.10 : 0))
            )
            .allowsHitTesting(false)
    }
    
    private func emptyPlaylistRow() -> some View {
        VStack(spacing: 6) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.42))
            VStack(spacing: 2) {
                Text("拖拽歌曲或文件夹到此区域")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.68))
                Text("也可以点击右上方添加歌曲")
                    .font(.system(size: 9.5, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.38))
            }
        }
        .frame(maxWidth: .infinity, minHeight: playlistPreviewHeight)
    }
    
    // Sleek 渐变半透明分割线
    private func gradientSeparator() -> some View {
        LinearGradient(
            colors: [.clear, .white.opacity(0.12), .clear],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 0.6)
        .padding(.vertical, 4)
    }
    
    // 快捷 App 启动器面板 (独立拖拽接收靶区)
    private func quickLauncherPanel() -> some View {
        ZStack {
            if quickLaunchViewModel.apps.isEmpty {
                emptyLauncherRow()
            } else {
                GeometryReader { geometry in
                    let itemSpacing = launcherItemSpacing(width: geometry.size.width)
                    
                    HStack(spacing: itemSpacing) {
                        ForEach(0..<quickLaunchViewModel.apps.count, id: \.self) { index in
                            let path = quickLaunchViewModel.apps[index]
                            LauncherItem(
                                path: path,
                                viewModel: quickLaunchViewModel,
                                onReorderChanged: { localX in
                                    let panelX = itemSpacing + CGFloat(index) * (38 + itemSpacing) + localX
                                    quickLaunchViewModel.setDropInsertionIndex(launcherInsertionIndex(forX: panelX, width: geometry.size.width))
                                },
                                onReorderEnded: { localX in
                                    let panelX = itemSpacing + CGFloat(index) * (38 + itemSpacing) + localX
                                    let insertionIndex = launcherInsertionIndex(forX: panelX, width: geometry.size.width)
                                    quickLaunchViewModel.moveApp(path: path, to: insertionIndex)
                                    quickLaunchViewModel.setDropInsertionIndex(nil)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, itemSpacing)
                    .frame(width: geometry.size.width, height: 52, alignment: .leading)
                    .overlay(alignment: .leading) {
                        launcherInsertionOverlay(width: geometry.size.width)
                    }
                }
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.02))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.6)
                )
            }
            
            // 启动器专属拖拽靶区高亮反馈 (天空蓝)
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    Color(red: 0.18, green: 0.68, blue: 0.90).opacity(quickLaunchViewModel.isDropTargeted ? 0.72 : 0),
                    style: StrokeStyle(lineWidth: 1.2, dash: [5, 4])
                )
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(red: 0.18, green: 0.68, blue: 0.90).opacity(quickLaunchViewModel.isDropTargeted ? 0.10 : 0))
                )
                .allowsHitTesting(false)
        }
        .frame(height: 52)
        // 将启动器卡片在 hosting view 坐标系下的 frame 实时上报给 ViewModel，
        // 供 AppKit 拖拽热区判断使用，避免硬编码坐标与实际视图位置偏移。
        .overlay(
            DropFrameReporter { frame in
                quickLaunchViewModel.dropFrame = frame
            }
        )
    }
    
    @ViewBuilder
    private func launcherInsertionOverlay(width: CGFloat) -> some View {
        if let index = quickLaunchViewModel.dropInsertionIndex {
            Capsule()
                .fill(Color(red: 0.18, green: 0.68, blue: 0.90).opacity(0.95))
                .frame(width: 2, height: 34)
                .shadow(color: Color(red: 0.18, green: 0.68, blue: 0.90).opacity(0.85), radius: 5)
                .offset(x: launcherInsertionOffset(for: index, width: width), y: 9)
                .allowsHitTesting(false)
        }
    }
    
    private func launcherItemSpacing(width: CGFloat) -> CGFloat {
        let itemWidth: CGFloat = 38
        let maxItemCount: CGFloat = 9
        let availableSpacing = width - itemWidth * maxItemCount
        // 允许间隔最小降为 6，以使 9 个图标在 525 展开宽度下（可用宽 417，计算间隔 7.5）完美契合不溢出
        return max(6, availableSpacing / (maxItemCount + 1))
    }
    
    private func launcherInsertionOffset(for index: Int, width: CGFloat) -> CGFloat {
        let itemWidth: CGFloat = 38
        let clampedIndex = min(max(index, 0), quickLaunchViewModel.apps.count)
        let itemSpacing = launcherItemSpacing(width: width)
        
        if clampedIndex == 0 {
            return itemSpacing - 1
        }
        
        let previousItemRightEdge = itemSpacing + CGFloat(clampedIndex) * itemWidth + CGFloat(clampedIndex - 1) * itemSpacing
        let offset = previousItemRightEdge + itemSpacing / 2 - 1
        return min(offset, width - itemSpacing - 1)
    }
    
    private func launcherInsertionIndex(forX x: CGFloat, width: CGFloat) -> Int {
        let itemWidth: CGFloat = 38
        let itemSpacing = launcherItemSpacing(width: width)
        let itemStep = itemWidth + itemSpacing
        
        for index in 0..<quickLaunchViewModel.apps.count {
            let itemCenterX = itemSpacing + (itemWidth / 2) + CGFloat(index) * itemStep
            if x < itemCenterX {
                return index
            }
        }
        
        return quickLaunchViewModel.apps.count
    }
    
    private func emptyLauncherRow() -> some View {
        HStack(spacing: 6) {
            Spacer()
            Image(systemName: "square.dashed")
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.35))
            Text("拖拽 .app 程序到此栏极速添加")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.42))
            Spacer()
        }
        .frame(height: 52)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.015))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    Color.white.opacity(0.06),
                    style: StrokeStyle(lineWidth: 0.6, dash: [4, 4])
                )
        )
    }
}

// 独立的 App 启动项，集成高保真 Hover 上浮缩放与删除、点击 Q 弹缩放与 NSWorkspace 拉起
private struct LauncherItem: View {
    let path: String
    let viewModel: QuickLaunchViewModel
    let onReorderChanged: (CGFloat) -> Void
    let onReorderEnded: (CGFloat) -> Void
    
    @State private var isHovered = false
    @State private var isDeleteHovered = false
    @State private var isPressed = false
    @State private var isReordering = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 主应用按钮
            VStack {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
            }
            .frame(width: 38, height: 38)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(isHovered ? 0.08 : 0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(isHovered ? 0.16 : 0.08), lineWidth: 0.6)
            )
            .contentShape(Rectangle())
            .scaleEffect(isPressed ? 0.92 : (isHovered ? 1.04 : 1.0))
            .offset(y: isHovered ? -2 : 0)
            .help(viewModel.displayName(for: path))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard !isDeleteHovered else { return }
                        isPressed = true
                        
                        if abs(value.translation.width) > 5 || abs(value.translation.height) > 5 {
                            isReordering = true
                            onReorderChanged(value.location.x)
                        }
                    }
                    .onEnded { value in
                        guard !isDeleteHovered else {
                            isPressed = false
                            isReordering = false
                            return
                        }
                        
                        if isReordering {
                            onReorderEnded(value.location.x)
                        } else {
                            viewModel.launchApp(path: path)
                        }
                        
                        isPressed = false
                        isReordering = false
                    }
            )
            
            // 红色高精度悬浮删除按钮
            if isHovered {
                Button(action: {
                    viewModel.removeApp(path: path)
                }) {
                    ZStack {
                        Circle()
                            .fill(isDeleteHovered ? Color(red: 0.95, green: 0.28, blue: 0.28) : Color.black.opacity(0.65))
                            .frame(width: 14, height: 14)
                        Image(systemName: "xmark")
                            .font(.system(size: 6, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                .offset(x: 4, y: -4)
                .onHover { hovering in
                    isDeleteHovered = hovering
                }
            }
        }
        .frame(width: 38, height: 38)
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.arrow.set()
            }
        }
        .animation(.spring(response: 0.24, dampingFraction: 0.72), value: isHovered)
    }
}

// 独立的极美微型清空列表按钮（内置于卡片头部，Capsule 胶囊造型，霓虹红 Hover）
private struct MiniTrashButton: View {
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: isHovered ? "trash.fill" : "trash")
                    .font(.system(size: 9, weight: .semibold))
                Text("清空")
                    .font(.system(size: 9.5, weight: .semibold))
            }
            .foregroundStyle(isHovered ? Color(red: 0.98, green: 0.35, blue: 0.35) : Color.white.opacity(0.48))
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .background(
                Capsule()
                    .fill(isHovered ? Color(red: 0.98, green: 0.35, blue: 0.35).opacity(0.12) : Color.white.opacity(0.04))
            )
            .overlay(
                Capsule()
                    .stroke(isHovered ? Color(red: 0.98, green: 0.35, blue: 0.35).opacity(0.25) : Color.white.opacity(0.08), lineWidth: 0.6)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.arrow.set()
            }
        }
    }
}

// 呼吸灯发光播放指示器
private struct PulseDot: View {
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.8
    
    var body: some View {
        ZStack {
            Circle()
                .fill(musicAccentColor)
                .frame(width: 5, height: 5)
            
            Circle()
                .stroke(musicAccentColor, lineWidth: 1.5)
                .frame(width: 9, height: 9)
                .scaleEffect(scale)
                .opacity(opacity)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                        scale = 1.6
                        opacity = 0.0
                    }
                }
        }
        .frame(width: 10, height: 10)
    }
}

// 播放列表行的按钮热区和删除热区分开，避免点删除时误触发播放。
private struct PlaylistPreviewItem: View {
    let url: URL
    let currentIndex: Int?
    let index: Int
    let onPlay: (Int) -> Void
    let onRemove: (Int) -> Void
    
    @State private var isHovered: Bool = false
    @State private var isDeleteHovered: Bool = false
    
    private var isCurrentTrack: Bool {
        currentIndex == index
    }
    
    private func playlistTitle(for url: URL) -> String {
        url.deletingPathExtension().lastPathComponent
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button(action: {
                    onPlay(index)
                }) {
                    HStack(spacing: 6) {
                        // 动态播放指示：当前播放项显示绿色呼吸灯；其余显示精细排版序号
                        HStack(spacing: 4) {
                            if isCurrentTrack {
                                PulseDot()
                                    .frame(width: 8)
                            } else {
                                Text("\(index + 1)")
                                    .font(.system(size: 9.2, weight: .regular, design: .monospaced))
                                    .foregroundStyle(Color.white.opacity(0.30))
                                    .frame(width: 8, alignment: .center)
                            }
                        }
                        .frame(width: 14, alignment: .trailing)
                        
                        Text(playlistTitle(for: url))
                            .font(.system(size: 10.8, weight: .medium))
                            .foregroundStyle(isCurrentTrack ? musicAccentColor : Color.white.opacity(0.64))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                    .frame(height: 19, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .help("播放 \(playlistTitle(for: url))")
                .accessibilityLabel("播放 \(playlistTitle(for: url))")
                
                Button(action: {
                    onRemove(index)
                }) {
                    Image(systemName: isDeleteHovered ? "trash.fill" : "trash")
                        .font(.system(size: 9.5, weight: .regular))
                        .foregroundStyle(deleteButtonForeground)
                        .frame(width: 20, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(deleteButtonOpacity)
                .accessibilityLabel("删除曲目")
                .help("删除 \(playlistTitle(for: url))")
                .onHover { hovering in
                    isDeleteHovered = hovering
                }
                .animation(.easeOut(duration: 0.12), value: isHovered)
                .animation(.easeOut(duration: 0.12), value: isDeleteHovered)
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(isHovered ? Color.white.opacity(0.04) : (isCurrentTrack ? Color.white.opacity(0.015) : Color.clear))
            )
            .onHover { hovering in
                isHovered = hovering
                if hovering {
                    NSCursor.arrow.set()
                }
            }
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
    }
    
    private var deleteButtonOpacity: Double {
        (isHovered || isCurrentTrack || isDeleteHovered) ? 1 : 0
    }
    
    private var deleteButtonForeground: Color {
        isDeleteHovered ? Color(red: 0.96, green: 0.38, blue: 0.38).opacity(0.90) : Color.white.opacity(0.38)
    }
}

private let musicAccentColor = Color(red: 0.16, green: 0.82, blue: 0.50)

// 自绘进度条是为了在 22pt 固定高度内保持稳定热区和可拖动 knob。
private struct MusicTimelineSlider: View {
    let progress: Double
    let isEnabled: Bool
    let onScrubbingChanged: (Double) -> Void
    let onScrubbingEnded: (Double) -> Void
    
    private let trackHeight: CGFloat = 4
    private let knobSize: CGFloat = 10
    
    @State private var localDragProgress: Double? = nil
    @State private var isHovering: Bool = false
    
    private var activeProgress: Double {
        localDragProgress ?? progress
    }
    private var safeProgress: Double {
        min(max(activeProgress, 0), 1)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            let filledWidth = width * safeProgress
            // knob 需要夹在轨道范围内，否则进度为 0 或 1 时会露出容器边界。
            let knobX = min(max(filledWidth - knobSize / 2, 0), width - knobSize)
            let isDragging = localDragProgress != nil
            
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(isEnabled ? 0.12 : 0.06))
                    .frame(height: trackHeight)
                
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isEnabled ? 0.90 : 0.30),
                                Color.white.opacity(isEnabled ? 0.70 : 0.20)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: isEnabled ? max(trackHeight, filledWidth) : 0, height: trackHeight)
                
                Circle()
                    .fill(Color.white)
                    .frame(width: knobSize, height: knobSize)
                    .shadow(color: Color.black.opacity(isEnabled ? 0.35 : 0), radius: 3, y: 1)
                    .offset(x: knobX)
                    .opacity(isEnabled && (isHovering || isDragging) ? 1 : 0)
                    .animation(.easeInOut(duration: 0.15), value: isHovering || isDragging)
            }
            .frame(maxWidth: .infinity, minHeight: 22, maxHeight: 22, alignment: .center)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    NSCursor.arrow.set()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard isEnabled else { return }
                        // 拖动位置转成比例，实际 seek 秒数由 ViewModel 根据当前时长计算。
                        let nextProgress = min(max(value.location.x / width, 0), 1)
                        localDragProgress = nextProgress
                        onScrubbingChanged(nextProgress)
                    }
                    .onEnded { value in
                        guard isEnabled else { return }
                        let nextProgress = min(max(value.location.x / width, 0), 1)
                        localDragProgress = nil
                        onScrubbingEnded(nextProgress)
                    }
            )
        }
        .frame(height: 22)
        .opacity(isEnabled ? 1 : 0.62)
    }
}

// 小按钮 hover 效果统一封装，避免每个播放器按钮重复维护 hover 状态。
private struct ButtonHoverEffect: ViewModifier {
    let fill: Color
    
    @State private var isHovered: Bool = false
    init(fill: Color = Color.white.opacity(0.14)) {
        self.fill = fill
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                Circle()
                    .fill(isHovered ? fill : Color.clear)
            )
            .onHover { hovering in
                isHovered = hovering
            }
            .onTapGesture {
                isHovered = false
            }
    }
}

// 独立的极美微型添加歌曲按钮（内置于卡片头部，Capsule 胶囊造型，荧光绿/白光 Hover）
private struct MiniAddButton: View {
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 9, weight: .semibold))
                Text("添加")
                    .font(.system(size: 9.5, weight: .semibold))
            }
            .foregroundStyle(isHovered ? Color.white : Color.white.opacity(0.48))
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .background(
                Capsule()
                    .fill(isHovered ? Color.white.opacity(0.10) : Color.white.opacity(0.04))
            )
            .overlay(
                Capsule()
                    .stroke(isHovered ? Color.white.opacity(0.20) : Color.white.opacity(0.08), lineWidth: 0.6)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.arrow.set()
            }
        }
    }
}

// AppKit 拖拽回调拿到的是 NSHostingView 本地坐标；这里用透明 NSView 直接上报同一坐标系下的热区 frame。
private struct DropFrameReporter: NSViewRepresentable {
    let onFrameChange: (CGRect) -> Void

    func makeNSView(context: Context) -> ReportingView {
        let view = ReportingView()
        view.onFrameChange = onFrameChange
        return view
    }

    func updateNSView(_ nsView: ReportingView, context: Context) {
        nsView.onFrameChange = onFrameChange
        nsView.reportFrame()
    }

    final class ReportingView: NSView {
        var onFrameChange: ((CGRect) -> Void)?
        private var lastReportedFrame: CGRect = .null

        override var isFlipped: Bool {
            true
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            reportFrame()
        }

        override func setFrameSize(_ newSize: NSSize) {
            super.setFrameSize(newSize)
            reportFrame()
        }

        override func setFrameOrigin(_ newOrigin: NSPoint) {
            super.setFrameOrigin(newOrigin)
            reportFrame()
        }

        override func layout() {
            super.layout()
            reportFrame()
        }

        func reportFrame() {
            guard let contentView = window?.contentView else { return }
            let frameInContentView = convert(bounds, to: contentView)
            let topLeftFrame = CGRect(
                x: frameInContentView.minX,
                y: contentView.bounds.height - frameInContentView.maxY,
                width: frameInContentView.width,
                height: frameInContentView.height
            )
            guard topLeftFrame != lastReportedFrame else { return }
            lastReportedFrame = topLeftFrame
            DispatchQueue.main.async { [weak self] in
                self?.onFrameChange?(topLeftFrame)
            }
        }
    }
}
