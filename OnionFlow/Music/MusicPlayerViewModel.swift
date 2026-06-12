import Combine
import CoreGraphics
import Foundation

// 音乐功能的状态入口：管理播放列表语义，底层 AVPlayer 细节留在 MusicPlayerController。
@MainActor
final class MusicPlayerViewModel: ObservableObject {
    enum PlaylistMode {
        case local
        case online
    }

    @Published var playlistMode: PlaylistMode = .local
    @Published private(set) var state: MusicPlayerState = .idle
    @Published private(set) var currentTrack: MusicTrack?
    @Published private(set) var currentTime: TimeInterval = 0

    // Local Playlist State
    @Published private(set) var playlist: [URL] = []
    @Published private(set) var currentIndex: Int?
    @Published var failedLocalURLs: Set<URL> = []
    private var consecutiveFailures = 0

    // Online Playlist State
    @Published var onlinePlaylist: [NeteaseSong] = []
    @Published private(set) var activeOnlinePlaylist: [NeteaseSong] = []
    @Published private(set) var currentOnlineIndex: Int?
    @Published var failedOnlineSongIDs: Set<Int> = []
    @Published var onlineSongFailureMessages: [Int: String] = [:]
    @Published var selectedChartId: String = "3778678"
    @Published var userPlaylists: [NeteaseUserPlaylist] = []
    @Published var currentUserId: String? = nil
    @Published var currentUserNickname: String? = nil
    private var lastLoadedCookie: String? = nil
    private var cachedOnlinePlaylists: [String: [NeteaseSong]] = [:]

