import AVFoundation
import Foundation

// 封装 AVPlayer、播放结束监听和 security-scoped 文件访问，SwiftUI 层不直接接触这些平台细节。
@MainActor
final class MusicPlayerController {
    private let player = AVPlayer()
    var isMuted: Bool {
        get { player.isMuted }
        set {
            player.isMuted = newValue
            onIsMutedChange?(newValue)
        }
    }
    var volume: Float {
        get { player.volume }
        set {
            player.volume = newValue
        }
    }
    var onIsMutedChange: ((Bool) -> Void)?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    // NSOpenPanel 返回的沙盒外文件需要在播放期间保持 security-scoped access。
    private var securityScopedURL: URL?
    private var isAccessingSecurityScopedResource = false
    // 用请求编号隔离连续加载；旧的异步 load 晚返回时不能覆盖新曲目。
    private var loadRequestID = 0
    var onProgressChange: ((TimeInterval) -> Void)?
    var onPlaybackEnded: (() -> Void)?
    func load(url: URL) async throws -> MusicTrack {
        loadRequestID += 1
        let requestID = loadRequestID
        clearCurrentItem(invalidatesPendingLoads: false)
        beginSecurityScopedAccess(for: url)

        do {
            let asset = AVURLAsset(
                url: url,
                options: [AVURLAssetPreferPreciseDurationAndTimingKey: true]
            )
            let duration = try await asset.load(.duration)
            // 用户可能在 await 期间又选择了新文件，旧请求必须失效。
            guard requestID == loadRequestID else {
                throw CancellationError()
            }
            let seconds = duration.seconds.isFinite ? duration.seconds : 0
            let item = AVPlayerItem(asset: asset)
            player.replaceCurrentItem(with: item)
            installTimeObserver()
            installEndObserver(for: item)
            return MusicTrack(url: url, duration: seconds)
        } catch {
            if requestID == loadRequestID {
                clearCurrentItem(invalidatesPendingLoads: false)
            }
            throw error
        }
    }
    func play() {
        player.play()
    }
    func pause() {
        player.pause()
    }
    func pauseAndResetToBeginning() {
        player.pause()
        player.seek(to: .zero)
        onProgressChange?(0)
    }
    func clear() {
        clearCurrentItem()
        onProgressChange?(0)
    }
    func seek(to seconds: TimeInterval, completionHandler: ((Bool) -> Void)? = nil) {
        let safeSeconds = max(0, seconds)
        let time = CMTime(seconds: safeSeconds, preferredTimescale: 600)
        player.seek(to: time) { [weak self] finished in
            Task { @MainActor [weak self] in
                completionHandler?(finished)
                self?.onProgressChange?(safeSeconds)
            }
        }
    }
    private func installTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            // AVPlayer 回调不继承 MainActor 隔离，回写 UI 状态前显式切回主 actor。
            Task { @MainActor [weak self] in
                self?.onProgressChange?(time.seconds)
            }
        }
    }
    private func installEndObserver(for item: AVPlayerItem) {
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.onPlaybackEnded?()
            }
        }
    }
    private func removeObservers() {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
    }
    private func beginSecurityScopedAccess(for url: URL) {
        let didStartAccess = url.startAccessingSecurityScopedResource()
        securityScopedURL = url
        isAccessingSecurityScopedResource = didStartAccess
    }
    private func endSecurityScopedAccess() {
        if isAccessingSecurityScopedResource {
            Self.stopSecurityScopedAccess(for: securityScopedURL)
        }
        securityScopedURL = nil
        isAccessingSecurityScopedResource = false
    }
    private func clearCurrentItem(invalidatesPendingLoads: Bool = true) {
        if invalidatesPendingLoads {
            loadRequestID += 1
        }
        player.pause()
        removeObservers()
        player.replaceCurrentItem(with: nil)
        endSecurityScopedAccess()
    }
    deinit {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        if isAccessingSecurityScopedResource {
            Self.stopSecurityScopedAccess(for: securityScopedURL)
        }
    }
    nonisolated private static func stopSecurityScopedAccess(for url: URL?) {
        guard let url else { return }
        url.stopAccessingSecurityScopedResource()
    }
}
