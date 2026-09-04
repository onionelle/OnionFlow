import Combine
import Foundation

/// 系统状态的 UI 入口：把后台采样快照发到主线程，数值没变就不刷新。
@MainActor
final class SystemMetricsViewModel: ObservableObject {
    @Published private(set) var metrics = SystemMetrics()
    private let service: SystemMetricsService

    init(service: SystemMetricsService = .shared) {
        self.service = service
        service.onUpdate = { [weak self] snapshot in
            Task { @MainActor [weak self] in
                self?.apply(snapshot)
            }
        }
    }

    func start() {
        if UserDefaults.standard.object(forKey: "systemMetricsEnabled") as? Bool == false {
            return
        }
        service.start()
    }

    func stop() {
        service.stop()
    }

    private func apply(_ snapshot: SystemMetrics) {
        guard snapshot != metrics else { return }
        metrics = snapshot
    }
}
