import CryptoKit
import Foundation

struct OnlineLyricsCandidate: Identifiable, Equatable {
    let id: Int
    let title: String
    let artists: [String]
    let album: String?

    var artistText: String {
        artists.isEmpty ? "未知歌手" : artists.joined(separator: " / ")
    }

    var detailText: String {
        guard let album, !album.isEmpty else { return artistText }
        return "\(artistText) - \(album)"
    }
}

enum OnlineLyricsResult {
    case lyrics([LyricLine])
    case candidates([OnlineLyricsCandidate])
    case noLyrics
    case failed(String)
}

enum LyricsSearchMode {
    case automatic
    case userSelection
}

/// 歌词读取和联网检索服务。只有用户允许后，ViewModel 才调用在线方法。
final class LyricsService {
    private let fileManager = FileManager.default
    private let cacheDirectoryURL: URL

    init() {
        let supportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        // V2 缓存只写入高可信或用户确认结果，避免沿用旧版自动首条匹配产生的错误歌词。
        cacheDirectoryURL = supportDir
            .appendingPathComponent("OnionFlow", isDirectory: true)
            .appendingPathComponent("LyricsCacheV2", isDirectory: true)
        try? fileManager.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true)
    }

    /// 读取不会产生网络访问的歌词来源：同目录 LRC 优先，其次为已确认缓存。
    func loadStoredLyrics(for track: MusicTrack) -> [LyricLine]? {
        if let localText = loadLocalLrc(for: track.url) {
            return parsedLines(from: localText)
        }
        guard let cachedText = try? String(contentsOf: cacheURL(for: track), encoding: .utf8) else {
            return nil
        }
        return parsedLines(from: cachedText)
    }

    /// 用户显式选取的 LRC 会复制为当前歌曲缓存，之后不再依赖原文件权限。
    func importLyricsFile(_ lrcURL: URL, for track: MusicTrack) -> [LyricLine]? {
        let didStartAccess = lrcURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                lrcURL.stopAccessingSecurityScopedResource()
            }
        }
        guard let text = try? String(contentsOf: lrcURL, encoding: .utf8),
              let lines = parsedLines(from: text) else {
            return nil
        }
        cache(text, for: track)
        return lines
    }

    /// 首次加载只自动下载高可信结果；用户发起重新匹配或低可信结果始终返回候选供确认。
    func searchOnlineLyrics(for track: MusicTrack, mode: LyricsSearchMode = .automatic) async -> OnlineLyricsResult {
        do {
            // 第一路：标准化查询（Title - Artist 或文件名）
            var candidates = try await searchCandidates(query: track.onlineSearchQuery)

            // 第二路：单纯标题模糊搜索（Title）
            if track.onlineSearchQuery != track.title {
                let fuzzyCandidates = try await searchCandidates(query: track.title)
                let additionalCandidates = fuzzyCandidates.filter { fuzzy in
                    !candidates.contains(where: { $0.id == fuzzy.id })
                }
                candidates.append(contentsOf: additionalCandidates)
            }

            guard !candidates.isEmpty else { return .noLyrics }

            // 根据融合度（含歌手比对与歌名保底）从高到低排序，将最佳匹配推荐在首位。
            let sortedCandidates = candidates.sorted { first, second in
                similarityScore(for: first, track: track) > similarityScore(for: second, track: track)
            }

            if mode == .automatic {
                if let bestCandidate = sortedCandidates.first,
                   isTrustedMatch(bestCandidate, for: track) {
                    let downloadResult = await downloadLyrics(for: bestCandidate, track: track)
                    if case .lyrics = downloadResult {
                        return downloadResult
                    }
                }
            }

            // 重新匹配、低可信自动匹配或自动下载失败时，回退到候选列表供用户手动选择。
            return .candidates(sortedCandidates)
        } catch {
            return .failed("网络请求失败，请稍后重试")
        }
    }

    func downloadLyrics(for candidate: OnlineLyricsCandidate, track: MusicTrack) async -> OnlineLyricsResult {
        do {
            guard let text = try await requestLyrics(songID: candidate.id),
                  let lines = parsedLines(from: text) else {
                return .noLyrics
            }
            cache(text, for: track)
            return .lyrics(lines)
        } catch {
            return .failed("歌词下载失败，请稍后重试")
        }
    }

    private func loadLocalLrc(for trackURL: URL) -> String? {
        let lrcURL = trackURL.deletingPathExtension().appendingPathExtension("lrc")
        let isTrackScoped = trackURL.startAccessingSecurityScopedResource()
        defer {
            if isTrackScoped {
                trackURL.stopAccessingSecurityScopedResource()
            }
        }
        guard fileManager.fileExists(atPath: lrcURL.path) else { return nil }
        return try? String(contentsOf: lrcURL, encoding: .utf8)
    }

    private func searchCandidates(query: String) async throws -> [OnlineLyricsCandidate] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty,
              var components = URLComponents(string: "https://music.163.com/api/search/get/web") else {
            return []
        }
        components.queryItems = [
            URLQueryItem(name: "s", value: cleanQuery),
            URLQueryItem(name: "type", value: "1")
        ]
        guard let url = components.url else { return [] }
        let data = try await requestData(from: url)
        let response = try JSONDecoder().decode(SearchResponse.self, from: data)
        return (response.result?.songs ?? []).map {
            OnlineLyricsCandidate(
                id: $0.id,
                title: $0.name,
                artists: ($0.artists ?? []).map(\.name),
                album: $0.album?.name
            )
        }
    }

    private func requestLyrics(songID: Int) async throws -> String? {
        guard var components = URLComponents(string: "https://music.163.com/api/song/lyric") else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "os", value: "pc"),
            URLQueryItem(name: "id", value: String(songID)),
            URLQueryItem(name: "lv", value: "-1"),
            URLQueryItem(name: "kv", value: "-1"),
            URLQueryItem(name: "tv", value: "-1")
        ]
        guard let url = components.url else { return nil }
        let data = try await requestData(from: url)
        return try JSONDecoder().decode(LyricResponse.self, from: data).lrc?.lyric
    }

    private func requestData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    private func isTrustedMatch(_ candidate: OnlineLyricsCandidate, for track: MusicTrack) -> Bool {
        guard let artist = track.artist else { return false }

        // 1. 歌名比对：两边都先进行通配去噪清洗（去除前导轨道号、中英文括号内容），然后再进行规范化等值比较
        let cleanLocalTitle = normalize(cleanTitleForFuzzySearch(track.title))
        let cleanCandidateTitle = normalize(cleanTitleForFuzzySearch(candidate.title))
        guard cleanLocalTitle == cleanCandidateTitle else { return false }

        // 2. 歌手比对：
        let normalizedLocalArtist = normalize(artist)
        let normalizedCandidateArtists = candidate.artists.map(normalize)

        // 情况 A：单歌手名刚好完全匹配云端组中的某一个成员
        if normalizedCandidateArtists.contains(normalizedLocalArtist) {
            return true
        }

        // 情况 B：多歌手合唱兼容。如果本地是长合唱串，判断它是否同时包含了云端的所有合唱歌手名字
        let matchedCount = normalizedCandidateArtists.filter { normalizedLocalArtist.contains($0) }.count
        if matchedCount > 0 && matchedCount == normalizedCandidateArtists.count {
            return true
        }

        return false
    }

    private func normalize(_ value: String) -> String {
        value.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }

    private func similarityScore(for candidate: OnlineLyricsCandidate, track: MusicTrack) -> Double {
        let trackTitleNorm = normalize(track.title)
        let candidateTitleNorm = normalize(candidate.title)

        let trackTitleWords = getNormalizedWords(track.title)
        let candidateTitleWords = getNormalizedWords(candidate.title)
        let titleSimilarity = jaccardSimilarity(between: trackTitleWords, and: candidateTitleWords)

        let artistSimilarity: Double
        if let artist = track.artist {
            let trackArtistWords = getNormalizedWords(artist)
            let candidateArtistWords = candidate.artists.flatMap(getNormalizedWords)
            artistSimilarity = jaccardSimilarity(between: trackArtistWords, and: candidateArtistWords)
        } else {
            // 如果歌曲没有歌手信息，根据候选者是否有歌手返回相应基准分，避免漏掉匹配
            artistSimilarity = candidate.artists.isEmpty ? 1.0 : 0.5
        }

        var score = titleSimilarity * 0.7 + artistSimilarity * 0.3

        // 针对完全一致的字段进行精准比对加成，确保更符合预期的候选胜出
        if trackTitleNorm == candidateTitleNorm {
            score += 0.2
        }
        if let artist = track.artist {
            let trackArtistNorm = normalize(artist)
            let normalizedArtists = candidate.artists.map(normalize)
            if normalizedArtists.contains(trackArtistNorm) {
                score += 0.1
            }
        }

        return score
    }

    private func getNormalizedWords(_ string: String) -> [String] {
        string.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    private func jaccardSimilarity(between a: [String], and b: [String]) -> Double {
        let setA = Set(a)
        let setB = Set(b)
        guard !setA.isEmpty || !setB.isEmpty else { return 0.0 }
        let intersection = setA.intersection(setB)
        let union = setA.union(setB)
        return Double(intersection.count) / Double(union.count)
    }

    private func parsedLines(from text: String) -> [LyricLine]? {
        let lines = LrcParser.parse(text)
        return lines.isEmpty ? nil : lines
    }

    private func cache(_ text: String, for track: MusicTrack) {
        try? text.write(to: cacheURL(for: track), atomically: true, encoding: .utf8)
    }

    private func cacheURL(for track: MusicTrack) -> URL {
        let key = "\(track.title)_\(track.url.path)"
        let digest = SHA256.hash(data: Data(key.utf8))
        let hashString = digest.map { String(format: "%02x", $0) }.joined()
        return cacheDirectoryURL.appendingPathComponent("\(hashString).lrc")
    }

    /// 正则清洗歌名核心词，用于第三路极大模糊化通配检索，剥离轨道号前缀和括号后缀内容。
    private func cleanTitleForFuzzySearch(_ title: String) -> String {
        var cleaned = title

        // 1. 去除开头的轨道号前缀，例如 "01. "、"02 - "、"12 "
        if let regex = try? NSRegularExpression(pattern: "^\\s*\\d+[-.\\s]+", options: .caseInsensitive) {
            cleaned = regex.stringByReplacingMatches(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned), withTemplate: "")
        }

        // 2. 去除各种括号及其中的后缀内容，例如 "(Live)"、"[FLAC]"、"（1999）"、"【伴奏】"
        if let regex = try? NSRegularExpression(pattern: "\\s*\\([^)]*\\)|\\s*\\[[^]]*\\]|\\s*（[^）]*）|\\s*【[^】]*】", options: .caseInsensitive) {
            cleaned = regex.stringByReplacingMatches(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned), withTemplate: "")
        }

        // 3. 去除首尾空白字符
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct SearchResponse: Decodable {
    struct Result: Decodable {
        let songs: [Song]?
    }

    struct Song: Decodable {
        struct Artist: Decodable {
            let name: String
        }

        struct Album: Decodable {
            let name: String
        }

        let id: Int
        let name: String
        let artists: [Artist]?
        let album: Album?
    }

    let result: Result?
}

private struct LyricResponse: Decodable {
    struct Lrc: Decodable {
        let lyric: String?
    }

    let lrc: Lrc?
}
