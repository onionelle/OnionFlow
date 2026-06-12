import Foundation
import CommonCrypto

// MARK: - Crypto Extensions

extension String {
    var md5: String {
        let length = Int(CC_MD5_DIGEST_LENGTH)
        var digest = [UInt8](repeating: 0, count: length)
        
        if let d = self.data(using: .utf8) {
            _ = d.withUnsafeBytes { body -> String in
                CC_MD5(body.baseAddress, CC_LONG(d.count), &digest)
                return ""
            }
        }
        
        return (0..<length).reduce("") {
            $0 + String(format: "%02x", digest[$1])
        }
    }
}

// MARK: - NeteaseAPIClient

class NeteaseAPIClient {
    static let shared = NeteaseAPIClient()
    private let baseURL = "https://interface3.music.163.com"
    private let eapiKey = "e82ckenh8dichen8"
    
    private init() {}
    
    /// 获取当前存储的 Cookie
    private var cookieString: String? {
        let rawCookie = UserDefaults.standard.string(forKey: "NeteaseCookie")?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let raw = rawCookie, !raw.isEmpty {
            return raw
        }
        return nil
    }
    
    /// AES-128-ECB 加密
    private func eapiEncrypt(text: String) -> String? {
        guard let data = text.data(using: .utf8),
              let keyData = eapiKey.data(using: .utf8) else { return nil }
        
        let keyLength = kCCKeySizeAES128
        let dataLength = data.count
        
        let bufferSize = dataLength + kCCBlockSizeAES128
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        var numBytesEncrypted: size_t = 0
        
        let cryptStatus = CCCrypt(
            CCOperation(kCCEncrypt),
            CCAlgorithm(kCCAlgorithmAES128),
            CCOptions(kCCOptionPKCS7Padding | kCCOptionECBMode),
            (keyData as NSData).bytes, keyLength,
            nil,
            (data as NSData).bytes, dataLength,
            &buffer, bufferSize,
            &numBytesEncrypted
        )
        
        if cryptStatus == kCCSuccess {
            let encryptedData = Data(bytes: buffer, count: numBytesEncrypted)
            return encryptedData.map { String(format: "%02X", $0) }.joined()
        }
        
        return nil
    }
    
    /// AES-128-ECB 解密
    private func eapiDecrypt(data: Data) -> Data? {
        guard let keyData = eapiKey.data(using: .utf8) else { return nil }
        
        let keyLength = kCCKeySizeAES128
        let dataLength = data.count
        
        let bufferSize = dataLength + kCCBlockSizeAES128
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        var numBytesDecrypted: size_t = 0
        
        let cryptStatus = CCCrypt(
            CCOperation(kCCDecrypt),
            CCAlgorithm(kCCAlgorithmAES128),
            CCOptions(kCCOptionPKCS7Padding | kCCOptionECBMode),
            (keyData as NSData).bytes, keyLength,
            nil,
            (data as NSData).bytes, dataLength,
            &buffer, bufferSize,
            &numBytesDecrypted
        )
        
        if cryptStatus == kCCSuccess {
            return Data(bytes: buffer, count: numBytesDecrypted)
        }
        
        return nil
    }
    
    /// 构造 eAPI 请求数据
    private func buildEAPIData(urlPath: String, parameters: [String: Any]) -> Data? {
        let sigPath = urlPath.replacingOccurrences(of: "/eapi/", with: "/api/")
        guard let jsonData = try? JSONSerialization.data(withJSONObject: parameters, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return nil }
        
        let message = "nobody\(sigPath)use\(jsonString)md5forencrypt"
        let digest = message.md5
        let dataToEncrypt = "\(sigPath)-36cd479b6b5-\(jsonString)-36cd479b6b5-\(digest)"
        
        guard let encryptedHex = eapiEncrypt(text: dataToEncrypt) else { return nil }
        
        // eAPI 只需要把 params=加密字符串 传上去即可
        var components = URLComponents()
        components.queryItems = [URLQueryItem(name: "params", value: encryptedHex)]
        return components.query?.data(using: .utf8)
    }
    
