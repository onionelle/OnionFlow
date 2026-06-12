import SwiftUI

struct NeteaseDiscoveryView: View {
    @ObservedObject var musicViewModel: MusicPlayerViewModel
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedUserPlaylistName: String? = nil
    @State private var hoveredChartId: String? = nil
    @State private var showPlaylistMenu = false
    @State private var hoveredPlaylistId: String? = nil
    
    @AppStorage("backgroundNebulaEnabled") private var backgroundNebulaEnabled = false
    @AppStorage("backgroundParticlesEnabled") private var backgroundParticlesEnabled = false
    @AppStorage("backgroundNebulaTheme") private var backgroundNebulaThemeRawValue = "charcoal"
    @AppStorage("autoDownloadOnPlay") private var autoDownloadOnPlay = false
    
    @State private var isSearchVisible = false
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    
    struct ChartInfo: Identifiable, Hashable {
        let id: String
        let name: String
        let shortName: String
    }
    
    private let charts = [
        ChartInfo(id: "3778678", name: "云音乐热歌榜", shortName: "热歌"),
        ChartInfo(id: "3779629", name: "云音乐新歌榜", shortName: "新歌"),
        ChartInfo(id: "19723756", name: "云音乐飙升榜", shortName: "飙升"),
        ChartInfo(id: "2884035", name: "网易原创榜", shortName: "原创")
    ]
    
