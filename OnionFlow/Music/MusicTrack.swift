import Foundation

// 当前加载曲目的轻量模型；metadata 缺失时回退到常见的“歌名 - 歌手”文件名格式。
struct MusicTrack: Equatable {
    let url: URL
    let title: String
    let artist: String?
    let duration: TimeInterval

    init(url: URL, duration: TimeInterval, metadataTitle: String? = nil, metadataArtist: String? = nil) {
        self.url = url
        let filename = url.deletingPathExtension().lastPathComponent
        let parsedName = Self.parseFilename(filename)

        let initialTitle = Self.nonEmpty(metadataTitle) ?? parsedName.title
        let initialArtist = Self.nonEmpty(metadataArtist) ?? parsedName.artist

        // 智能纠偏：如果音频文件的 ID3 标签写入有误，导致歌手与歌名颠倒（即 Artist 标签等于文件名/歌名，而 Title 标签反而等于歌手名），自动进行互换纠正
        if let metaArtist = Self.nonEmpty(metadataArtist),
           let metaTitle = Self.nonEmpty(metadataTitle) {
            let normalizedFilename = parsedName.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedMetaArtist = metaArtist.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedMetaTitle = metaTitle.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

            if normalizedMetaArtist == normalizedFilename && normalizedMetaTitle != normalizedFilename {
                // 歌手标签匹配了文件名（实际歌名），而歌名标签并非该名字，说明标签写反了，在此进行互换
                self.title = metaArtist
                self.artist = metaTitle
                self.duration = duration
                return
            }
        }

        self.title = initialTitle
        self.artist = initialArtist
        self.duration = duration
    }

    var onlineSearchQuery: String {
        [artist, title].compactMap { $0 }.joined(separator: " ")
    }

    private static func parseFilename(_ filename: String) -> (artist: String?, title: String) {
        let separators = [" - ", " – ", " — "]
        for separator in separators {
            let components = filename.components(separatedBy: separator)
            if components.count >= 2,
               let title = nonEmpty(components.first),
               let artist = nonEmpty(components.dropFirst().joined(separator: separator)) {
                return (artist, title)
            }
        }
        return (nil, filename)
    }

    private static func nonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }
}