    /// 发送 eAPI 请求
    private func requestEAPI<T: Decodable>(urlPath: String, parameters: [String: Any]) async throws -> T {
        let fullURL = URL(string: baseURL + urlPath)!
        var request = URLRequest(url: fullURL)
        request.httpMethod = "POST"
        
        // 伪装头部
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("https://music.163.com/", forHTTPHeaderField: "Referer")
        
        // Cookie 注入（优先用户填写的 Cookie，如果没有则提供一个基础的访客 OS 标识）
        let cookie = cookieString ?? "os=pc; osver=Mac OS X 10.15.7; appver=3.0.0"
        request.setValue(cookie, forHTTPHeaderField: "Cookie")
        
        // eAPI 需要把 Cookie 等一些环境参数也丢进请求体里面作为 header
        var eapiParams = parameters
        eapiParams["header"] = [
            "os": "pc",
            "appver": "3.0.0",
            "cookie": cookie
        ]
        
        guard let bodyData = buildEAPIData(urlPath: urlPath, parameters: eapiParams) else {
            throw URLError(.badURL)
        }
        request.httpBody = bodyData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("=== [requestEAPI] Response String (first 1000 chars) ===")
            print(String(responseString.prefix(1000)))
        } else {
            print("=== [requestEAPI] Response data is not a UTF-8 string, size: \(data.count) bytes ===")
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }
}

// MARK: - API 接口实现
extension NeteaseAPIClient {
    
    /// 获取榜单 (新歌榜: 3779629, 热歌榜: 3778678, 飙歌榜: 19723756)
    func fetchPlaylistDetail(id: String) async throws -> NeteasePlaylistDetailResponse {
        let timestamp = Int(Date().timeIntervalSince1970)
        let publicURL = URL(string: "https://music.163.com/api/v3/playlist/detail?id=\(id)&n=10000&t=\(timestamp)")!
        var req = URLRequest(url: publicURL)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        if let cookie = cookieString {
            req.setValue(cookie, forHTTPHeaderField: "Cookie")
        }
        
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(NeteasePlaylistDetailResponse.self, from: data)
    }
    
    /// 获取每日推荐歌曲 (需要登录 Cookie)
    func fetchRecommendSongs() async throws -> NeteaseRecommendSongsResponse {
        return try await requestEAPI(urlPath: "/eapi/v3/discovery/recommend/songs", parameters: [:])
    }
    
    /// 获取歌曲播放/下载直链
    func fetchSongURL(id: String, level: String = "lossless") async throws -> NeteaseSongURLResponse {
        // 1. 尝试使用 eAPI (可能因为无 Cookie 或无版权而失败)
        let params: [String: Any] = ["ids": "[\(id)]", "level": level, "encodeType": "flac"]
        do {
            let res: NeteaseSongURLResponse = try await requestEAPI(urlPath: "/eapi/song/enhance/player/url/v1", parameters: params)
            if res.code == 200, let url = res.data?.first?.url, !url.isEmpty {
                print("=== [NeteaseAPIClient] eAPI Succeeded ===")
                print("  URL: \(url)")
                print("  Level: \(res.data?.first?.level ?? "nil")")
                print("  Size: \(res.data?.first?.size ?? 0) bytes")
                return res
            } else {
                print("=== [NeteaseAPIClient] eAPI Succeeded but payload invalid ===")
                print("  Code: \(res.code)")
                print("  Data is nil or empty: \(res.data == nil || res.data?.isEmpty == true)")
                if let first = res.data?.first {
                    print("    First Item ID: \(first.id)")
                    print("    First Item URL: \(first.url ?? "nil")")
                    print("    First Item Level: \(first.level ?? "nil")")
                }
            }
        } catch {
            print("=== [NeteaseAPIClient] eAPI request threw error: \(error) ===")
        }
        
        print("=== [NeteaseAPIClient] eAPI Failed, falling back to public API ===")
        
        // 2. 降级回滚到无需 Cookie 的公开 API (标准音质 320k)
        let publicURL = URL(string: "https://music.163.com/api/song/enhance/player/url?id=\(id)&ids=[\(id)]&br=320000")!
        var req = URLRequest(url: publicURL)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(NeteaseSongURLResponse.self, from: data)
    }
    