    // Grid layout for 3 columns
    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                // Netease Banner / Selector for top charts
                HStack(spacing: 6) {
                    ForEach(charts) { chart in
                        Button {
                            if musicViewModel.selectedChartId != chart.id {
                                musicViewModel.selectedChartId = chart.id
                                loadSongs(for: chart.id)
                            }
                        } label: {
                            Text(chart.shortName)
                                .font(.system(size: 9.5, weight: .regular))
                                .foregroundStyle(
                                    musicViewModel.selectedChartId == chart.id 
                                    ? musicAccentColor 
                                    : (hoveredChartId == chart.id ? musicAccentColor.opacity(0.8) : .white.opacity(0.48))
                                )
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1.5)
                                .background(
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(
                                            musicViewModel.selectedChartId == chart.id 
                                            ? musicAccentColor.opacity(0.12) 
                                            : (hoveredChartId == chart.id ? Color.white.opacity(0.08) : Color.white.opacity(0.04))
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            hoveredChartId = hovering ? chart.id : nil
                            if hovering {
                                NSCursor.arrow.set()
                            }
                        }
                    }
                    
                    // 相似 (相似推荐)
                    Button {
                        if musicViewModel.selectedChartId != "simi" {
                            musicViewModel.selectedChartId = "simi"
                            loadSongs(for: "simi")
                        }
                    } label: {
                        Text("相似")
                            .font(.system(size: 9.5, weight: .regular))
                            .foregroundStyle(
                                musicViewModel.selectedChartId == "simi" 
                                ? musicAccentColor 
                                : (hoveredChartId == "simi" ? musicAccentColor.opacity(0.8) : .white.opacity(0.48))
                            )
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(
                                        musicViewModel.selectedChartId == "simi" 
                                        ? musicAccentColor.opacity(0.12) 
                                        : (hoveredChartId == "simi" ? Color.white.opacity(0.08) : Color.white.opacity(0.04))
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        hoveredChartId = hovering ? "simi" : nil
                        if hovering {
                            NSCursor.arrow.set()
                        }
                    }
                    
                    // 我的歌单 Button
                    if UserDefaults.standard.string(forKey: "NeteaseCookie")?.isEmpty == false {
                        if !musicViewModel.userPlaylists.isEmpty {
                            let isUserPlaylist = !charts.contains(where: { $0.id == musicViewModel.selectedChartId }) && musicViewModel.selectedChartId != "simi" && musicViewModel.selectedChartId != "search"
                            Button {
                                showPlaylistMenu = true
                            } label: {
                                HStack(spacing: 2) {
                                    Text(isUserPlaylist ? (selectedUserPlaylistName ?? "我的网易云歌单") : "我的网易云歌单")
                                        .font(.system(size: 9.5, weight: .regular))
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .frame(maxWidth: 90)
                                        .foregroundStyle(
                                            isUserPlaylist 
                                            ? musicAccentColor 
                                            : (hoveredChartId == "menu" ? musicAccentColor.opacity(0.8) : .white.opacity(0.48))
                                        )
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 6.5))
                                        .foregroundStyle(
                                            isUserPlaylist 
                                            ? musicAccentColor 
                                            : (hoveredChartId == "menu" ? musicAccentColor.opacity(0.8) : .white.opacity(0.48))
                                        )
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1.5)
                                .background(
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(
                                            isUserPlaylist 
                                            ? musicAccentColor.opacity(0.12) 
                                            : (hoveredChartId == "menu" ? Color.white.opacity(0.08) : Color.white.opacity(0.04))
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .onHover { hovering in
                                hoveredChartId = hovering ? "menu" : nil
                                if hovering {
                                    NSCursor.arrow.set()
                                }
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // 边听边存
                    Button {
                        autoDownloadOnPlay.toggle()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: autoDownloadOnPlay ? "square.and.arrow.down.fill" : "square.and.arrow.down")
                                .font(.system(size: 8.5))
                            Text("边听边存")
                                .font(.system(size: 9.5, weight: .regular))
                        }
                        .foregroundStyle(
                            autoDownloadOnPlay 
                            ? musicAccentColor 
                            : (hoveredChartId == "autoDownload" ? musicAccentColor.opacity(0.8) : .white.opacity(0.48))
                        )
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(
                                    autoDownloadOnPlay 
                                    ? musicAccentColor.opacity(0.12) 
                                    : (hoveredChartId == "autoDownload" ? Color.white.opacity(0.08) : Color.white.opacity(0.04))
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        hoveredChartId = hovering ? "autoDownload" : nil
                        if hovering {
                            NSCursor.arrow.set()
                        }
                    }
                    .padding(.trailing, 4)
                    
                    // 搜索 Toggle
                    Button(action: {
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
                    }) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 9))
                            .foregroundColor(isSearchVisible || hoveredChartId == "searchToggle" ? musicAccentColor : .white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        hoveredChartId = hovering ? "searchToggle" : nil
                        if hovering {
                            NSCursor.arrow.set()
                        }
                    }
                    .padding(.trailing, 4)
                    
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.35)
                            .frame(width: 12, height: 12)
                    } else {
                        Button(action: { loadSongs(for: musicViewModel.selectedChartId, forceRefresh: true) }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 9))
                                .foregroundColor(hoveredChartId == "refresh" ? musicAccentColor : .white.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            hoveredChartId = hovering ? "refresh" : nil
                            if hovering {
                                NSCursor.arrow.set()
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
                
                if isSearchVisible {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.4))
                        ZStack(alignment: .leading) {
                            if searchText.isEmpty {
                                Text("搜索网易云音乐...")
                                    .font(.system(size: 9.8, weight: .regular))
                                    .foregroundColor(.white.opacity(0.35))
                            }
                            TextField("", text: $searchText)
                                .textFieldStyle(.plain)
                                .font(.system(size: 9.8, weight: .regular))
                                .foregroundColor(.white.opacity(0.85))
                                .focused($isSearchFocused)
                                .onSubmit {
                                    if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        musicViewModel.selectedChartId = "search"
                                        loadSongs(for: "search")
                                    } else {
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
                
                if UserDefaults.standard.string(forKey: "NeteaseCookie") == nil || UserDefaults.standard.string(forKey: "NeteaseCookie")?.isEmpty == true {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 8.2))
                        Text("当前未配置网易云 Cookie，如需无损音质及私人歌单，请在设置中配置。")
                            .font(.system(size: 8.2))
                    }
                    .foregroundColor(.white.opacity(0.32))
                    .padding(.horizontal, 10)
                    .padding(.top, 4)
                    .padding(.bottom, 2)
                }
                
                if errorMessage != nil || musicViewModel.onlinePlaylist.isEmpty {
                    statusPlaceholderView
                } else {
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 0.5) {
                                ForEach(Array(musicViewModel.onlinePlaylist.enumerated()), id: \.offset) { index, song in
                                    NeteaseOnlinePreviewItem(index: index, song: song, musicViewModel: musicViewModel)
                                        .id(index)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .onChange(of: musicViewModel.onlinePlaylist) { _, newPlaylist in
                            scrollToActiveSong(in: newPlaylist, proxy: proxy)
                        }
                        .onChange(of: musicViewModel.currentOnlineIndex) { _, _ in
                            scrollToActiveSong(in: musicViewModel.onlinePlaylist, proxy: proxy)
                        }
                        .onAppear {
                            scrollToActiveSong(in: musicViewModel.onlinePlaylist, proxy: proxy)
                        }
                    }
                }
            }
            .onAppear {
                musicViewModel.loadUserPlaylistsIfNeeded()
                if musicViewModel.onlinePlaylist.isEmpty {
                    loadSongs(for: musicViewModel.selectedChartId)
                }
                // Restore selected user playlist name
                if !charts.contains(where: { $0.id == musicViewModel.selectedChartId }) && musicViewModel.selectedChartId != "simi" && musicViewModel.selectedChartId != "search" {
                    if let playlist = musicViewModel.userPlaylists.first(where: { String($0.id) == musicViewModel.selectedChartId }) {
                        selectedUserPlaylistName = playlist.name
                    }
                }
            }
            .onChange(of: musicViewModel.userPlaylists) { _, playlists in
                if !charts.contains(where: { $0.id == musicViewModel.selectedChartId }) && musicViewModel.selectedChartId != "simi" && musicViewModel.selectedChartId != "search" {
                    if let playlist = playlists.first(where: { String($0.id) == musicViewModel.selectedChartId }) {
                        selectedUserPlaylistName = playlist.name
                    }
                }
            }
            
            if showPlaylistMenu {
                Color.white.opacity(0.0001)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showPlaylistMenu = false
                    }
                
                dropdownView
                    .offset(x: 160, y: 34)
            }
        }
    }
    
    private var dropdownView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(musicViewModel.userPlaylists) { playlist in
                    Button {
                        musicViewModel.selectedChartId = String(playlist.id)
                        selectedUserPlaylistName = playlist.name
                    loadSongs(for: String(playlist.id))
                        showPlaylistMenu = false
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 9))
                                .foregroundStyle(musicViewModel.selectedChartId == String(playlist.id) ? musicAccentColor : Color.white.opacity(0.48))
                            
                            Text(playlist.name)
                                .font(.system(size: 9.8, weight: .regular))
                                .foregroundStyle(musicViewModel.selectedChartId == String(playlist.id) ? musicAccentColor : Color.white.opacity(0.72))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .padding(.horizontal, 6)
                        .frame(height: 19)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(hoveredPlaylistId == String(playlist.id) ? Color.white.opacity(0.06) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        hoveredPlaylistId = hovering ? String(playlist.id) : nil
                        if hovering {
                            NSCursor.arrow.set()
                        }
                    }
                }
            }
            .padding(4)
        }
        .scrollContentBackground(.hidden)
        .frame(width: 150, height: min(180, CGFloat(musicViewModel.userPlaylists.count * 20 + 8)))
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.45))
        )
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.001))
                .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }
    
    private func loadSongs(for playlistId: String, forceRefresh: Bool = false) {
        guard !isLoading else { return }
        if forceRefresh {
            musicViewModel.resetOnlineFailureState()
        }
        if !forceRefresh, playlistId != "search", playlistId != "simi",
           let cachedSongs = musicViewModel.cachedOnlinePlaylist(for: playlistId) {
            errorMessage = nil
            musicViewModel.setOnlinePlaylist(cachedSongs)
            return
        }
        
        isLoading = true
        errorMessage = nil
        Task {
            do {
                if playlistId == "search" {
                    guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        await MainActor.run {
                            self.isLoading = false
                        }
                        return
                    }
                    let response = try await NeteaseAPIClient.shared.searchSongs(query: searchText)
                    await MainActor.run {
                        musicViewModel.setOnlinePlaylist(response)
                        self.isLoading = false
                    }
                } else if playlistId == "simi" {
                    guard musicViewModel.playlistMode == .online,
                          let activeIndex = musicViewModel.currentOnlineIndex,
                          musicViewModel.activeOnlinePlaylist.indices.contains(activeIndex) else {
                        await MainActor.run {
                            self.errorMessage = "请先播放一首在线歌曲以获取相似推荐"
                            self.isLoading = false
                        }
                        return
                    }
                    let activeSong = musicViewModel.activeOnlinePlaylist[activeIndex]
                    let simiRes = try await NeteaseAPIClient.shared.fetchSimiSongs(songId: String(activeSong.id))
                    guard let simiSongs = simiRes.songs else {
                        throw NSError(domain: "Netease", code: -1, userInfo: [NSLocalizedDescriptionKey: "未获取到相似歌曲"])
                    }
                    let tracks = simiSongs.map { $0.toNeteaseSong() }
                    await MainActor.run {
                        musicViewModel.setOnlinePlaylist(tracks)
                        self.isLoading = false
                    }
                } else {
                    let response = try await NeteaseAPIClient.shared.fetchPlaylistDetail(id: playlistId)
                    guard let tracks = response.playlist?.tracks else {
                        let code = response.code
                        throw NSError(domain: "Netease", code: code, userInfo: [NSLocalizedDescriptionKey: "歌单无数据 (状态码: \(code))"])
                    }
                    
                    await MainActor.run {
                        musicViewModel.setOnlinePlaylist(tracks, cacheKey: playlistId)
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    if let cachedSongs = musicViewModel.cachedOnlinePlaylist(for: playlistId) {
                        musicViewModel.setOnlinePlaylist(cachedSongs)
                        self.errorMessage = nil
                    } else if playlistId == "simi" {
                        self.errorMessage = "获取相似歌曲失败: \(error.localizedDescription)"
                    } else {
                        if UserDefaults.standard.string(forKey: "NeteaseCookie")?.isEmpty != false {
                            self.errorMessage = "加载失败 (请配置 Cookie): \(error.localizedDescription)"
                        } else {
                            self.errorMessage = "加载失败: \(error.localizedDescription)"
                        }
                    }
                    self.isLoading = false
                }
            }
        }
    }
    
    private func scrollToActiveSong(in playlist: [NeteaseSong], proxy: ScrollViewProxy) {
        guard musicViewModel.playlistMode == .online,
              let activeIndex = musicViewModel.currentOnlineIndex,
              musicViewModel.activeOnlinePlaylist.indices.contains(activeIndex) else {
            return
        }
        let activeSong = musicViewModel.activeOnlinePlaylist[activeIndex]
        if let matchIndex = playlist.firstIndex(where: { $0.id == activeSong.id }) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                proxy.scrollTo(matchIndex, anchor: .center)
            }
        }
    }
    
    private var statusPlaceholderView: some View {
        VStack(spacing: 6) {
            Spacer()
            if let error = errorMessage {
                if error == "请先播放一首在线歌曲以获取相似推荐" {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(musicAccentColor.opacity(0.68))
                    VStack(spacing: 2) {
                        Text("获取相似推荐")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.68))
                        Text("请先播放一首在线歌曲")
                            .font(.system(size: 9.5, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.38))
                    }
                } else {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Color.orange.opacity(0.68))
                    VStack(spacing: 2) {
                        Text("加载失败")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.68))
                        Text(error)
                            .font(.system(size: 9.5, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.38))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                }
            } else if musicViewModel.onlinePlaylist.isEmpty {
                if musicViewModel.selectedChartId == "search" {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.42))
                    VStack(spacing: 2) {
                        Text("未找到歌曲")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.68))
                        Text("请尝试更换搜索词重新输入")
                            .font(.system(size: 9.5, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.38))
                    }
                } else {
                    Image(systemName: "music.note.house")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.42))
                    VStack(spacing: 2) {
                        Text("暂无歌曲")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.68))
                        Text("请选择其他榜单或播放歌曲")
                            .font(.system(size: 9.5, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.38))
                    }
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

