import Foundation

// MARK: - API Response Wrappers

struct NeteasePlaylistDetailResponse: Codable {
    let code: Int
    let playlist: NeteasePlaylist?
}

struct NeteaseRecommendSongsResponse: Codable {
    let code: Int
    let data: NeteaseRecommendData?
}

struct NeteaseRecommendData: Codable {
    let dailySongs: [NeteaseSong]?
}

struct NeteaseSongURLResponse: Codable {
    let code: Int
    let data: [NeteaseSongURLData]?
}

// MARK: - Core Entities

struct NeteasePlaylist: Codable {
    let id: Int
    let name: String?
    let tracks: [NeteaseSong]?
}

struct NeteaseSong: Codable, Identifiable, Equatable {
    let id: Int
    let name: String
    let ar: [NeteaseArtist]?
    let al: NeteaseAlbum?
    let dt: Int?
    
    // UI Helpers
    var artistName: String {
        ar?.map { $0.name }.joined(separator: " / ") ?? "未知歌手"
    }
    var coverURL: URL? {
        if let urlStr = al?.picUrl {
            return URL(string: urlStr.replacingOccurrences(of: "http://", with: "https://"))
        }
        return nil
    }
}

struct NeteaseArtist: Codable, Equatable {
    let id: Int
    let name: String
}

struct NeteaseAlbum: Codable, Equatable {
    let id: Int
    let name: String
    let picUrl: String?
}

struct NeteaseSongURLData: Codable {
    let id: Int
    let url: String?
    let br: Int?
    let level: String?
    let size: Int?
}

// MARK: - User Playlist & Profile Models

struct NeteaseUserPlaylistsResponse: Codable {
    let code: Int?
    let playlist: [NeteaseUserPlaylist]?
}

struct NeteaseUserPlaylist: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let trackCount: Int?
}

struct NeteaseAccountStatusResponse: Codable {
    let code: Int
    let profile: NeteaseUserProfile?
}

struct NeteaseUserProfile: Codable {
    let userId: Int
    let nickname: String?
}

// MARK: - Similar Songs Models

struct NeteaseSimiSongsResponse: Codable {
    let songs: [NeteaseSimiSong]?
}

struct NeteaseSimiSong: Codable {
    let id: Int
    let name: String
    let artists: [NeteaseSimiArtist]?
    let album: NeteaseSimiAlbum?
    let duration: Int?
    
    func toNeteaseSong() -> NeteaseSong {
        let ar = artists?.map { NeteaseArtist(id: $0.id ?? 0, name: $0.name) }
        let al = album.map { NeteaseAlbum(id: $0.id ?? 0, name: $0.name ?? "", picUrl: $0.picUrl) }
        return NeteaseSong(id: id, name: name, ar: ar, al: al, dt: duration)
    }
}

struct NeteaseSimiArtist: Codable {
    let id: Int?
    let name: String
}

struct NeteaseSimiAlbum: Codable {
    let id: Int?
    let name: String?
    let picUrl: String?
}


