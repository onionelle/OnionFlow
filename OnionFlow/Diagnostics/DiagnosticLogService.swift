import AppKit
import Foundation

/// 进程级诊断日志。工程默认 MainActor 隔离，未捕获异常不在主线程，因此整类显式 nonisolated，写盘走串行队列。
nonisolated final class DiagnosticLogService: @unchecked Sendable {
    static let shared = DiagnosticLogService()

    private let queue = DispatchQueue(label: "larva.OnionFlow.diagnostics")
    private let fileManager = FileManager.default
    private let logURL: URL
    private let previousLogURL: URL
    private let maxFileBytes = 2 * 1024 * 1024
    private let timestampFormatter: ISO8601DateFormatter
    private var didInstallExceptionHandler = false

    private init() {
        let supportDirectory = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        let logsDirectory = supportDirectory
            .appendingPathComponent("OnionFlow", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
        logURL = logsDirectory.appendingPathComponent("onion-diagnostics.log")
        previousLogURL = logsDirectory.appendingPathComponent("onion-diagnostics.log.old")
        timestampFormatter = ISO8601DateFormatter()
        timestampFormatter.formatOptions = [.withInternetDateTime]
    }

    func start() {
        queue.async { [self] in
            try? fileManager.createDirectory(
                at: logURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            installExceptionHandlerIfNeeded()
            append(
                tag: "app.launch",
                fields: [
                    "version": bundleValue("CFBundleShortVersionString"),
                    "build": bundleValue("CFBundleVersion"),
                    "os": ProcessInfo.processInfo.operatingSystemVersionString,
                    "bundle": Bundle.main.bundleIdentifier ?? ""
                ]
            )
        }
    }

    func log(_ tag: String, _ fields: [String: String] = [:]) {
        guard isEnabled else { return }
        queue.async { [self] in
            append(tag: tag, fields: fields)
        }
    }

    func log(_ tag: String, url: URL, _ fields: [String: String] = [:]) {
        var merged = Self.urlFields(url)
        merged.merge(fields) { _, new in new }
        log(tag, merged)
    }

    static func urlFields(_ url: URL) -> [String: String] {
        if url.isFileURL {
            return ["filePath": url.path, "isFileURL": "true"]
        }
        return ["url": url.absoluteString, "isFileURL": "false"]
    }

    /// 退出路径必须同步落盘，否则异步写入可能来不及完成。
    func logAndFlush(_ tag: String, _ fields: [String: String] = [:]) {
        guard isEnabled else { return }
        queue.sync { [self] in
            append(tag: tag, fields: fields)
        }
    }

    func revealInFinder() {
        queue.async { [self] in
            try? fileManager.createDirectory(
                at: logURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if !fileManager.fileExists(atPath: logURL.path) {
                fileManager.createFile(atPath: logURL.path, contents: nil)
            }
            let url = logURL
            DispatchQueue.main.async {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
    }

    private var isEnabled: Bool {
        if UserDefaults.standard.object(forKey: "diagnosticLoggingEnabled") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "diagnosticLoggingEnabled")
    }

    private func installExceptionHandlerIfNeeded() {
        guard !didInstallExceptionHandler else { return }
        didInstallExceptionHandler = true
        previousUncaughtExceptionHandler = NSGetUncaughtExceptionHandler()
        NSSetUncaughtExceptionHandler { exception in
            DiagnosticLogService.shared.logUncaughtException(exception)
            previousUncaughtExceptionHandler?(exception)
        }
    }

    private func logUncaughtException(_ exception: NSException) {
        // 崩溃过程中进程可能马上退出，必须同步写入。
        queue.sync {
            let stack = exception.callStackSymbols.prefix(20).joined(separator: " > ")
            append(
                tag: "app.uncaught_exception",
                fields: [
                    "name": exception.name.rawValue,
                    "reason": exception.reason ?? "",
                    "stack": stack
                ]
            )
        }
    }

    private func append(tag: String, fields: [String: String]) {
        rotateIfNeeded()
        let timestamp = timestampFormatter.string(from: Date())
        var parts = ["\(timestamp) | [\(sanitize(tag))]"]
        for (key, value) in sanitizedFields(fields) {
            parts.append("\(key)=\(value)")
        }
        let line = parts.joined(separator: " | ") + "\n"
        guard let data = line.data(using: .utf8) else { return }
        if fileManager.fileExists(atPath: logURL.path) {
            guard let handle = try? FileHandle(forWritingTo: logURL) else { return }
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: logURL, options: .atomic)
        }
    }

    private func rotateIfNeeded() {
        let values = try? logURL.resourceValues(forKeys: [.fileSizeKey])
        guard let size = values?.fileSize, size >= maxFileBytes else { return }
        try? fileManager.removeItem(at: previousLogURL)
        try? fileManager.moveItem(at: logURL, to: previousLogURL)
    }

    private func sanitizedFields(_ fields: [String: String]) -> [(String, String)] {
        fields.compactMap { key, value in
            let lowered = key.lowercased()
            if lowered.contains("cookie") || lowered.contains("authorization") || lowered.contains("token") {
                return nil
            }
            return (key, sanitize(value))
        }
        .sorted { $0.0 < $1.0 }
    }

    private func sanitize(_ value: String) -> String {
        let collapsed = value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "|", with: "/")
        guard let url = URL(string: collapsed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return collapsed
        }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.query = nil
        components?.fragment = nil
        return components?.string ?? collapsed
    }

    private func bundleValue(_ key: String) -> String {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String) ?? ""
    }
}

// C 异常回调不能捕获实例属性；沿用系统前一个 handler，避免打断其它崩溃报告。
nonisolated(unsafe) private var previousUncaughtExceptionHandler: NSUncaughtExceptionHandler?