struct NeteaseOnlinePreviewItem: View {
    let index: Int
    let song: NeteaseSong
    @ObservedObject var musicViewModel: MusicPlayerViewModel
    @ObservedObject private var downloadManager = OnlineDownloadManager.shared
    
    @State private var isHovered = false
    @State private var isDownloadHovered = false
    
    private var isCurrentTrack: Bool {
        guard musicViewModel.playlistMode == .online,
              let activeIndex = musicViewModel.currentOnlineIndex,
              musicViewModel.activeOnlinePlaylist.indices.contains(activeIndex) else {
            return false
        }
        return musicViewModel.activeOnlinePlaylist[activeIndex].id == song.id
    }
    
    private var isFailed: Bool {
        musicViewModel.failedOnlineSongIDs.contains(song.id)
    }

    private var failureType: String? {
        guard isFailed else { return nil }
        let msg = musicViewModel.onlineSongFailureMessages[song.id] ?? ""
        if msg.contains("超时") {
            return "timeout"
        } else if msg.contains("版权") || msg.contains("VIP") {
            return "copyright"
        } else {
            return "other"
        }
    }

    private var failureColor: Color {
        guard let type = failureType else { return Color.red }
        switch type {
        case "timeout":
            return Color(red: 0.98, green: 0.60, blue: 0.18) // Amber/Orange
        case "copyright":
            return Color(red: 0.98, green: 0.28, blue: 0.28) // Coral Red
        default:
            return Color(red: 0.98, green: 0.28, blue: 0.28) // Coral Red
        }
    }

