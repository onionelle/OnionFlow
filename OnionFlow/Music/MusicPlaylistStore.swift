import Foundation

struct MusicPlaylistSnapshot {
    let playlist: [URL]
    let currentIndex: Int?
    let playbackMode: MusicPlaybackMode
    let currentTrackProgress: TimeInterval?
    let volume: Double?
    let isPlaying: Bool?
    let failedLocalURLs: Set<URL>?
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
            .appendingPathComponent("OnionFlow", isDirectory: true)
            .appendingPathComponent("playlist.json")
    }

    func load() -> MusicPlaylistSnapshot? {
        guard fileManager.fileExists(atPath: storageURL.path) else { return nil }
        let storedSnapshot: StoredMusicPlaylistSnapshot
        do {
            let data = try Data(contentsOf: storageURL)
            storedSnapshot = try JSONDecoder().decode(StoredMusicPlaylistSnapshot.self, from: data)
        } catch {
            DiagnosticLogService.shared.log("playlist.load.failed", [
                "error": error.localizedDescription
            ])
            return nil
        }
        let resolvedEntries = storedSnapshot.playlist.enumerated().compactMap { entry -> (originalIndex: Int, url: URL)? in
            guard let url = resolveURL(from: entry.element) else { return nil }
            return (entry.offset, url)
        }
        let playlist = resolvedEntries.map(\.url)
        let restoredCurrentIndex = storedSnapshot.currentIndex.flatMap { storedIndex in
            resolvedEntries.firstIndex { $0.originalIndex == storedIndex }
        }
        var failedLocalURLs: Set<URL> = []
        if let storedFailed = storedSnapshot.failedLocalURLs {
            let failedStrings = Set(storedFailed)
            for url in playlist {
                if failedStrings.contains(url.absoluteString) {
                    failedLocalURLs.insert(url)
                }
            }
        }

        return MusicPlaylistSnapshot(
            playlist: playlist,
            currentIndex: restoredCurrentIndex,
            playbackMode: storedSnapshot.playbackMode,
            currentTrackProgress: storedSnapshot.currentTrackProgress,
            volume: storedSnapshot.volume,
            isPlaying: storedSnapshot.isPlaying,
            failedLocalURLs: failedLocalURLs
        )
    }

    func save(_ snapshot: MusicPlaylistSnapshot, currentlyAccessingURL: URL? = nil) {
        do {
            let directoryURL = storageURL.deletingLastPathComponent()
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )

            let storedSnapshot = StoredMusicPlaylistSnapshot(
                playlist: snapshot.playlist.map { makeEntry(for: $0, currentlyAccessingURL: currentlyAccessingURL) },
                currentIndex: snapshot.currentIndex,
                playbackMode: snapshot.playbackMode,
                currentTrackProgress: snapshot.currentTrackProgress,
                volume: snapshot.volume,
                isPlaying: snapshot.isPlaying,
                failedLocalURLs: snapshot.failedLocalURLs?.map { $0.absoluteString },
                failedOnlineSongIDs: nil,
                onlineSongFailureMessages: nil
            )
            let data = try JSONEncoder().encode(storedSnapshot)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            DiagnosticLogService.shared.log("playlist.save.failed", [
                "error": error.localizedDescription
            ])
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
            DiagnosticLogService.shared.log("playlist.bookmark.resolve_failed", [
                "url": entry.url
            ])
        }
        return URL(string: entry.url)
    }

    private func makeEntry(for url: URL, currentlyAccessingURL: URL?) -> StoredMusicPlaylistEntry {
        // 正在播放的文件已经由播放器持有 security-scoped 访问。若这里再 start 后 stop，
        // 会把播放权限一起关掉，下一秒 AVPlayer 就会报资源暂时不可用。
        if let bookmarkData = try? url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            return StoredMusicPlaylistEntry(url: url.absoluteString, bookmarkData: bookmarkData)
        }

        let didStartAccess = url.startAccessingSecurityScopedResource()
        let bookmarkData = try? url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        // startAccessing 不是引用计数：对正在播放的 URL 再 stop，会连播放器的权限一起撤掉。
        if didStartAccess, !isSameLocalFile(url, as: currentlyAccessingURL) {
            url.stopAccessingSecurityScopedResource()
        }
        return StoredMusicPlaylistEntry(
            url: url.absoluteString,
            bookmarkData: bookmarkData
        )
    }

    private func isSameLocalFile(_ lhs: URL, as rhs: URL?) -> Bool {
        guard let rhs else { return false }
        return lhs.standardizedFileURL.path == rhs.standardizedFileURL.path
    }
}

private struct StoredMusicPlaylistSnapshot: Codable {
    let playlist: [StoredMusicPlaylistEntry]
    let currentIndex: Int?
    let playbackMode: MusicPlaybackMode
    let currentTrackProgress: TimeInterval?
    let volume: Double?
    let isPlaying: Bool?
    let failedLocalURLs: [String]?
    let failedOnlineSongIDs: [Int]?
    let onlineSongFailureMessages: [String: String]?

    private enum CodingKeys: String, CodingKey {
        case playlist
        case currentIndex
        case playbackMode
        case currentTrackProgress
        case volume
        case isPlaying
        case failedLocalURLs
        case failedOnlineSongIDs
        case onlineSongFailureMessages
    }

    init(
        playlist: [StoredMusicPlaylistEntry],
        currentIndex: Int?,
        playbackMode: MusicPlaybackMode,
        currentTrackProgress: TimeInterval?,
        volume: Double?,
        isPlaying: Bool?,
        failedLocalURLs: [String]?,
        failedOnlineSongIDs: [Int]?,
        onlineSongFailureMessages: [String: String]?
    ) {
        self.playlist = playlist
        self.currentIndex = currentIndex
        self.playbackMode = playbackMode
        self.currentTrackProgress = currentTrackProgress
        self.volume = volume
        self.isPlaying = isPlaying
        self.failedLocalURLs = failedLocalURLs
        self.failedOnlineSongIDs = failedOnlineSongIDs
        self.onlineSongFailureMessages = onlineSongFailureMessages
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
        isPlaying = try container.decodeIfPresent(Bool.self, forKey: .isPlaying)
        failedLocalURLs = try container.decodeIfPresent([String].self, forKey: .failedLocalURLs)
        failedOnlineSongIDs = try container.decodeIfPresent([Int].self, forKey: .failedOnlineSongIDs)
        onlineSongFailureMessages = try container.decodeIfPresent([String: String].self, forKey: .onlineSongFailureMessages)
    }
}

private struct StoredMusicPlaylistEntry: Codable {
    let url: String
    let bookmarkData: Data?
}
