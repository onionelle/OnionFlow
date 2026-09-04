import Foundation

/// compact 系统状态快照。缺项为 nil，界面显示为「—」。
struct SystemMetrics: Equatable {
    var gpuTemperatureCelsius: Double?
    var fanUsage: Double?
    var cpuUsage: Double?
    var memoryUsage: Double?
    var uploadBytesPerSecond: Int64?
    var downloadBytesPerSecond: Int64?
    var sampledAt: Date = Date()

    static func == (lhs: SystemMetrics, rhs: SystemMetrics) -> Bool {
        lhs.gpuTemperatureCelsius == rhs.gpuTemperatureCelsius
            && lhs.fanUsage == rhs.fanUsage
            && lhs.cpuUsage == rhs.cpuUsage
            && lhs.memoryUsage == rhs.memoryUsage
            && lhs.uploadBytesPerSecond == rhs.uploadBytesPerSecond
            && lhs.downloadBytesPerSecond == rhs.downloadBytesPerSecond
    }
}