    private var failureLabel: String {
        guard let type = failureType else { return "" }
        switch type {
        case "timeout":
            return " [超时]"
        case "copyright":
            return " [VIP/版权]"
        default:
            return " [失败]"
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            Button {
                musicViewModel.playOnlineSong(at: index)
            } label: {
                HStack(alignment: .center, spacing: 6) {
                    Group {
                        if isCurrentTrack {
                            PulseDot()
                                .frame(width: 8)
                        } else {
                            Text("\(index + 1)")
                                .font(.system(size: 9.2, weight: .regular, design: .monospaced))
                                .italic()
                                .foregroundStyle(isFailed ? failureColor.opacity(0.48) : Color.white.opacity(0.30))
                        }
                    }
                    .frame(width: 20, alignment: .trailing)

                    Text(song.name)
                        .font(.system(size: 9.8, weight: .regular))
                        .foregroundStyle(isFailed ? failureColor.opacity(0.68) : (isCurrentTrack ? musicAccentColor : Color.white.opacity(0.64)))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    Text("- " + song.artistName)
                        .font(.system(size: 9.8, weight: .regular))
                        .foregroundStyle(isFailed ? failureColor.opacity(0.35) : Color.white.opacity(0.30))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if isFailed {
                        Text(failureLabel)
                            .font(.system(size: 8.5, weight: .semibold))
                            .foregroundStyle(failureColor.opacity(0.75))
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
                .frame(maxWidth: .infinity)
                .offset(y: 1.0)
            }
            .buttonStyle(.plain)
            .frame(height: 17)
            .accessibilityLabel(isFailed ? "播放失败: \(musicViewModel.onlineSongFailureMessages[song.id] ?? "未知原因")" : "播放 \(song.name)")

            Button {
                Task {
                    do {
                        downloadManager.downloadErrors.removeValue(forKey: song.id)
                        musicViewModel.clearOnlineSongFailure(id: song.id)
                        try await downloadManager.download(song: song)
                    } catch {
                        print("Download error: \(error)")
                        let errorMsg = error.localizedDescription
                        downloadManager.downloadErrors[song.id] = errorMsg
                        // Sync failure to musicViewModel
                        musicViewModel.markOnlineSongFailed(id: song.id, message: errorMsg)
                    }
                }
            } label: {
                if downloadManager.isDownloaded(song: song) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(musicAccentColor)
                } else if downloadManager.downloadingSongIDs.contains(song.id) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 2)
                            .frame(width: 14, height: 14)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(downloadManager.downloadProgresses[song.id] ?? 0.0))
                            .stroke(musicAccentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                            .frame(width: 14, height: 14)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.1), value: downloadManager.downloadProgresses[song.id])
                    }
                } else if let errorMsg = downloadManager.downloadErrors[song.id] {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.red)
                        .help(errorMsg)
                } else if isFailed {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.red)
                } else {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(downloadButtonForeground)
                }
            }
            .buttonStyle(.plain)
            .disabled(downloadManager.downloadingSongIDs.contains(song.id) || downloadManager.isDownloaded(song: song) || isFailed)
            .help(downloadManager.isDownloaded(song: song) ? "已下载" : "")
            .frame(width: 20, height: 17)
            .opacity(downloadButtonOpacity)
            .onHover { hovering in
                isDownloadHovered = hovering
            }
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, minHeight: 17, alignment: .center)
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
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
    }
    
    private var downloadButtonOpacity: Double {
        (isHovered || isCurrentTrack || isDownloadHovered || downloadManager.isDownloaded(song: song) || downloadManager.downloadErrors[song.id] != nil || isFailed) ? 1 : 0
    }

    private var downloadButtonForeground: Color {
        isDownloadHovered ? Color.white.opacity(0.8) : Color.white.opacity(0.38)
    }
}
