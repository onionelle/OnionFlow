import Foundation

/// 快捷启动槽位只持久化 App 路径，不负责启动或拖拽行为。
struct QuickLaunchStore {
    private let key = "quickLaunchAppsJson"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadSlots() -> [String?]? {
        guard let json = defaults.string(forKey: key),
              let data = json.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode([String?].self, from: data)
    }

    func saveSlots(_ slots: [String?]) {
        guard let data = try? JSONEncoder().encode(slots),
              let json = String(data: data, encoding: .utf8) else {
            return
        }
        defaults.set(json, forKey: key)
    }
}
