import Foundation
import CommonCrypto
import CryptoKit

struct NeteaseCrypto {
    static let aesKey = "e82ckenh8dichen8".data(using: .utf8)!
    
    static func hexString(from data: Data) -> String {
        return data.map { String(format: "%02x", $0) }.joined()
    }
    
    static func md5(_ string: String) -> String {
        let digest = Insecure.MD5.hash(data: string.data(using: .utf8) ?? Data())
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    static func encryptParams(url: String, payload: [String: Any]) throws -> String {
        guard let urlPath = URL(string: url)?.path.replacingOccurrences(of: "/eapi/", with: "/api/") else {
            throw NSError(domain: "NeteaseAPI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL path"])
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
        let jsonString = String(data: jsonData, encoding: .utf8)!
        
        let digestStr = "nobody\(urlPath)use\(jsonString)md5forencrypt"
        let digest = md5(digestStr)
        
        let params = "\(urlPath)-36cd479b6b5-\(jsonString)-36cd479b6b5-\(digest)"
        let paramsData = params.data(using: .utf8)!
        
        // PKCS7 Padding
        let blockSize = kCCBlockSizeAES128
        let paddingSize = blockSize - (paramsData.count % blockSize)
        var paddedData = paramsData
        paddedData.append(contentsOf: Array(repeating: UInt8(paddingSize), count: paddingSize))
        
        let keyBytes = [UInt8](aesKey)
        let dataBytes = [UInt8](paddedData)
        
        var outBytes = [UInt8](repeating: 0, count: paddedData.count + blockSize)
        var outLength = 0
        
        let status = CCCrypt(
            CCOperation(kCCEncrypt),
            CCAlgorithm(kCCAlgorithmAES128),
            CCOptions(kCCOptionECBMode), // Note: PKCS7 padding is manually applied above because kCCOptionPKCS7Padding with ECB might be tricky or we can just use 0 if we padded manually
            keyBytes, kCCKeySizeAES128,
            nil, // no IV for ECB
            dataBytes, dataBytes.count,
            &outBytes, outBytes.count,
            &outLength
        )
        
        guard status == kCCSuccess else {
            throw NSError(domain: "NeteaseAPI", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "AES Encryption failed"])
        }
        
        let encryptedData = Data(bytes: outBytes, count: outLength)
        return hexString(from: encryptedData)
    }
}

class NeteaseAPI {
    static let shared = NeteaseAPI()
    private let session = URLSession.shared
    
    // Cookie string to append to requests
    var cookieStr: String {
        get {
            let userCookie = UserDefaults.standard.string(forKey: "NeteaseCookie") ?? ""
            if userCookie.isEmpty {
                return "os=pc;appver=;"
            }
            return userCookie
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "NeteaseCookie")
        }
    }
    
    func search(query: String) async throws -> [SearchResult] {
        let url = URL(string: "https://music.163.com/api/cloudsearch/pc")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Safari/537.36 Chrome/91.0.4472.164 NeteaseMusicDesktop/2.10.2.200154", forHTTPHeaderField: "User-Agent")
        request.addValue("https://music.163.com/", forHTTPHeaderField: "Referer")
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.addValue(cookieStr, forHTTPHeaderField: "Cookie")
        
        let bodyString = "s=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&type=1&limit=20"
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "NeteaseAPI", code: 2, userInfo: [NSLocalizedDescriptionKey: "HTTP error"])
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let songs = result["songs"] as? [[String: Any]] else {
            return []
        }
        
        var searchResults: [SearchResult] = []
        for song in songs {
            if let id = song["id"] as? Int,
               let name = song["name"] as? String,
               let ar = song["ar"] as? [[String: Any]] {
                let artistNames = ar.compactMap { $0["name"] as? String }.joined(separator: ", ")
                let dt = (song["dt"] as? Double) ?? 0
                searchResults.append(SearchResult(
                    id: String(id),
                    title: name,
                    uploader: artistNames,
                    duration: dt / 1000.0,
                    url: "netease:\(id)" // Custom scheme to identify Netease track
                ))
            }
        }
        return searchResults
    }
    
    func getSongUrl(id: String, quality: String = "lossless") async throws -> String {
        let apiUrl = "https://interface3.music.163.com/eapi/song/enhance/player/url/v1"
        
        let headerJson = "{\"os\":\"pc\",\"appver\":\"3.0.18.203152\",\"osver\":\"16.4\",\"deviceId\":\"pyncm!\",\"requestId\":\"\(Int.random(in: 20000000...30000000))\"}"
        let payload: [String: Any] = [
            "ids": [Int(id) ?? 0],
            "level": quality,
            "encodeType": "flac",
            "header": headerJson
        ]
        
        let params = try NeteaseCrypto.encryptParams(url: apiUrl, payload: payload)
        let bodyString = "params=\(params.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        var request = URLRequest(url: URL(string: apiUrl)!)
        request.httpMethod = "POST"
        request.addValue("Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Safari/537.36 Chrome/91.0.4472.164 NeteaseMusicDesktop/2.10.2.200154", forHTTPHeaderField: "User-Agent")
        request.addValue("https://music.163.com/", forHTTPHeaderField: "Referer")
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let finalCookie = "os=pc; appver=3.0.18.203152; " + cookieStr
        request.addValue(finalCookie, forHTTPHeaderField: "Cookie")
        
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "NeteaseAPI", code: 3, userInfo: [NSLocalizedDescriptionKey: "HTTP error"])
        }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let dataArr = json["data"] as? [[String: Any]],
           let first = dataArr.first {
            
            if let urlStr = first["url"] as? String {
                return urlStr.replacingOccurrences(of: "http://", with: "https://")
            } else if let code = first["code"] as? Int {
                if code == -110 {
                    throw NSError(domain: "NeteaseAPI", code: -110, userInfo: [NSLocalizedDescriptionKey: "Cookie 无效或该歌曲需要 VIP，请在设置中更新 Cookie。"])
                } else if code == 404 {
                    throw NSError(domain: "NeteaseAPI", code: 404, userInfo: [NSLocalizedDescriptionKey: "该歌曲在网易云已下架或无版权。"])
                } else {
                    throw NSError(domain: "NeteaseAPI", code: code, userInfo: [NSLocalizedDescriptionKey: "下载失败 (网易云错误码: \\(code))"])
                }
            } else if let codeStr = first["code"] as? String, let code = Int(codeStr) {
                if code == -110 {
                    throw NSError(domain: "NeteaseAPI", code: -110, userInfo: [NSLocalizedDescriptionKey: "Cookie 无效或该歌曲需要 VIP，请在设置中更新 Cookie。"])
                } else if code == 404 {
                    throw NSError(domain: "NeteaseAPI", code: 404, userInfo: [NSLocalizedDescriptionKey: "该歌曲在网易云已下架或无版权。"])
                } else {
                    throw NSError(domain: "NeteaseAPI", code: code, userInfo: [NSLocalizedDescriptionKey: "下载失败 (网易云错误码: \\(code))"])
                }
            }
        }
        
        throw NSError(domain: "NeteaseAPI", code: 4, userInfo: [NSLocalizedDescriptionKey: "无法获取该歌曲的下载链接。"])
    }
}
