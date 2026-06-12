import SwiftUI

/// 播放列表与歌词共用同一张卡片，保持切换时高度、边框和投放热区稳定。
struct MusicPlaylistPanelView: View {
    @ObservedObject var musicViewModel: MusicPlayerViewModel
    @Binding var selectedTab: MusicExpandedView.ExpandedTab
    let previewHeight: CGFloat

    @State private var isPlaylistHovered = false
    @State private var isOnlineHovered = false
    @State private var isLyricsHovered = false
    @State private var isSearchVisible = false
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            switch selectedTab {
            case .local:
                playlistPreview
            case .online:
                NeteaseDiscoveryView(musicViewModel: musicViewModel)
                    .frame(height: previewHeight)
            case .lyrics:
                MusicLyricsView(
                    lyricsViewModel: musicViewModel.lyricsViewModel,
                    onRetry: musicViewModel.retryLyrics,
                    onChooseLocalLyrics: {
                        Task {
                            await musicViewModel.chooseLocalLyricsFile()
                        }
                    },
                    onRematch: musicViewModel.rematchLyrics,
                    onSelectCandidate: musicViewModel.selectLyricsCandidate,
                    onCancelSelection: musicViewModel.cancelLyricsSelection
                )
                .frame(height: previewHeight)
            }
        }
        .background(containerBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(containerBorder)
        .overlay(dropTargetOverlay)
        // 投放协调器依赖渲染后的真实卡片位置，不能按固定高度推算命中区域。
        .overlay(
            DropFrameReporter { frame in
                musicViewModel.dropFrame = frame
            }
        )
    }

    private var headerBar: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = .local
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 10))
                                .foregroundStyle(isPlaylistHovered ? musicAccentColor : (selectedTab == .local ? musicAccentColor : .white.opacity(0.48)))
                            Text("本地曲库")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(isPlaylistHovered ? musicAccentColor : (selectedTab == .local ? musicAccentColor : .white.opacity(0.48)))

                            if !musicViewModel.playlist.isEmpty {
                                Text("\(musicViewModel.playlist.count)")
                                    .font(.system(size: 8.5, weight: .regular, design: .monospaced))
                                    .foregroundStyle(selectedTab == .local ? musicAccentColor : .white.opacity(0.4))
                                    .padding(.horizontal, 4.5)
                                    .padding(.vertical, 0.5)
                                    .background(selectedTab == .local ? musicAccentColor.opacity(0.12) : Color.white.opacity(0.05))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        isPlaylistHovered = hovering
                        if hovering {
                            NSCursor.arrow.set()
                        }
                    }
                    
                    // 线上发现 Tab
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = .online
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "globe")
                                .font(.system(size: 10))
                                .foregroundStyle(isOnlineHovered ? musicAccentColor : (selectedTab == .online ? musicAccentColor : .white.opacity(0.48)))
                            Text("线上发现")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(isOnlineHovered ? musicAccentColor : (selectedTab == .online ? musicAccentColor : .white.opacity(0.48)))
                        }
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        isOnlineHovered = hovering
                        if hovering {
                            NSCursor.arrow.set()
                        }
                    }

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = .lyrics
                        }
                        musicViewModel.showLyrics()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "quote.bubble")
                                .font(.system(size: 10))
                                .foregroundStyle(isLyricsHovered ? musicAccentColor : (selectedTab == .lyrics ? musicAccentColor : .white.opacity(0.48)))
                            Text("歌词")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(isLyricsHovered ? musicAccentColor : (selectedTab == .lyrics ? musicAccentColor : .white.opacity(0.48)))
                        }
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        isLyricsHovered = hovering
                        if hovering {
                            NSCursor.arrow.set()
                        }
                    }
                }

                Spacer()

                if selectedTab == .local {
                    HStack(spacing: 0) {
                        MusicMiniAddButton {
                            Task {
                                await musicViewModel.addFilesOrDirectoriesToPlaylist()
                            }
                        }

                        if !musicViewModel.playlist.isEmpty {
                            MusicMiniSearchButton(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isSearchVisible.toggle()
                                    if !isSearchVisible {
                                        searchText = ""
                                    }
                                }
                                if isSearchVisible {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        isSearchFocused = true
                                    }
                                }
                            }, isActive: isSearchVisible)
                            .keyboardShortcut("f", modifiers: .command)

                            MusicMiniTrashButton {
                                musicViewModel.clearPlaylistAndPlayback()
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(Color.white.opacity(0.025))

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 0.6)
        }
    }

    private var playlistPreview: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    if isSearchVisible {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 10, weight: .regular))
                                .foregroundStyle(Color.white.opacity(0.4))
                            ZStack(alignment: .leading) {
                                if searchText.isEmpty {
                                    Text("模糊搜索...")
                                        .font(.system(size: 9.8, weight: .regular))
                                        .foregroundColor(.white.opacity(0.35))
                                }
                                TextField("", text: $searchText)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 9.8, weight: .regular))
                                    .foregroundColor(.white.opacity(0.85))
                                    .focused($isSearchFocused)
                                    .onSubmit {
                                        if searchText.isEmpty {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                isSearchVisible = false
                                            }
                                        }
                                    }
                            }
                            if !searchText.isEmpty {
                                Button {
                                    searchText = ""
                                    isSearchFocused = true
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color.white.opacity(0.4))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4.5)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .padding(.horizontal, 10)
                        .padding(.top, 6)
                        .padding(.bottom, 2)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    ScrollView(showsIndicators: false) {
                        if musicViewModel.playlist.isEmpty {
                            emptyPlaylistRow
                                .frame(width: geometry.size.width)
                        } else {
                            let filteredIndices = musicViewModel.playlist.indices.filter { index in
                                if searchText.isEmpty { return true }
                                let title = musicViewModel.playlist[index].deletingPathExtension().lastPathComponent
                                return fuzzyMatch(pattern: searchText, str: title)
                            }

                            VStack(alignment: .leading, spacing: 0.5) {
                                ForEach(filteredIndices, id: \.self) { index in
                                    MusicPlaylistPreviewItem(
                                        url: musicViewModel.playlist[index],
                                        currentIndex: musicViewModel.currentIndex,
                                        index: index,
                                        isFailed: musicViewModel.failedLocalURLs.contains(musicViewModel.playlist[index]),
                                        onPlay: { selectedIndex in
                                            musicViewModel.playTrack(at: selectedIndex)
                                        },
                                        onRemove: { removedIndex in
                                            musicViewModel.removeTrack(at: removedIndex)
                                        }
                                    )
                                    .frame(width: geometry.size.width)
                                    .id(index)
                                }
                            }
                            .padding(.vertical, 2)
                            .frame(width: geometry.size.width, alignment: .leading)
                        }
                    }
                }
                .onChange(of: musicViewModel.currentIndex) { _, newIndex in
                    if let newIndex = newIndex, newIndex >= 0 {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
                .onAppear {
                    if let currentIndex = musicViewModel.currentIndex, currentIndex >= 0 {
                        proxy.scrollTo(currentIndex, anchor: .center)
                    }
                }
            }
        }
        .frame(height: previewHeight)
    }

    private var containerBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.white.opacity(musicViewModel.playlist.isEmpty ? 0.01 : 0.024))
    }

    private var containerBorder: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(Color.white.opacity(musicViewModel.playlist.isEmpty ? 0.06 : 0.08), lineWidth: 0.5)
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

    private var emptyPlaylistRow: some View {
        VStack(spacing: 6) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.42))
            VStack(spacing: 2) {
                Text("拖拽歌曲或文件夹到此区域")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.68))
                Text("也可以点击右上方添加歌曲")
                    .font(.system(size: 9.5, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.38))
            }
        }
        .frame(maxWidth: .infinity, minHeight: previewHeight)
    }

    private func fuzzyMatch(pattern: String, str: String) -> Bool {
        let p = pattern.lowercased()
        let s = str.lowercased()
        var pIdx = p.startIndex
        var sIdx = s.startIndex
        while pIdx < p.endIndex && sIdx < s.endIndex {
            if p[pIdx] == s[sIdx] {
                pIdx = p.index(after: pIdx)
            }
            sIdx = s.index(after: sIdx)
        }
        return pIdx == p.endIndex
    }
}
