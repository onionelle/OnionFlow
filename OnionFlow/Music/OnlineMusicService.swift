import Foundation

struct OnlineMusicUserSession {
    let userId: String
    let nickname: String?
    let playlists: [NeteaseUserPlaylist]
}

enum OnlineMusicServiceError: LocalizedError {
    case unavailableStreamURL

    var errorDescription: String? {
        switch self {
        case .unavailableStreamURL:
            return "获取播放链接失败"
        }
    }
}

/// 在线音乐服务层只负责网易云请求与下载触发，播放状态仍由 MusicPlayerViewModel 编排。
struct OnlineMusicService {
    func loadUserSession() async throws -> OnlineMusicUserSession? {
        let status = try await NeteaseAPIClient.shared.fetchLoginStatus()
        guard let profile = status.profile else { return nil }

        let userId = String(profile.userId)
        let playlistsResponse = try await NeteaseAPIClient.shared.fetchUserPlaylists(uid: userId)
        return OnlineMusicUserSession(
            userId: userId,
            nickname: profile.nickname,
            playlists: playlistsResponse.playlist ?? []
        )
    }

    func streamURL(for song: NeteaseSong) async throws -> URL {
        let response = try await NeteaseAPIClient.shared.fetchSongURL(id: "\(song.id)")
        guard let urlString = response.data?.first?.url,
              let url = URL(string: urlString.replacingOccurrences(of: "http://", with: "https://")) else {
            throw OnlineMusicServiceError.unavailableStreamURL
        }
        return url
    }

    @MainActor
    func autoDownloadOnPlayIfNeeded(song: NeteaseSong) {
        guard UserDefaults.standard.bool(forKey: "autoDownloadOnPlay") else { return }
        Task {
            try? await OnlineDownloadManager.shared.download(song: song)
        }
    }
}
