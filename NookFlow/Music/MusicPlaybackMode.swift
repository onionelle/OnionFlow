import Foundation

// 播放列表模式：顺序、单曲循环、列表循环、随机。rawValue 用于播放列表持久化，修改时需兼容旧值。
enum MusicPlaybackMode: String, CaseIterable, Codable, Equatable {
    case order
    case singleLoop
    case loop
    case shuffle
}
