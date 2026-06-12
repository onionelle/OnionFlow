import Foundation

// 播放列表模式：顺序、单曲循环、列表循环、随机。rawValue 用于播放列表持久化，修改时需兼容旧值。
enum MusicPlaybackMode: String, CaseIterable, Codable, Equatable {
    case singleLoop
    case loop
    case shuffle

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        if value == "order" {
            self = .loop
        } else if let mode = MusicPlaybackMode(rawValue: value) {
            self = mode
        } else {
            self = .loop
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}
