import SwiftUI

/// 展开态底部系统状态。硬件四项靠左，网速靠右。只展示，不接收点击。
struct SystemMetricsStripView: View {
    enum Placement {
        case hardware
        case network
    }

    @ObservedObject var viewModel: SystemMetricsViewModel
    let placement: Placement

    var body: some View {
        HStack(spacing: 6) {
            switch placement {
            case .hardware:
                labeledValue("GPU", tempText(viewModel.metrics.gpuTemperatureCelsius))
                labeledValue("FAN", percentText(viewModel.metrics.fanUsage))
                labeledValue("CPU", percentText(viewModel.metrics.cpuUsage))
                labeledValue("MEM", percentText(viewModel.metrics.memoryUsage))
            case .network:
                labeledValue("NET", networkText)
            }
        }
    }

    private var networkText: String {
        let up = rateText(viewModel.metrics.uploadBytesPerSecond)
        let down = rateText(viewModel.metrics.downloadBytesPerSecond)
        return "↑\(up) ↓\(down)"
    }

    private func labeledValue(_ label: String, _ value: String) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(IslandTypography.micro)
                .foregroundStyle(.white.opacity(0.32))
            Text(value)
                .font(IslandTypography.mono)
                .foregroundStyle(.white.opacity(0.62))
        }
    }

    private func tempText(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(Int(value.rounded()))°"
    }

    private func percentText(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(Int((value * 100).rounded()))%"
    }

    private func rateText(_ bytesPerSecond: Int64?) -> String {
        guard let bytesPerSecond else { return "—" }
        let value = Double(max(bytesPerSecond, 0))
        if value < 1024 {
            return "0K"
        }
        if value < 1024 * 1024 {
            return compactRate(value / 1024, suffix: "K")
        }
        return compactRate(value / (1024 * 1024), suffix: "M")
    }

    private func compactRate(_ value: Double, suffix: String) -> String {
        if value >= 10 {
            return "\(Int(value.rounded()))\(suffix)"
        }
        return String(format: "%.1f%@", value, suffix)
    }
}
