import Combine
import CoreGraphics
import Foundation

// 音乐功能的状态入口：管理播放列表语义，底层 AVPlayer 细节留在 MusicPlayerController。
@MainActor
final class MusicPlayerViewModel: ObservableObject {
    @Published private(set) var state: MusicPlayerState = .idle
    @Published private(set) var currentTrack: MusicTrack?
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var playlist: [URL] = []
    @Published private(set) var currentIndex: Int?
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
    private let filePicker: MusicFilePicker
    private let playerController: MusicPlayerController
    private let directoryScanner: MusicDirectoryScanner
    private let playlistStore: MusicPlaylistStore
    private var currentTrackProgress: TimeInterval = 0
    var onWillOpenFilePicker: (() -> Void)?
    var onDidCloseFilePicker: (() -> Void)?
    // 连续选择文件时取消旧加载，并用 generation 防止旧结果晚返回覆盖新状态。
    private var loadTask: Task<Void, Never>?
    private var loadGeneration = 0
    convenience init(restoresPlaylistOnInit: Bool = true) {
        self.init(
            filePicker: MusicFilePicker(),
            playerController: MusicPlayerController(),
            directoryScanner: MusicDirectoryScanner(),
            playlistStore: MusicPlaylistStore(),
            restoresPlaylistOnInit: restoresPlaylistOnInit
        )
    }
    init(
        filePicker: MusicFilePicker,
        playerController: MusicPlayerController,
        directoryScanner: MusicDirectoryScanner,
        playlistStore: MusicPlaylistStore,
        restoresPlaylistOnInit: Bool = true
    ) {
        self.filePicker = filePicker
        self.playerController = playerController
        self.directoryScanner = directoryScanner
        self.playlistStore = playlistStore
        self.playerController.onProgressChange = { [weak self] seconds in
            self?.currentTime = seconds
        }
        self.playerController.onPlaybackEnded = { [weak self] in
            self?.handlePlaybackEnded()
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
        guard let currentIndex else { return false }
        return playlist.indices.contains(currentIndex)
    }
    var canPlayPrevious: Bool {
        guard hasPlaylist else { return false }
        if playbackMode == .loop {
            return playlist.count > 0
        }
        guard let currentIndex else { return false }
        return currentIndex > 0
    }
    var canPlayNext: Bool {
        guard hasPlaylist else { return false }
        if playbackMode == .loop {
            return playlist.count > 0
        }
        if playbackMode == .shuffle {
            return playlist.count > 1
        }
        guard let currentIndex else { return false }
        return currentIndex < playlist.count - 1
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
        if let currentIndex, playlist.indices.contains(currentIndex) {
            return playlist[currentIndex].deletingPathExtension().lastPathComponent
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
        case .order:
            return "list.bullet"
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
        case .order:
            return "顺序播放"
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
    func addFilesOrDirectoriesToPlaylist() async {
        // 文件选择器自身会提升到 island 上方；回调用于关闭后恢复 island 层级。
        onWillOpenFilePicker?()
        let urls = await filePicker.pickAudioFilesAndDirectories()
        onDidCloseFilePicker?()
        guard !urls.isEmpty else { return }
        addFilesOrDirectoriesToPlaylist(from: urls)
    }
    func addFilesOrDirectoriesToPlaylist(from urls: [URL]) {
        guard !urls.isEmpty else { return }
        var audioFileURLs: [URL] = []
        for url in urls {
            var isDirectory = ObjCBool(false)
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    audioFileURLs.append(contentsOf: directoryScanner.audioFiles(in: url))
                } else if directoryScanner.isAudioFile(url) {
                    audioFileURLs.append(url)
                }
            }
        }
        let existingURLs = Set(playlist.map { $0.absoluteString })
        var seenURLs: Set<String> = existingURLs
        var newURLs: [URL] = []
        for url in audioFileURLs {
            let absolute = url.absoluteString
            if !seenURLs.contains(absolute) {
                seenURLs.insert(absolute)
                newURLs.append(url)
            }
        }
        guard let firstURL = newURLs.first else { return }
        let firstNewIndex = playlist.count
        playlist.append(contentsOf: newURLs)
        if !hasPlaylist || currentTrack == nil {
            currentIndex = firstNewIndex
            loadFile(at: firstURL)
        }
        persistPlaylist()
    }
    func playPreviousTrack() {
        guard canPlayPrevious, let currentIndex else { return }

        let previousIndex: Int
        switch playbackMode {
        case .order:
            previousIndex = currentIndex - 1
        case .singleLoop:
            previousIndex = currentIndex - 1
        case .loop:
            previousIndex = currentIndex == 0 ? playlist.count - 1 : currentIndex - 1
        case .shuffle:
            previousIndex = currentIndex - 1
        }
        guard playlist.indices.contains(previousIndex) else { return }
        saveCurrentProgress()
        self.currentIndex = previousIndex
        currentTrackProgress = 0
        persistPlaylist(syncCurrentProgress: false)
        loadFile(at: playlist[previousIndex])
    }
    func togglePlaybackMode() {
        let allModes = MusicPlaybackMode.allCases
        guard let currentIndex = allModes.firstIndex(of: playbackMode) else { return }
        let nextIndex = (currentIndex + 1) % allModes.count
        playbackMode = allModes[nextIndex]
        persistPlaylist()
    }
    func playNextTrack() {
        guard let currentIndex, !playlist.isEmpty else { return }

        let nextIndex: Int
        switch playbackMode {
        case .order:
            guard currentIndex < playlist.count - 1 else { return }
            nextIndex = currentIndex + 1
        case .singleLoop:
            guard currentIndex < playlist.count - 1 else { return }
            nextIndex = currentIndex + 1
        case .loop:
            nextIndex = (currentIndex + 1) % playlist.count
        case .shuffle:
            guard playlist.count > 1 else { return }
            let remainingIndices = playlist.indices.filter { $0 != currentIndex }
            if let randomIndex = remainingIndices.randomElement() {
                nextIndex = randomIndex
            } else {
                return
            }
        }
        saveCurrentProgress()
        self.currentIndex = nextIndex
        currentTrackProgress = 0
        persistPlaylist(syncCurrentProgress: false)
        loadFile(at: playlist[nextIndex])
    }
    func playTrack(at index: Int) {
        guard playlist.indices.contains(index) else { return }
        guard currentIndex != index else { return }
        saveCurrentProgress()
        self.currentIndex = index
        currentTrackProgress = 0
        persistPlaylist(syncCurrentProgress: false)
        loadFile(at: playlist[index])
    }
    func removeTrack(at index: Int) {
        guard playlist.indices.contains(index) else { return }
        playlist.remove(at: index)
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
    func clearPlaylistAndPlayback() {
        clearPlaylist()
        clearCurrentPlayback()
        persistPlaylist()
    }
    private func loadFile(at url: URL, resumeFrom progress: TimeInterval? = nil) {
        loadTask?.cancel()
        loadGeneration += 1
        let generation = loadGeneration
        state = .loading
        currentTime = 0
        currentTrackProgress = progress ?? 0
        loadTask = Task { @MainActor [weak self] in
            await self?.loadAndPlay(url: url, generation: generation, resumeFrom: progress)
        }
    }
    func togglePlayPause() {
        guard currentTrack != nil else {
            if let currentIndex, playlist.indices.contains(currentIndex) {
                loadFile(at: playlist[currentIndex])
            } else {
                Task {
                    await addFilesOrDirectoriesToPlaylist()
                }
            }
            return
        }
        switch state {
        case .playing:
            playerController.pause()
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
        loadTask?.cancel()
        loadGeneration += 1
        // 清空列表或删除最后一首时，旧曲目信息也要移除，避免空列表仍显示旧标题。
        playerController.clear()
        currentTrack = nil
        currentIndex = nil
        currentTime = 0
        currentTrackProgress = 0
        state = .idle
    }
    private func clearPlaylist() {
        playlist = []
        currentIndex = nil
    }
    func seek(to progress: Double) {
        guard duration > 0 else { return }
        let seconds = min(max(progress, 0), 1) * duration
        playerController.seek(to: seconds)
    }
    func updateScrubbingProgress(_ progress: Double) {
        guard duration > 0 else { return }
        scrubbingTime = min(max(progress, 0), 1) * duration
    }
    func endScrubbing(at progress: Double) {
        seek(to: progress)
        scrubbingTime = nil
    }
    private func loadAndPlay(url: URL, generation: Int, resumeFrom progress: TimeInterval? = nil) async {
        do {
            let track = try await playerController.load(url: url)
            // 如果任务取消发生在底层播放器刚装好 item 之后，需要主动清理文件访问权限。
            if Task.isCancelled, generation == loadGeneration {
                playerController.clear()
                return
            }
            // 旧加载结果只忽略，不清空当前新曲目。
            guard generation == loadGeneration else { return }
            currentTrack = track
            currentTime = 0
            if let progress {
                playerController.seek(to: progress) { [weak self] _ in
                    self?.playerController.play()
                    self?.state = .playing
                }
                currentTime = progress
                currentTrackProgress = progress
            } else {
                playerController.play()
                state = .playing
            }
        } catch {
            guard generation == loadGeneration else { return }
            currentTrack = nil
            currentTime = 0
            state = .failed("无法播放，文件已移动或格式不支持")
        }
    }
    private func handlePlaybackEnded() {
        // 自然结束后由 ViewModel 根据播放列表和模式决定下一步，Controller 只负责发结束事件。
        if hasPlaylist {
            if playbackMode == .singleLoop {
                restartCurrentTrack()
                return
            }
            if canPlayNext {
                playNextTrack()
                return
            }
        }
        playerController.pauseAndResetToBeginning()
        currentTime = 0
        currentTrackProgress = 0
        state = .paused
        persistPlaylist(syncCurrentProgress: false)
    }
    private func restorePlaylist() {
        guard let snapshot = playlistStore.load() else { return }
        playbackMode = snapshot.playbackMode
        volume = snapshot.volume ?? 1.0 // 恢复保存的音量，缺失时按默认 1.0 处理
        playlist = snapshot.playlist
            .filter { directoryScanner.isAudioFile($0) }

        if let restoredIndex = snapshot.currentIndex, playlist.indices.contains(restoredIndex) {
            currentIndex = restoredIndex
        } else if playlist.isEmpty {
            currentIndex = nil
        } else {
            currentIndex = 0
        }

        // currentTrackProgress 是可选字段，兼容旧 playlist.json；缺失时从 0 开始恢复。
        if let restoredIndex = currentIndex, playlist.indices.contains(restoredIndex) {
            let savedProgress = snapshot.currentTrackProgress ?? 0
            loadFile(at: playlist[restoredIndex], resumeFrom: savedProgress)
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
            volume: volume
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
    private func restartCurrentTrack() {
        guard let currentIndex, playlist.indices.contains(currentIndex) else { return }
        playerController.pauseAndResetToBeginning()
        playerController.play()
        currentTime = 0
        currentTrackProgress = 0
        state = .playing
        persistPlaylist(syncCurrentProgress: false)
    }
    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "00:00" }
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}
