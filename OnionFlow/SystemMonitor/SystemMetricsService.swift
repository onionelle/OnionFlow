import Darwin
import Foundation
import IOKit

/// CPU / 内存 / 网速 2 秒一轮；GPU 温度和风扇 4 秒一轮。HID / SMC 失败只记一次日志。
nonisolated final class SystemMetricsService: @unchecked Sendable {
    static let shared = SystemMetricsService()

    var onUpdate: ((SystemMetrics) -> Void)?

    private let queue = DispatchQueue(label: "larva.OnionFlow.system-metrics", qos: .utility)
    private let fastInterval: TimeInterval = 2
    private let thermalInterval: TimeInterval = 4
    private var timer: DispatchSourceTimer?
    private let smc = SMCReader()
    private var previousCPU: host_cpu_load_info?
    private var previousNetwork: (up: Int64, down: Int64, at: Date)?
    private var lastThermalSample: Date?
    private var cachedGPUTemperature: Double?
    private var cachedFanUsage: Double?
    private var didLogGPUTempFailure = false
    private var didLogFanFailure = false
    private var didLogProbe = false
    private var isRunning = false

    /// Stats SensorsList 里各代 Apple Silicon / 独显 GPU 温度键。
    private static let gpuSMCTemperatureKeys = [
        "TCGC", "TG0D", "TGDD", "TG0H", "TG0P",
        "Tg05", "Tg0D", "Tg0L", "Tg0T",
        "Tg0f", "Tg0j",
        "Tf14", "Tf18", "Tf19", "Tf1A", "Tf24", "Tf28", "Tf29", "Tf2A",
        "Tg0G", "Tg0H", "Tg1U", "Tg1k", "Tg0K", "Tg0d", "Tg0e", "Tg0k",
        "Tg0U", "Tg0X", "Tg0g", "Tg1Y", "Tg1c", "Tg1g"
    ]

    private init() {}

    func start() {
        queue.async { [self] in
            guard !isRunning else { return }
            isRunning = true
            sampleLocked()
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now() + fastInterval, repeating: fastInterval, leeway: .milliseconds(200))
            timer.setEventHandler { [weak self] in
                self?.sampleLocked()
            }
            timer.resume()
            self.timer = timer
        }
    }

    func stop() {
        queue.async { [self] in
            timer?.setEventHandler {}
            timer?.cancel()
            timer = nil
            isRunning = false
            lastThermalSample = nil
        }
    }

    private func sampleLocked() {
        logProbeIfNeeded()
        let now = Date()
        let shouldReadThermal = lastThermalSample.map { now.timeIntervalSince($0) >= thermalInterval - 0.05 } ?? true
        if shouldReadThermal {
            cachedGPUTemperature = readGPUTemperature()
            cachedFanUsage = readFanUsage()
            lastThermalSample = now
        }
        var metrics = SystemMetrics()
        metrics.gpuTemperatureCelsius = cachedGPUTemperature
        metrics.fanUsage = cachedFanUsage
        metrics.cpuUsage = readCPUUsage()
        metrics.memoryUsage = readMemoryUsage()
        let network = readNetworkRates()
        metrics.uploadBytesPerSecond = network.upload
        metrics.downloadBytesPerSecond = network.download
        metrics.sampledAt = now
        onUpdate?(metrics)
    }

    private func logProbeIfNeeded() {
        guard !didLogProbe else { return }
        didLogProbe = true
        let hid = OnionAppleSiliconTemperatures()
        let hidKeys = hid?.keys.sorted().joined(separator: ",") ?? ""
        DiagnosticLogService.shared.log("metrics.probe", [
            "smc": smc.isAvailable ? "true" : "false",
            "fnum": smc.doubleValue(forKey: "FNum").map { String($0) } ?? "nil",
            "f0ac": smc.doubleValue(forKey: "F0Ac").map { String($0) } ?? "nil",
            "f0mx": smc.doubleValue(forKey: "F0Mx").map { String($0) } ?? "nil",
            "hidCount": String(hid?.count ?? 0),
            "hidKeys": hidKeys
        ])
    }

    private func readGPUTemperature() -> Double? {
        if let hid = averageHIDGPUTemperature() {
            return hid
        }
        if let smcTemperature = averageSMCGPUTemperature() {
            return smcTemperature
        }
        if let accelerator = acceleratorGPUTemperature() {
            return accelerator
        }
        if !didLogGPUTempFailure {
            didLogGPUTempFailure = true
            DiagnosticLogService.shared.log("metrics.gpu_temp.unavailable")
        }
        return nil
    }

    private func averageHIDGPUTemperature() -> Double? {
        guard let raw = OnionAppleSiliconTemperatures() else { return nil }
        let gpuValues = raw.compactMap { key, value -> Double? in
            let name = key.lowercased()
            guard name.contains("gpu"), name.contains("temp") else { return nil }
            let temperature = value.doubleValue
            return (temperature >= 0 && temperature < 110) ? temperature : nil
        }
        guard !gpuValues.isEmpty else { return nil }
        return gpuValues.reduce(0, +) / Double(gpuValues.count)
    }

    private func averageSMCGPUTemperature() -> Double? {
        let values = Self.gpuSMCTemperatureKeys.compactMap { key -> Double? in
            guard let temperature = smc.doubleValue(forKey: key) else { return nil }
            return (temperature >= 0 && temperature < 110) ? temperature : nil
        }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func acceleratorGPUTemperature() -> Double? {
        guard let stats = firstAcceleratorStatistics() else { return nil }
        if let temp = stats["Temperature(C)"] as? Int, temp > 0, temp < 120 {
            return Double(temp)
        }
        return nil
    }

    private func firstAcceleratorStatistics() -> [String: Any]? {
        guard let matching = IOServiceMatching("IOAccelerator") else { return nil }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }
        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            var properties: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let dict = properties?.takeRetainedValue() as? [String: Any],
                  let stats = dict["PerformanceStatistics"] as? [String: Any] else {
                continue
            }
            return stats
        }
        return nil
    }

    private func readFanUsage() -> Double? {
        if let usage = smc.busiestFanUsage() {
            return usage
        }
        if !didLogFanFailure {
            didLogFanFailure = true
            DiagnosticLogService.shared.log(
                "metrics.fan.unavailable",
                ["smc": smc.isAvailable ? "true" : "false"]
            )
        }
        return nil
    }

    private func readCPUUsage() -> Double? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        defer { previousCPU = info }
        guard let previous = previousCPU else { return nil }
        let user = Double(info.cpu_ticks.0 &- previous.cpu_ticks.0)
        let system = Double(info.cpu_ticks.1 &- previous.cpu_ticks.1)
        let idle = Double(info.cpu_ticks.2 &- previous.cpu_ticks.2)
        let nice = Double(info.cpu_ticks.3 &- previous.cpu_ticks.3)
        let total = user + system + idle + nice
        guard total > 0 else { return nil }
        return min(max((user + system + nice) / total, 0), 1)
    }

    private func readMemoryUsage() -> Double? {
        var basic = host_basic_info()
        var basicCount = mach_msg_type_number_t(MemoryLayout<host_basic_info>.stride / MemoryLayout<integer_t>.stride)
        let basicResult = withUnsafeMutablePointer(to: &basic) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(basicCount)) {
                host_info(mach_host_self(), HOST_BASIC_INFO, $0, &basicCount)
            }
        }
        guard basicResult == KERN_SUCCESS, basic.max_mem > 0 else { return nil }

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let page = Double(vm_kernel_page_size)
        let active = Double(stats.active_count) * page
        let speculative = Double(stats.speculative_count) * page
        let inactive = Double(stats.inactive_count) * page
        let wired = Double(stats.wire_count) * page
        let compressed = Double(stats.compressor_page_count) * page
        let purgeable = Double(stats.purgeable_count) * page
        let external = Double(stats.external_page_count) * page
        let used = active + inactive + speculative + wired + compressed - purgeable - external
        let ratio = used / Double(basic.max_mem)
        return min(max(ratio, 0), 1)
    }

    private func readNetworkRates() -> (upload: Int64?, download: Int64?) {
        guard let totals = networkByteTotals() else { return (nil, nil) }
        let now = Date()
        defer { previousNetwork = (totals.up, totals.down, now) }
        guard let previous = previousNetwork else { return (nil, nil) }
        let elapsed = now.timeIntervalSince(previous.at)
        guard elapsed > 0.2 else { return (nil, nil) }
        let upDelta = max(totals.up - previous.up, 0)
        let downDelta = max(totals.down - previous.down, 0)
        let maxDelta = Int64(1_250_000_000 * elapsed)
        return (
            upDelta > maxDelta ? 0 : Int64(Double(upDelta) / elapsed),
            downDelta > maxDelta ? 0 : Int64(Double(downDelta) / elapsed)
        )
    }

    private func networkByteTotals() -> (up: Int64, down: Int64)? {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var size: size_t = 0
        guard sysctl(&mib, u_int(mib.count), nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, u_int(mib.count), &buffer, &size, nil, 0) == 0 else { return nil }

        var upload: Int64 = 0
        var download: Int64 = 0
        var offset = 0
        while offset + MemoryLayout<if_msghdr>.size <= size {
            var header = if_msghdr()
            buffer.withUnsafeBytes { src in
                guard let base = src.baseAddress else { return }
                memcpy(&header, base.advanced(by: offset), MemoryLayout<if_msghdr>.size)
            }
            guard header.ifm_msglen > 0 else { break }
            if Int32(header.ifm_type) == RTM_IFINFO2, offset + MemoryLayout<if_msghdr2>.size <= size {
                var header2 = if_msghdr2()
                buffer.withUnsafeBytes { src in
                    guard let base = src.baseAddress else { return }
                    memcpy(&header2, base.advanced(by: offset), MemoryLayout<if_msghdr2>.size)
                }
                if (UInt32(header2.ifm_flags) & UInt32(IFF_LOOPBACK)) == 0 {
                    upload += Int64(clamping: header2.ifm_data.ifi_obytes)
                    download += Int64(clamping: header2.ifm_data.ifi_ibytes)
                }
            }
            offset += Int(header.ifm_msglen)
        }
        return (upload, download)
    }
}
