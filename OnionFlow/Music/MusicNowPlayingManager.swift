import Foundation
import MediaPlayer

/// 桥接苹果 MediaPlayer 框架的系统级媒体管理器，用于同步播放信息（以支持 Siri、控制中心、多媒体键及锁屏）并响应系统级播控指令。
@MainActor
final class MusicNowPlayingManager {
    private weak var viewModel: MusicPlayerViewModel?
    private var commandTargets: [(MPRemoteCommand, Any)] = []

    init(viewModel: MusicPlayerViewModel) {
        self.viewModel = viewModel
        setupRemoteCommands()
    }

    deinit {
        let targets = commandTargets
        Task { @MainActor in
            for (command, target) in targets {
                command.removeTarget(target)
            }
        }
    }

    /// 注册系统媒体控制器的监听指令
    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        // 1. 播放命令
        let playTarget = commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            self.viewModel?.play()
            return .success
        }
        commandCenter.playCommand.isEnabled = true
        commandTargets.append((commandCenter.playCommand, playTarget))

        // 2. 暂停命令
        let pauseTarget = commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            self.viewModel?.pause()
            return .success
        }
        commandCenter.pauseCommand.isEnabled = true
        commandTargets.append((commandCenter.pauseCommand, pauseTarget))

        // 3. 播放/暂停切换键
        let toggleTarget = commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            self.viewModel?.togglePlayPause()
            return .success
        }
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandTargets.append((commandCenter.togglePlayPauseCommand, toggleTarget))

        // 4. 下一首
        let nextTarget = commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            self.viewModel?.playNextTrack(isUserInitiated: true)
            return .success
        }
        commandCenter.nextTrackCommand.isEnabled = true
        commandTargets.append((commandCenter.nextTrackCommand, nextTarget))

        // 5. 上一首
        let prevTarget = commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            self.viewModel?.playPreviousTrack()
            return .success
        }
        commandCenter.previousTrackCommand.isEnabled = true
        commandTargets.append((commandCenter.previousTrackCommand, prevTarget))

        // 6. 进度条拖动（系统控制中心/锁屏进度条）
        let positionTarget = commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self,
                  let posEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self.viewModel?.seekToSeconds(posEvent.positionTime)
            return .success
        }
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandTargets.append((commandCenter.changePlaybackPositionCommand, positionTarget))
    }

    /// 同步最新的播放信息至系统 Now Playing 控制器
    /// - Parameters:
    ///   - track: 当前播放的曲目模型
    ///   - isPlaying: 播放状态（true 为正在播放，false 为已暂停/加载中）
    ///   - currentTime: 当前已播放的秒数
    ///   - duration: 曲目的总秒数
    func updateNowPlaying(
        track: MusicTrack?,
        isPlaying: Bool,
        currentTime: TimeInterval,
        duration: TimeInterval
    ) {
        let infoCenter = MPNowPlayingInfoCenter.default()

        guard let track = track else {
            infoCenter.nowPlayingInfo = nil
            return
        }

        var nowPlayingInfo = [String: Any]()

        // 同步基本元数据
        nowPlayingInfo[MPMediaItemPropertyTitle] = track.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = track.artist ?? "未知歌手"
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        
        // 同步进度与速率（iOS/macOS 会根据 playbackRate 自动进行时间插值计算，无需每秒推送进度）
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        infoCenter.nowPlayingInfo = nowPlayingInfo
    }
}
