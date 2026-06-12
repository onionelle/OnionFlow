import AppKit
import QuickLookThumbnailing

/// 集中处理临时暂存的文件状态与系统预览能力，View 只消费结果。
@MainActor
final class TemporaryTrayFileService {
    func makeItem(from url: URL, transferMode: TemporaryTrayTransferMode) -> TemporaryTrayItem {
        let normalizedURL = url.standardizedFileURL
        return TemporaryTrayItem(
            url: normalizedURL,
            transferMode: transferMode,
            isAvailable: FileManager.default.fileExists(atPath: normalizedURL.path)
        )
    }

    func refreshedItem(_ item: TemporaryTrayItem) -> TemporaryTrayItem {
        TemporaryTrayItem(
            url: item.url,
            transferMode: item.transferMode,
            isAvailable: FileManager.default.fileExists(atPath: item.url.path)
        )
    }

    func icon(for item: TemporaryTrayItem) -> NSImage {
        NSWorkspace.shared.icon(forFile: item.url.path)
    }

    func loadPreview(for item: TemporaryTrayItem, completion: @escaping (NSImage) -> Void) {
        let fallback = icon(for: item)
        guard item.isAvailable else {
            completion(fallback)
            return
        }

        let request = QLThumbnailGenerator.Request(
            fileAt: item.url,
            size: CGSize(width: 52, height: 52),
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            representationTypes: .thumbnail
        )
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
            DispatchQueue.main.async {
                completion(representation?.nsImage ?? fallback)
            }
        }
    }
}
