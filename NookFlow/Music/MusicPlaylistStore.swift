import Foundation

struct MusicPlaylistSnapshot {
    let playlist: [URL]
    let currentIndex: Int?
    let playbackMode: MusicPlaybackMode
    let currentTrackProgress: TimeInterval?
    let volume: Double?
}

// 只保存轻量播放列表状态，不保存音频 metadata，避免把当前阶段扩成资料库。
struct MusicPlaylistStore {
    private let fileManager: FileManager
    private let storageURL: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let supportDirectory = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        self.storageURL = supportDirectory
            .appendingPathComponent("NookFlow", isDirectory: true)
            .appendingPathComponent("playlist.json")
    }

    func load() -> MusicPlaylistSnapshot? {
        guard let data = try? Data(contentsOf: storageURL) else { return nil }
        guard let storedSnapshot = try? JSONDecoder().decode(StoredMusicPlaylistSnapshot.self, from: data) else {
            return nil
        }
        let playlist = storedSnapshot.playlist.compactMap(resolveURL)
        return MusicPlaylistSnapshot(
            playlist: playlist,
            currentIndex: storedSnapshot.currentIndex,
            playbackMode: storedSnapshot.playbackMode,
            currentTrackProgress: storedSnapshot.currentTrackProgress,
            volume: storedSnapshot.volume
        )
    }

    func save(_ snapshot: MusicPlaylistSnapshot) {
        do {
            let directoryURL = storageURL.deletingLastPathComponent()
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
            let storedSnapshot = StoredMusicPlaylistSnapshot(
                playlist: snapshot.playlist.map(makeEntry),
                currentIndex: snapshot.currentIndex,
                playbackMode: snapshot.playbackMode,
                currentTrackProgress: snapshot.currentTrackProgress,
                volume: snapshot.volume
            )
            let data = try JSONEncoder().encode(storedSnapshot)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            // 持久化失败不应影响播放；下次用户操作会再次尝试保存。
        }
    }

    private func resolveURL(from entry: StoredMusicPlaylistEntry) -> URL? {
        if let bookmarkData = entry.bookmarkData {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                return url
            }
        }
        return URL(string: entry.url)
    }

    private func makeEntry(for url: URL) -> StoredMusicPlaylistEntry {
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let bookmarkData = try? url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        return StoredMusicPlaylistEntry(
            url: url.absoluteString,
            bookmarkData: bookmarkData
        )
    }
}

private struct StoredMusicPlaylistSnapshot: Codable {
    let playlist: [StoredMusicPlaylistEntry]
    let currentIndex: Int?
    let playbackMode: MusicPlaybackMode
    let currentTrackProgress: TimeInterval?
    let volume: Double?

    private enum CodingKeys: String, CodingKey {
        case playlist
        case currentIndex
        case playbackMode
        case currentTrackProgress
        case volume
    }

    init(
        playlist: [StoredMusicPlaylistEntry],
        currentIndex: Int?,
        playbackMode: MusicPlaybackMode,
        currentTrackProgress: TimeInterval?,
        volume: Double?
    ) {
        self.playlist = playlist
        self.currentIndex = currentIndex
        self.playbackMode = playbackMode
        self.currentTrackProgress = currentTrackProgress
        self.volume = volume
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let entries = try? container.decode([StoredMusicPlaylistEntry].self, forKey: .playlist) {
            playlist = entries
        } else {
            // 兼容早期只保存 URL 字符串 of playlist.json；新保存会补写 security-scoped bookmark。
            let urls = try container.decode([String].self, forKey: .playlist)
            playlist = urls.map {
                StoredMusicPlaylistEntry(url: $0, bookmarkData: nil)
            }
        }
        currentIndex = try container.decodeIfPresent(Int.self, forKey: .currentIndex)
        playbackMode = try container.decode(MusicPlaybackMode.self, forKey: .playbackMode)
        currentTrackProgress = try container.decodeIfPresent(TimeInterval.self, forKey: .currentTrackProgress)
        volume = try container.decodeIfPresent(Double.self, forKey: .volume)
    }
}

private struct StoredMusicPlaylistEntry: Codable {
    let url: String
    let bookmarkData: Data?
}
