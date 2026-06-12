import Foundation

/// LRC 格式歌词解析器，将包含时间标签的文本解析为有序的 LyricLine 数组。
struct LrcParser {

    /// 解析单行或整篇 LRC 格式歌词文本。
    /// - Parameter lrcText: 原始 LRC 文本内容
    /// - Returns: 按时间戳升序排序的歌词行数组
    static func parse(_ lrcText: String) -> [LyricLine] {
        var lines: [LyricLine] = []

        // 按行分割
        let rawLines = lrcText.components(separatedBy: .newlines)

        // 正则表达式匹配时间标签，例如 [00:12.34] 或 [01:05.4] 或 [02:03:45]
        // 捕获组：1. 分钟数，2. 秒数，3. 毫秒/百毫秒数（可选，前缀支持点 . 或冒号 :）
        let pattern = "\\[(\\d+):(\\d+)(?:[.:](\\d+))?\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }

        for rawLine in rawLines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            let nsString = trimmed as NSString
            let matches = regex.matches(in: trimmed, options: [], range: NSRange(location: 0, length: nsString.length))

            if matches.isEmpty {
                continue // 忽略不含时间戳的元数据行，如 [ti:Song Title]
            }

            // 一行歌词可能包含多个时间戳，例如: [00:12.34][01:05.4]歌词内容
            // 我们需要提取出最后一个时间戳后面的歌词文本
            var lyricsContent = ""
            if let lastMatch = matches.last {
                let contentStart = lastMatch.range.location + lastMatch.range.length
                if contentStart < nsString.length {
                    lyricsContent = nsString.substring(from: contentStart).trimmingCharacters(in: .whitespaces)
                }
            }

            // 解析匹配到的所有时间戳，并为每个时间戳生成一行 LyricLine
            for match in matches {
                let minStr = nsString.substring(with: match.range(at: 1))
                let secStr = nsString.substring(with: match.range(at: 2))

                guard let minutes = Double(minStr), let seconds = Double(secStr) else {
                    continue
                }

                var milliseconds: Double = 0
                if match.range(at: 3).location != NSNotFound {
                    let msStr = nsString.substring(with: match.range(at: 3))
                    if let msValue = Double(msStr) {
                        // 根据毫秒/百毫秒数字长计算实际秒数占比，例如 "34" -> 0.34, "3" -> 0.3, "340" -> 0.34
                        let count = msStr.count
                        milliseconds = msValue / pow(10.0, Double(count))
                    }
                }

                let totalTime = (minutes * 60.0) + seconds + milliseconds
                let trimmedContent = lyricsContent.trimmingCharacters(in: .whitespacesAndNewlines)
                lines.append(LyricLine(time: totalTime, text: trimmedContent))
            }
        }

        // 按照时间戳升序排序
        let sortedLines = lines.sorted { $0.time < $1.time }

        // 过滤掉连续多余的空歌词行，防止界面出现大段连续的空白区域，只保留单个空行作为必要的间奏占位
        var filteredLines: [LyricLine] = []
        for line in sortedLines {
            if line.text.isEmpty {
                if let last = filteredLines.last, last.text.isEmpty {
                    continue // 过滤连续空行
                }
            }
            filteredLines.append(line)
        }
        return filteredLines
    }
}
