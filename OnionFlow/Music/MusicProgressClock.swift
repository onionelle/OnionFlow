import Combine
import Foundation

/// 播放进度单独发布，避免 0.2 秒一次的时间更新把 island、Mascot 和频谱整树重绘。
@MainActor
final class MusicProgressClock: ObservableObject {
    @Published var currentTime: TimeInterval = 0
    @Published var scrubbingTime: TimeInterval? = nil
}