    /// 获取当前登录账号状态与 UID (需要登录 Cookie)
    func fetchLoginStatus() async throws -> NeteaseAccountStatusResponse {
        guard let cookie = cookieString else {
            throw URLError(.userAuthenticationRequired)
        }
        let url = URL(string: "https://music.163.com/api/w/nuser/account/get")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        req.setValue(cookie, forHTTPHeaderField: "Cookie")
        req.setValue("https://music.163.com/", forHTTPHeaderField: "Referer")
        
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(NeteaseAccountStatusResponse.self, from: data)
    }
    
    /// 获取用户的个人歌单列表 (需要登录 Cookie)
    func fetchUserPlaylists(uid: String) async throws -> NeteaseUserPlaylistsResponse {
        guard let cookie = cookieString else {
            throw URLError(.userAuthenticationRequired)
        }
        let url = URL(string: "https://music.163.com/api/user/playlist?uid=\(uid)&limit=50")!
        var req = URLRequest(url: url)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        req.setValue(cookie, forHTTPHeaderField: "Cookie")
        req.setValue("https://music.163.com/", forHTTPHeaderField: "Referer")
        
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(NeteaseUserPlaylistsResponse.self, from: data)
    }
    
    /// 获取相似歌曲推荐
    func fetchSimiSongs(songId: String) async throws -> NeteaseSimiSongsResponse {
        let url = URL(string: "https://music.163.com/api/v1/discovery/simiSong?songid=\(songId)")!
        var req = URLRequest(url: url)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        req.setValue("https://music.163.com/", forHTTPHeaderField: "Referer")
        
        if let cookie = cookieString {
            req.setValue(cookie, forHTTPHeaderField: "Cookie")
        }
        
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(NeteaseSimiSongsResponse.self, from: data)
    }
    
    /// 搜索歌曲 (云音乐搜索接口)
    func searchSongs(query: String) async throws -> [NeteaseSong] {
        let url = URL(string: "https://music.163.com/api/cloudsearch/pc")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Safari/537.36 Chrome/91.0.4472.164 NeteaseMusicDesktop/2.10.2.200154", forHTTPHeaderField: "User-Agent")
        request.addValue("https://music.163.com/", forHTTPHeaderField: "Referer")
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        if let cookie = cookieString {
            request.addValue(cookie, forHTTPHeaderField: "Cookie")
        }
        
        let bodyString = "s=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&type=1&limit=30"
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "NeteaseAPIClient", code: 2, userInfo: [NSLocalizedDescriptionKey: "HTTP error"])
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let songs = result["songs"] as? [[String: Any]] else {
            return []
        }
        
        var neteaseSongs: [NeteaseSong] = []
        for song in songs {
            if let id = song["id"] as? Int,
               let name = song["name"] as? String {
                var parsedArtists: [NeteaseArtist] = []
                if let ar = song["ar"] as? [[String: Any]] {
                    for artist in ar {
                        if let artistId = artist["id"] as? Int,
                           let artistName = artist["name"] as? String {
                            parsedArtists.append(NeteaseArtist(id: artistId, name: artistName))
                        }
                    }
                }
                
                var parsedAlbum: NeteaseAlbum? = nil
                if let al = song["al"] as? [String: Any],
                   let albumId = al["id"] as? Int,
                   let albumName = al["name"] as? String {
                    parsedAlbum = NeteaseAlbum(id: albumId, name: albumName, picUrl: al["picUrl"] as? String)
                }
                
                let dt = song["dt"] as? Int
                
                neteaseSongs.append(NeteaseSong(
                    id: id,
                    name: name,
                    ar: parsedArtists,
                    al: parsedAlbum,
                    dt: dt
                ))
            }
        }
        return neteaseSongs
    }
}
