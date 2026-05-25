import Foundation

// 播放器状态只描述状态本身；曲目和播放列表数据放在 ViewModel。
enum MusicPlayerState: Equatable {
    case idle
    case loading
    case playing
    case paused
    case failed(String)
}
