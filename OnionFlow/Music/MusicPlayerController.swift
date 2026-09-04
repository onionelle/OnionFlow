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
    private var failedObserver: NSObjectProtocol?
    private var stalledObserver: NSObjectProtocol?
    private var itemStatusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var hasReportedPlaybackStart = false
    // NSOpenPanel 返回的沙盒外文件需要在播放期间保持 security-scoped access。
    private var securityScopedURL: URL?
    private var isAccessingSecurityScopedResource = false
    // 用请求编号隔离连续加载；旧的异步 load 晚返回时不能覆盖新曲目。
    private var loadRequestID = 0
    var onProgressChange: ((TimeInterval) -> Void)?
    var onPlaybackEnded: (() -> Void)?
    var onPlaybackStarted: (() -> Void)?
    var onPlaybackFailure: ((String) -> Void)?
    var onPlaybackStalled: (() -> Void)?
    var progressInterval: TimeInterval = 0.25 {
        didSet {
            guard timeObserver != nil, abs(oldValue - progressInterval) > 0.05 else { return }
            installTimeObserver()
        }
    }
    func load(url: URL, predefinedTitle: String? = nil, predefinedArtist: String? = nil, predefinedDuration: TimeInterval? = nil) async throws -> MusicTrack {
        loadRequestID += 1
        let requestID = loadRequestID
        clearCurrentItem(invalidatesPendingLoads: false)
        
        // 只对 file:// 协议进行 Security Scoped Access
        let isLocalFile = url.isFileURL
        if isLocalFile {
            beginSecurityScopedAccess(for: url)
        }
        DiagnosticLogService.shared.log("player.load.begin", url: url, [
            "requestID": String(requestID),
            "securityScopedAccessStarted": isLocalFile && isAccessingSecurityScopedResource ? "true" : "false"
        ])

        do {
            let asset = AVURLAsset(
                url: url,
                options: [AVURLAssetPreferPreciseDurationAndTimingKey: true]
            )
            
            // 如果是在线流媒体且提供了预定义元数据，直接使用，跳过耗时的 asset.load
            let duration: TimeInterval
            if let pd = predefinedDuration {
                duration = pd
            } else {
                let d = try await asset.load(.duration)
                duration = d.seconds.isFinite ? d.seconds : 0
            }
            
            let metadataTitle: String?
            let metadataArtist: String?
            
            if let pt = predefinedTitle, let pa = predefinedArtist {
                metadataTitle = pt
                metadataArtist = pa
            } else {
                let metadata = (try? await asset.load(.commonMetadata)) ?? []
                metadataTitle = await metadataString(for: .commonKeyTitle, in: metadata)
                metadataArtist = await metadataString(for: .commonKeyArtist, in: metadata)
            }
            
            // 用户可能在 await 期间又选择了新文件，旧请求必须失效。
            guard requestID == loadRequestID else {
                throw CancellationError()
            }
            let item = AVPlayerItem(asset: asset)
            player.replaceCurrentItem(with: item)
            installTimeObserver()
            installPlaybackObservers(for: item, url: url)
            return MusicTrack(
                url: url,
                duration: duration,
                metadataTitle: metadataTitle,
                metadataArtist: metadataArtist
            )
        } catch {
            if requestID == loadRequestID {
                clearCurrentItem(invalidatesPendingLoads: false)
            }
            if !(error is CancellationError) {
                DiagnosticLogService.shared.log("player.load.failed", url: url, [
                    "requestID": String(requestID),
                    "error": Self.playbackFailureMessage(from: error)
                ])
            }
            throw error
        }
    }
    func play() {
        if timeObserver == nil, player.currentItem != nil {
            installTimeObserver()
        }
        player.play()
    }
    func pause() {
        player.pause()
        removeTimeObserver()
    }
    func pauseAndResetToBeginning() {
        player.pause()
        removeTimeObserver()
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
    private func metadataString(for key: AVMetadataKey, in metadata: [AVMetadataItem]) async -> String? {
        guard let item = metadata.first(where: { $0.commonKey?.rawValue == key.rawValue }),
              let value = try? await item.load(.stringValue) else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    private func installTimeObserver() {
        removeTimeObserver()
        let interval = CMTime(seconds: max(progressInterval, 0.2), preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            // AVPlayer 回调不继承 MainActor 隔离，回写 UI 状态前显式切回主 actor。
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.player.timeControlStatus == .playing else { return }
                let seconds = time.seconds
                self.onProgressChange?(seconds)
                if seconds.isFinite, seconds > 0 {
                    self.reportPlaybackStartedIfNeeded()
                }
            }
        }
    }
    private func removeTimeObserver() {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
    }
    private func installPlaybackObservers(for item: AVPlayerItem, url: URL) {
        hasReportedPlaybackStart = false
        let requestID = loadRequestID
        let loadedURL = url
        itemStatusObservation = item.observe(\.status, options: [.new]) { [weak self] observedItem, _ in
            let status = observedItem.status
            let failureMessage = observedItem.error.map { Self.playbackFailureMessage(from: $0) }
            Task { @MainActor [weak self] in
                guard let self, self.loadRequestID == requestID else { return }
                switch status {
                case .readyToPlay:
                    break
                case .failed:
                    let message = failureMessage ?? "播放链接不可用"
                    DiagnosticLogService.shared.log("player.item.status_failed", url: loadedURL, [
                        "requestID": String(requestID),
                        "error": message
                    ])
                    self.reportPlaybackFailure(message)
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }
        timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] observedPlayer, _ in
            let isPlaying = observedPlayer.timeControlStatus == .playing
            Task { @MainActor [weak self] in
                guard let self, self.loadRequestID == requestID else { return }
                if isPlaying {
                    self.reportPlaybackStartedIfNeeded()
                }
            }
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.loadRequestID == requestID else { return }
                self.onPlaybackEnded?()
            }
        }
        failedObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] notification in
            let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            let message = error.map { Self.playbackFailureMessage(from: $0) } ?? "播放中断"
            Task { @MainActor [weak self] in
                guard let self, self.loadRequestID == requestID else { return }
                DiagnosticLogService.shared.log("player.item.failed_to_end", url: loadedURL, [
                    "requestID": String(requestID),
                    "error": message
                ])
                self.reportPlaybackFailure(message)
            }
        }
        stalledObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemPlaybackStalled,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.loadRequestID == requestID else { return }
                DiagnosticLogService.shared.log("player.item.stalled", url: loadedURL, [
                    "requestID": String(requestID)
                ])
                self.onPlaybackStalled?()
            }
        }
    }

    nonisolated private static func playbackFailureMessage(from error: Error) -> String {
        let nsError = error as NSError
        var parts = [nsError.localizedDescription, "\(nsError.domain):\(nsError.code)"]
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            parts.append("\(underlying.domain):\(underlying.code)")
        }
        if let reason = nsError.userInfo[NSLocalizedFailureReasonErrorKey] as? String, !reason.isEmpty {
            parts.append(reason)
        }
        return parts.joined(separator: " | ")
    }
    private func removeObservers() {
        removeTimeObserver()
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil
        timeControlObservation?.invalidate()
        timeControlObservation = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        if let failedObserver {
            NotificationCenter.default.removeObserver(failedObserver)
            self.failedObserver = nil
        }
        if let stalledObserver {
            NotificationCenter.default.removeObserver(stalledObserver)
            self.stalledObserver = nil
        }
    }
    private func reportPlaybackStartedIfNeeded() {
        guard !hasReportedPlaybackStart else { return }
        hasReportedPlaybackStart = true
        onPlaybackStarted?()
    }
    private func reportPlaybackFailure(_ message: String) {
        onPlaybackFailure?(message)
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
        hasReportedPlaybackStart = false
        player.replaceCurrentItem(with: nil)
        endSecurityScopedAccess()
    }
    deinit {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        itemStatusObservation?.invalidate()
        timeControlObservation?.invalidate()
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        if let failedObserver {
            NotificationCenter.default.removeObserver(failedObserver)
        }
        if let stalledObserver {
            NotificationCenter.default.removeObserver(stalledObserver)
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