    @Published private(set) var playbackMode: MusicPlaybackMode = .shuffle
    @Published private(set) var isMuted: Bool = false
    @Published var volume: Double = 1.0 {
        didSet {
            playerController.volume = Float(volume)
            // 联动静音逻辑：当调大音量且处于静音状态时，自动解除静音
            if volume > 0 && isMuted {
                toggleMute()
            }
        }
    }
    @Published private(set) var isDropTargeted: Bool = false
    @Published var dropFrame: CGRect = .zero
    @Published var scrubbingTime: TimeInterval? = nil
    let lyricsViewModel = LyricsViewModel()
    private let filePicker: MusicFilePicker
    private let playerController: MusicPlayerController
    private let directoryScanner: MusicDirectoryScanner
    private let playlistStore: MusicPlaylistStore
    private let onlineMusicService: OnlineMusicService
    private var currentTrackProgress: TimeInterval = 0
    var onWillOpenFilePicker: (() -> Void)?
    var onDidCloseFilePicker: (() -> Void)?
    private var loadTask: Task<Void, Never>?
    private var loadGeneration = 0
    private var autoSkipTask: Task<Void, Never>?
    private var playbackStartWatchdogTask: Task<Void, Never>?
    convenience init(restoresPlaylistOnInit: Bool = true) {
        self.init(
            filePicker: MusicFilePicker(),
            playerController: MusicPlayerController(),
            directoryScanner: MusicDirectoryScanner(),
            playlistStore: MusicPlaylistStore(),
            onlineMusicService: OnlineMusicService(),
            restoresPlaylistOnInit: restoresPlaylistOnInit
        )
    }
    init(
        filePicker: MusicFilePicker,
        playerController: MusicPlayerController,
        directoryScanner: MusicDirectoryScanner,
        playlistStore: MusicPlaylistStore,
        onlineMusicService: OnlineMusicService = OnlineMusicService(),
        restoresPlaylistOnInit: Bool = true
    ) {
        self.filePicker = filePicker
        self.playerController = playerController
        self.directoryScanner = directoryScanner
        self.playlistStore = playlistStore
        self.onlineMusicService = onlineMusicService
        self.playerController.onProgressChange = { [weak self] seconds in
            self?.currentTime = seconds
            self?.lyricsViewModel.updateTime(seconds)
        }
        self.playerController.onPlaybackEnded = { [weak self] in
            self?.handlePlaybackEnded()
        }
        self.playerController.onPlaybackStarted = { [weak self] in
            self?.handlePlaybackStarted()
        }
        self.playerController.onPlaybackFailure = { [weak self] message in
            self?.handlePlaybackFailure(message: message)
        }
        self.playerController.onPlaybackStalled = { [weak self] in
            self?.handlePlaybackStalled()
        }
        self.playerController.onIsMutedChange = { [weak self] muted in
            self?.isMuted = muted
        }
        if restoresPlaylistOnInit {
            restorePlaylist()
        }
    }
    var hasTrack: Bool {
        currentTrack != nil
    }
    var hasPlaylist: Bool {
        switch playlistMode {
        case .local:
            guard let currentIndex else { return false }
            return playlist.indices.contains(currentIndex)
        case .online:
            guard let currentOnlineIndex else { return false }
            return activeOnlinePlaylist.indices.contains(currentOnlineIndex)
        }
    }
    var canPlayPrevious: Bool {
        guard hasPlaylist else { return false }
        if playbackMode == .loop {
            return playlistMode == .local ? (playlist.count > 0) : (activeOnlinePlaylist.count > 0)
        }
        if playlistMode == .local {
            guard let currentIndex else { return false }
            return currentIndex > 0
        } else {
            guard let currentOnlineIndex else { return false }
            return currentOnlineIndex > 0
        }
    }
    var canPlayNext: Bool {
        guard hasPlaylist else { return false }
        if playbackMode == .loop {
            return playlistMode == .local ? (playlist.count > 0) : (activeOnlinePlaylist.count > 0)
        }
        if playbackMode == .shuffle {
            return playlistMode == .local ? (playlist.count > 1) : (activeOnlinePlaylist.count > 1)
        }
        if playlistMode == .local {
            guard let currentIndex else { return false }
            return currentIndex < playlist.count - 1
        } else {
            guard let currentOnlineIndex else { return false }
            return currentOnlineIndex < activeOnlinePlaylist.count - 1
        }
    }
    var duration: TimeInterval {
        currentTrack?.duration ?? 0
    }
    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(currentTime / duration, 0), 1)
    }
    var titleText: String {
        if let currentTrack {
            return currentTrack.title
        }
        if playlistMode == .local {
            if let currentIndex, playlist.indices.contains(currentIndex) {
                return playlist[currentIndex].deletingPathExtension().lastPathComponent
            }
        } else {
            if let currentOnlineIndex, activeOnlinePlaylist.indices.contains(currentOnlineIndex) {
                return activeOnlinePlaylist[currentOnlineIndex].name
            }
        }
        return "未播放"
    }
    var stateText: String {
        switch state {
        case .playing:
            return "播放中"
        case .paused:
            return "已暂停"
        case .loading:
            return "加载中..."
        case .idle:
            return ""
        case .failed:
            return "加载失败"
        }
    }
    var playbackModeSystemName: String {
        switch playbackMode {
        case .singleLoop:
            return "repeat.1"
        case .loop:
            return "repeat"
        case .shuffle:
            return "shuffle"
        }
    }
    var playbackModeText: String {
        switch playbackMode {
        case .singleLoop:
            return "单曲循环"
        case .loop:
            return "列表循环"
        case .shuffle:
            return "随机播放"
        }
    }
    var playPauseSystemName: String {
        state == .playing ? "pause.fill" : "play.fill"
    }
    var currentTimeText: String {
        formatTime(scrubbingTime ?? currentTime)
    }
    var durationText: String {
        formatTime(duration)
    }
    var hasPlaybackError: Bool {
        if case .failed = state { return true }; return false
    }
    var errorText: String? {
        if case .failed(let message) = state {
            return message
        }
        return nil
    }
    func toggleMute() {
        playerController.isMuted = !isMuted
    }
    func setDropTargeted(_ isTargeted: Bool) {
        isDropTargeted = isTargeted
    }

    func canAcceptPlaylistDrop(from urls: [URL]) -> Bool {
        urls.contains(where: canImportToPlaylist)
    }

    func canAcceptAllPlaylistDrop(from urls: [URL]) -> Bool {
        !urls.isEmpty && urls.allSatisfy(canImportToPlaylist)
    }

    func addFilesOrDirectoriesToPlaylist() async {
        // 文件选择器自身会提升到 island 上方；回调用于关闭后恢复 island 层级。
        onWillOpenFilePicker?()
        let urls = await filePicker.pickAudioFilesAndDirectories()
        onDidCloseFilePicker?()
        guard !urls.isEmpty else { return }
        addFilesOrDirectoriesToPlaylist(from: urls)
    }
    func showLyrics() {
        lyricsViewModel.loadLyrics(for: currentTrack)
    }
    func retryLyrics() {
        lyricsViewModel.retry(for: currentTrack)
    }
    func rematchLyrics() {
        lyricsViewModel.rematch(for: currentTrack)
    }
    func selectLyricsCandidate(_ candidate: OnlineLyricsCandidate) {
        lyricsViewModel.select(candidate, for: currentTrack)
    }
    func cancelLyricsSelection() {
        lyricsViewModel.cancelCandidateSelection()
    }
    func chooseLocalLyricsFile() async {
        guard currentTrack != nil else { return }
        onWillOpenFilePicker?()
        let url = await filePicker.pickLyricsFile()
        onDidCloseFilePicker?()
        guard let url else { return }
        lyricsViewModel.importLocalLyrics(from: url, for: currentTrack)
    }
    @discardableResult
    func addFilesOrDirectoriesToPlaylist(from urls: [URL]) -> Bool {
        guard !urls.isEmpty else { return false }
        var audioFileURLs: [URL] = []
        for url in urls {
            audioFileURLs.append(contentsOf: directoryScanner.audioFilesToImport(from: url))
        }

        // 依据文件名（不区分大小写）进行去重，防止相同歌曲从不同位置重复导入
        let existingNames = Set(playlist.map { $0.lastPathComponent.lowercased() })
        var seenNames: Set<String> = existingNames
        var newURLs: [URL] = []
        for url in audioFileURLs {
            let name = url.lastPathComponent.lowercased()
            if !seenNames.contains(name) {
                seenNames.insert(name)
                newURLs.append(url)
            }
        }
        guard let firstURL = newURLs.first else { return false }

        let isFirstImport = playlist.isEmpty
        playlist.append(contentsOf: newURLs)

        if isFirstImport || currentTrack == nil {
            currentIndex = playlist.count - newURLs.count
            loadFile(at: firstURL)
        }

        persistPlaylist()
        return true
    }

    private func canImportToPlaylist(_ url: URL) -> Bool {
        directoryScanner.canImportToPlaylist(url)
    }
    // MARK: - Online Playback

    // Playback state memory for both modes
    private var localTrackProgress: TimeInterval = 0
    private var localTrackIsPlaying: Bool = false
    private var onlineTrackProgress: TimeInterval = 0
    private var onlineTrackIsPlaying: Bool = false

    private func savePlaybackMemory() {
        if playlistMode == .local {
            localTrackProgress = currentTime
            localTrackIsPlaying = (state == .playing)
        } else {
            onlineTrackProgress = currentTime
            onlineTrackIsPlaying = (state == .playing)
        }
    }

    func switchPlaylistMode(to mode: PlaylistMode) {
        guard playlistMode != mode else { return }

        // 1. Save current mode's playback state
        savePlaybackMemory()

        // Cancel loading and clear current playback (temporarily)
        loadTask?.cancel()
        loadGeneration += 1
        playerController.clear()
        currentTrack = nil
        lyricsViewModel.clear()
        currentTime = 0
        state = .idle

        playlistMode = mode

        // 2. Restore new mode's playback state
        if playlistMode == .local {
            if let currentIndex, playlist.indices.contains(currentIndex) {
                loadFile(at: playlist[currentIndex], resumeFrom: localTrackProgress, shouldPlay: localTrackIsPlaying)
            }
        } else {
            if let currentOnlineIndex, activeOnlinePlaylist.indices.contains(currentOnlineIndex) {
                loadAndPlayOnlineSong(at: currentOnlineIndex, resumeFrom: onlineTrackProgress, shouldPlay: onlineTrackIsPlaying)
            }
        }
    }

    func cachedOnlinePlaylist(for playlistId: String) -> [NeteaseSong]? {
        cachedOnlinePlaylists[playlistId]
    }

    func setOnlinePlaylist(_ songs: [NeteaseSong], cacheKey: String? = nil) {
        self.onlinePlaylist = songs
        if let cacheKey {
            cachedOnlinePlaylists[cacheKey] = songs
        }
    }

    func loadUserPlaylistsIfNeeded(forceRefresh: Bool = false) {
        let cookie = UserDefaults.standard.string(forKey: "NeteaseCookie")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        // If cookie changed or was empty
        if cookie != lastLoadedCookie {
            self.userPlaylists = []
            self.currentUserId = nil
            self.currentUserNickname = nil
            self.lastLoadedCookie = cookie
            self.cachedOnlinePlaylists.removeAll()
        }

        guard !cookie.isEmpty else { return }
        guard forceRefresh || userPlaylists.isEmpty else { return }

        Task {
            do {
                guard let session = try await self.onlineMusicService.loadUserSession() else { return }
                await MainActor.run {
                    self.currentUserId = session.userId
                    self.currentUserNickname = session.nickname
                    self.userPlaylists = session.playlists
                }
            } catch {
                print("Failed to load user playlists: \(error)")
            }
        }
    }

    func playOnlineSong(at index: Int) {
        // Copy the currently displayed onlinePlaylist to activeOnlinePlaylist when explicitly selected by the user
        self.activeOnlinePlaylist = onlinePlaylist
        selectAndPlayOnlineSong(at: index)
    }

    private func selectAndPlayOnlineSong(at index: Int) {
        // Save current progress to memory before changing mode
        savePlaybackMemory()
        saveCurrentProgress()
        consecutiveFailures = 0

        if playlistMode != .online {
            loadTask?.cancel()
            loadGeneration += 1
            playerController.clear()
            currentTrack = nil
            lyricsViewModel.clear()
            currentTime = 0
            state = .idle
            playlistMode = .online
        }

        loadAndPlayOnlineSong(at: index, resumeFrom: 0, shouldPlay: true)
    }

    private func loadAndPlayOnlineSong(at index: Int, resumeFrom progress: TimeInterval? = nil, shouldPlay: Bool = true) {
        autoSkipTask?.cancel()
        playbackStartWatchdogTask?.cancel()

        guard activeOnlinePlaylist.indices.contains(index) else { return }
        let song = activeOnlinePlaylist[index]
        clearOnlineSongFailure(id: song.id)
        self.currentOnlineIndex = index
        currentTrackProgress = progress ?? 0

        loadTask?.cancel()
        loadGeneration += 1
        let generation = loadGeneration
        state = .loading
        currentTime = progress ?? 0

        // Stop currently playing music immediately
        playerController.clear()

        loadTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            do {
                let url = try await self.onlineMusicService.streamURL(for: song)
                await self.loadAndPlay(url: url, generation: generation, resumeFrom: progress, shouldPlay: shouldPlay, onlineSong: song)
            } catch OnlineMusicServiceError.unavailableStreamURL {
                guard generation == self.loadGeneration else { return }
                let errorMsg = "获取播放链接失败 (可能需要 VIP 或无版权)"
                self.markOnlineSongFailed(id: song.id, message: errorMsg)
                self.setFailedState(message: errorMsg)
            } catch {
                guard generation == self.loadGeneration else { return }
                let errorMsg = "网络请求失败"
                self.markOnlineSongFailed(id: song.id, message: errorMsg)
                self.setFailedState(message: errorMsg)
            }
        }
    }

    func playPreviousTrack() {
        guard canPlayPrevious else { return }

        let count = playlistMode == .local ? playlist.count : activeOnlinePlaylist.count
        let currentIdx = playlistMode == .local ? (currentIndex ?? 0) : (currentOnlineIndex ?? 0)

        let previousIndex: Int
        switch playbackMode {
        case .singleLoop:
            previousIndex = currentIdx - 1
        case .loop:
            previousIndex = currentIdx == 0 ? count - 1 : currentIdx - 1
        case .shuffle:
            previousIndex = currentIdx - 1
        }

        guard previousIndex >= 0 && previousIndex < count else { return }

        saveCurrentProgress()
        currentTrackProgress = 0
        consecutiveFailures = 0

        if playlistMode == .local {
            self.currentIndex = previousIndex
            persistPlaylist(syncCurrentProgress: false)
            loadFile(at: playlist[previousIndex])
        } else {
            self.currentOnlineIndex = previousIndex
            selectAndPlayOnlineSong(at: previousIndex)
        }
    }
    func togglePlaybackMode() {
        let allModes = MusicPlaybackMode.allCases
        guard let currentIndex = allModes.firstIndex(of: playbackMode) else { return }
        let nextIndex = (currentIndex + 1) % allModes.count
        playbackMode = allModes[nextIndex]
        persistPlaylist()
    }
    func playNextTrack(isUserInitiated: Bool = true) {
        guard playlistMode == .local ? !playlist.isEmpty : !activeOnlinePlaylist.isEmpty else { return }
        let count = playlistMode == .local ? playlist.count : activeOnlinePlaylist.count
        let currentIdx = playlistMode == .local ? currentIndex : currentOnlineIndex
        guard let currentIdx else { return }

        let nextIndex: Int
        switch playbackMode {
        case .singleLoop:
            guard currentIdx < count - 1 else { return }
            nextIndex = currentIdx + 1
        case .loop:
            nextIndex = (currentIdx + 1) % count
        case .shuffle:
            guard count > 1 else { return }
            let remainingIndices = (0..<count).filter { $0 != currentIdx }
            if let randomIndex = remainingIndices.randomElement() {
                nextIndex = randomIndex
            } else {
                return
            }
        }

        saveCurrentProgress()
        currentTrackProgress = 0
        if isUserInitiated {
            consecutiveFailures = 0
        }

        if playlistMode == .local {
            self.currentIndex = nextIndex
            persistPlaylist(syncCurrentProgress: false)
            loadFile(at: playlist[nextIndex])
        } else {
            self.currentOnlineIndex = nextIndex
            selectAndPlayOnlineSong(at: nextIndex)
        }
    }
    func playTrack(at index: Int) {
        guard playlist.indices.contains(index) else { return }
        if playlistMode == .local {
            guard currentIndex != index else { return }
        }

        // Save current progress to memory before changing mode
        savePlaybackMemory()
        saveCurrentProgress()

        if playlistMode != .local {
            loadTask?.cancel()
            loadGeneration += 1
            playerController.clear()
            currentTrack = nil
            lyricsViewModel.clear()
            currentTime = 0
            state = .idle
            playlistMode = .local
        }

        self.currentIndex = index
        currentTrackProgress = 0
        consecutiveFailures = 0
        persistPlaylist(syncCurrentProgress: false)
        loadFile(at: playlist[index])
    }
    func removeTrack(at index: Int) {
        guard playlist.indices.contains(index) else { return }
        let url = playlist[index]
        playlist.remove(at: index)
        failedLocalURLs.remove(url)
        // 删除当前播放项时，要把索引移动到仍存在的相邻曲目；删除前序项时要同步左移索引。
        if let currentIdx = currentIndex, currentIdx == index {
            if playlist.isEmpty {
                clearCurrentPlayback()
                persistPlaylist()
            } else {
                let newIndex = min(index, playlist.count - 1)
                guard playlist.indices.contains(newIndex) else { return }
                currentIndex = newIndex
                currentTrackProgress = 0
                persistPlaylist(syncCurrentProgress: false)
                loadFile(at: playlist[newIndex])
            }
        } else if let currentIdx = currentIndex, currentIdx > index {
            let newCurrentIdx = currentIdx - 1
            guard playlist.indices.contains(newCurrentIdx) else { return }
            self.currentIndex = newCurrentIdx
            persistPlaylist()
        } else {
            persistPlaylist()
        }
    }
    func playOnlineSongDirectly(_ song: NeteaseSong) {
        playlistMode = .online
        if let index = activeOnlinePlaylist.firstIndex(where: { $0.id == song.id }) {
            selectAndPlayOnlineSong(at: index)
        } else {
            activeOnlinePlaylist.append(song)
            selectAndPlayOnlineSong(at: activeOnlinePlaylist.count - 1)
        }
    }
    func removeOnlineTrack(at index: Int) {
        guard activeOnlinePlaylist.indices.contains(index) else { return }
        activeOnlinePlaylist.remove(at: index)

        if let currentIdx = currentOnlineIndex, currentIdx == index {
            if activeOnlinePlaylist.isEmpty {
                currentOnlineIndex = nil
                clearCurrentPlayback()
            } else {
                let newIndex = min(index, activeOnlinePlaylist.count - 1)
                currentOnlineIndex = newIndex
                currentTrackProgress = 0
                loadAndPlayOnlineSong(at: newIndex, resumeFrom: 0, shouldPlay: state == .playing)
            }
        } else if let currentIdx = currentOnlineIndex, currentIdx > index {
            self.currentOnlineIndex = currentIdx - 1
        }
    }
    func clearPlaylistAndPlayback() {
        clearPlaylist()
        clearCurrentPlayback()
        persistPlaylist()
    }
    private func loadFile(at url: URL, resumeFrom progress: TimeInterval? = nil, shouldPlay: Bool = true, onlineSong: NeteaseSong? = nil) {
        autoSkipTask?.cancel()
        playbackStartWatchdogTask?.cancel()

        loadTask?.cancel()
        loadGeneration += 1
        let generation = loadGeneration
        state = .loading
        currentTime = 0
        currentTrackProgress = progress ?? 0

        // Stop currently playing music immediately
        playerController.clear()

        loadTask = Task { @MainActor [weak self] in
            await self?.loadAndPlay(url: url, generation: generation, resumeFrom: progress, shouldPlay: shouldPlay, onlineSong: onlineSong)
        }
    }
    func togglePlayPause() {
        guard currentTrack != nil else {
            if playlistMode == .local {
                if let currentIndex, playlist.indices.contains(currentIndex) {
                    loadFile(at: playlist[currentIndex])
                } else {
                    Task { await addFilesOrDirectoriesToPlaylist() }
                }
            } else {
                if let currentOnlineIndex, activeOnlinePlaylist.indices.contains(currentOnlineIndex) {
                    selectAndPlayOnlineSong(at: currentOnlineIndex)
                }
            }
            return
        }
        switch state {
        case .playing:
            playerController.pause()
            playbackStartWatchdogTask?.cancel()
            saveCurrentProgress()
            state = .paused
        case .paused:
            playerController.play()
            state = .playing
        case .idle, .failed:
            Task {
                await addFilesOrDirectoriesToPlaylist()
            }
        case .loading:
            break
        }
    }
    private func clearCurrentPlayback() {
        autoSkipTask?.cancel()
        playbackStartWatchdogTask?.cancel()

        loadTask?.cancel()
        loadGeneration += 1
        // 清空列表或删除最后一首时，旧曲目信息也要移除，避免空列表仍显示旧标题。
        playerController.clear()
        currentTrack = nil
        lyricsViewModel.clear()
        currentIndex = nil
        currentTime = 0
        currentTrackProgress = 0
        state = .idle
    }
    private func clearPlaylist() {
        playlist = []
        currentIndex = nil
        failedLocalURLs.removeAll()
    }
    func seek(to progress: Double) {
        guard duration > 0 else { return }
        let seconds = min(max(progress, 0), 1) * duration
        playerController.seek(to: seconds)
    }
    func updateScrubbingProgress(_ progress: Double) {
        guard duration > 0 else { return }
        let targetTime = min(max(progress, 0), 1) * duration
        scrubbingTime = targetTime
        lyricsViewModel.updateTime(targetTime)
    }
    func endScrubbing(at progress: Double) {
        seek(to: progress)
        if let targetTime = scrubbingTime {
            lyricsViewModel.updateTime(targetTime)
        }
        scrubbingTime = nil
    }
    private func loadAndPlay(url: URL, generation: Int, resumeFrom progress: TimeInterval? = nil, shouldPlay: Bool = true, onlineSong: NeteaseSong? = nil) async {
        do {
            let track: MusicTrack
            if let onlineSong = onlineSong {
                let duration = onlineSong.dt != nil ? TimeInterval(onlineSong.dt!) / 1000.0 : nil
                track = try await playerController.load(url: url, predefinedTitle: onlineSong.name, predefinedArtist: onlineSong.artistName, predefinedDuration: duration)
                onlineMusicService.autoDownloadOnPlayIfNeeded(song: onlineSong)
            } else {
                track = try await playerController.load(url: url)
                if failedLocalURLs.contains(url) {
                    failedLocalURLs.remove(url)
                    persistPlaylist(syncCurrentProgress: false)
                }
            }

            // 如果任务取消发生在底层播放器刚装好 item 之后，需要主动清理文件访问权限。
            if Task.isCancelled, generation == loadGeneration {
                playerController.clear()
                return
            }
            // 旧加载结果只忽略，不清空当前新曲目。
            guard generation == loadGeneration else { return }
            consecutiveFailures = 0
            currentTrack = track
            lyricsViewModel.setCurrentTrack(track)
            showLyrics()
            currentTime = 0
            if let progress {
                playerController.seek(to: progress) { [weak self] _ in
                    guard let self, generation == self.loadGeneration else { return }
                    if shouldPlay {
                        if let onlineSong {
                            self.startOnlinePlaybackWatchdog(for: onlineSong, generation: generation, baselineTime: progress)
                            self.playerController.play()
                            self.state = .loading
                        } else {
                            self.playerController.play()
                            self.state = .playing
                        }
                    } else {
                        self.state = .paused
                    }
                }
                currentTime = progress
                currentTrackProgress = progress
            } else {
                if shouldPlay {
                    if let onlineSong {
                        startOnlinePlaybackWatchdog(for: onlineSong, generation: generation, baselineTime: 0)
                    }
                    playerController.play()
                    state = onlineSong == nil ? .playing : .loading
                } else {
                    state = .paused
                }
            }
        } catch {
            guard generation == loadGeneration else { return }
            currentTime = 0
            if onlineSong == nil {
                print("[MusicPlayerViewModel] Local track unplayable or missing: \(url.path)")
                failedLocalURLs.insert(url)
                persistPlaylist(syncCurrentProgress: false)
            } else if let onlineSong = onlineSong {
                let errorMsg = "网络连接异常或无版权"
                markOnlineSongFailed(id: onlineSong.id, message: errorMsg)
            }
            let message = "无法播放，" + (onlineSong != nil ? "网络连接异常或无版权" : "文件已移动或格式不支持")
            setFailedState(message: message)
        }
    }
    private func handlePlaybackEnded() {
        playbackStartWatchdogTask?.cancel()
        // 自然结束后由 ViewModel 根据播放列表和模式决定下一步，Controller 只负责发结束事件。
        if hasPlaylist {
            if playbackMode == .singleLoop {
                restartCurrentTrack()
                return
            }
            if canPlayNext {
                playNextTrack(isUserInitiated: false)
                return
            }
        }
        playerController.pauseAndResetToBeginning()
        currentTime = 0
        currentTrackProgress = 0
        state = .paused
        persistPlaylist(syncCurrentProgress: false)
    }
    private func handlePlaybackStarted() {
        if playlistMode == .online, currentTime <= 0.15 {
            return
        }
        playbackStartWatchdogTask?.cancel()
        playbackStartWatchdogTask = nil
        guard currentTrack != nil else { return }
        if state == .loading {
            state = .playing
        }
    }
    private func handlePlaybackFailure(message: String) {
        failCurrentPlayback(message: message)
    }
    private func handlePlaybackStalled() {
        guard playlistMode == .online, currentTime <= 0.2 else { return }
        guard let currentOnlineIndex,
              activeOnlinePlaylist.indices.contains(currentOnlineIndex) else { return }
        startOnlinePlaybackWatchdog(
            for: activeOnlinePlaylist[currentOnlineIndex],
            generation: loadGeneration,
            baselineTime: currentTime,
            timeoutNanoseconds: 6_000_000_000
        )
    }
    private func restorePlaylist() {
        guard let snapshot = playlistStore.load() else { return }
        playbackMode = snapshot.playbackMode
        volume = snapshot.volume ?? 1.0 // 恢复保存的音量，缺失时按默认 1.0 处理
        let playableEntries = snapshot.playlist.enumerated().filter { entry in
            directoryScanner.isAudioFile(entry.element)
        }
        playlist = playableEntries.map(\.element)
        failedLocalURLs = snapshot.failedLocalURLs ?? []
        resetOnlineFailureState()

        if let restoredIndex = snapshot.currentIndex,
           let remappedIndex = playableEntries.firstIndex(where: { $0.offset == restoredIndex }) {
            currentIndex = remappedIndex
        } else if playlist.isEmpty {
            currentIndex = nil
        } else {
            currentIndex = 0
        }

        // currentTrackProgress 是可选字段，兼容旧 playlist.json；缺失时从 0 开始恢复。
        if let restoredIndex = currentIndex, playlist.indices.contains(restoredIndex) {
            let savedProgress = snapshot.currentTrackProgress ?? 0
            let shouldPlay = snapshot.isPlaying ?? false
            loadFile(at: playlist[restoredIndex], resumeFrom: savedProgress, shouldPlay: shouldPlay)
        } else if snapshot.playlist.count != playlist.count || !playlist.isEmpty {
            persistPlaylist()
        }
    }
    private func persistPlaylist(syncCurrentProgress: Bool = true) {
        if syncCurrentProgress, currentTrack != nil {
            currentTrackProgress = currentTime
        }
        let snapshot = MusicPlaylistSnapshot(
            playlist: playlist,
            currentIndex: currentIndex,
            playbackMode: playbackMode,
            currentTrackProgress: currentTrackProgress,
            volume: volume,
            isPlaying: state == .playing,
            failedLocalURLs: failedLocalURLs
        )
        playlistStore.save(snapshot)
    }
    private func saveCurrentProgress() {
        guard currentTrack != nil else { return }
        currentTrackProgress = currentTime
        persistPlaylist()
    }
    func persistCurrentStateOnQuit() {
        if state == .playing {
            playerController.pause()
        }
        saveCurrentProgress()
    }

    func markOnlineSongFailed(id: Int, message: String) {
        failedOnlineSongIDs.insert(id)
        onlineSongFailureMessages[id] = message
    }

    func clearOnlineSongFailure(id: Int) {
        if failedOnlineSongIDs.contains(id) {
            failedOnlineSongIDs.remove(id)
            onlineSongFailureMessages.removeValue(forKey: id)
        }
    }

    func resetOnlineFailureState() {
        failedOnlineSongIDs.removeAll()
        onlineSongFailureMessages.removeAll()
    }

    private func setFailedState(message: String) {
        playbackStartWatchdogTask?.cancel()
        self.state = .failed(message)
        self.currentTrack = nil
        self.lyricsViewModel.clear()

        autoSkipTask?.cancel()

        consecutiveFailures += 1
        let limit = playlistMode == .local ? playlist.count : activeOnlinePlaylist.count
        if consecutiveFailures >= limit {
            consecutiveFailures = 0
            return
        }

        guard canPlayNext else { return }
        autoSkipTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                guard let self = self, !Task.isCancelled else { return }
                self.playNextTrack(isUserInitiated: false)
            } catch {
                // Task was cancelled
            }
        }
    }
    private func startOnlinePlaybackWatchdog(
        for song: NeteaseSong,
        generation: Int,
        baselineTime: TimeInterval,
        timeoutNanoseconds: UInt64 = 8_000_000_000
    ) {
        playbackStartWatchdogTask?.cancel()
        playbackStartWatchdogTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
                guard let self, !Task.isCancelled else { return }
                guard generation == self.loadGeneration else { return }
                guard self.playlistMode == .online,
                      let currentOnlineIndex = self.currentOnlineIndex,
                      self.activeOnlinePlaylist.indices.contains(currentOnlineIndex),
                      self.activeOnlinePlaylist[currentOnlineIndex].id == song.id else { return }
                guard self.state == .loading || self.state == .playing else { return }
                if self.currentTime > baselineTime + 0.25 {
                    self.handlePlaybackStarted()
                    return
                }
                self.failCurrentPlayback(message: "播放启动超时")
            } catch {
                // 新的切歌或用户操作会取消旧 watchdog。
            }
        }
    }
    private func failCurrentPlayback(message: String) {
        if case .failed = state { return }
        playbackStartWatchdogTask?.cancel()

        if playlistMode == .online,
           let currentOnlineIndex,
           activeOnlinePlaylist.indices.contains(currentOnlineIndex) {
            let song = activeOnlinePlaylist[currentOnlineIndex]
            markOnlineSongFailed(id: song.id, message: message)
            setFailedState(message: "无法播放，\(message)")
            return
        }

        if playlistMode == .local,
           let currentIndex,
           playlist.indices.contains(currentIndex) {
            let url = playlist[currentIndex]
            failedLocalURLs.insert(url)
            persistPlaylist(syncCurrentProgress: false)
            setFailedState(message: "无法播放，文件已移动或格式不支持")
            return
        }

        setFailedState(message: "无法播放，\(message)")
    }
    private func restartCurrentTrack() {
        switch playlistMode {
        case .local:
            guard let currentIndex, playlist.indices.contains(currentIndex) else { return }
        case .online:
            guard let currentOnlineIndex, activeOnlinePlaylist.indices.contains(currentOnlineIndex) else { return }
        }
        playerController.pauseAndResetToBeginning()
        if playlistMode == .online,
           let currentOnlineIndex,
           activeOnlinePlaylist.indices.contains(currentOnlineIndex) {
            startOnlinePlaybackWatchdog(for: activeOnlinePlaylist[currentOnlineIndex], generation: loadGeneration, baselineTime: 0)
        }
        playerController.play()
        currentTime = 0
        currentTrackProgress = 0
        state = playlistMode == .online ? .loading : .playing
        if playlistMode == .local {
            persistPlaylist(syncCurrentProgress: false)
        }
    }
    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "00:00" }
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}
