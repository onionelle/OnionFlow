import Darwin
import Foundation
import IOKit

/// 只读 SMC，用于风扇转速。结构与调用约定参考 exelban/Stats（MIT），不写风扇、不装 Helper。
nonisolated final class SMCReader: @unchecked Sendable {
    private var connection: io_connect_t = 0

    init() {
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("AppleSMC")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return
        }
        let device = IOIteratorNext(iterator)
        IOObjectRelease(iterator)
        guard device != 0 else { return }
        let result = IOServiceOpen(device, mach_task_self_, 0, &connection)
        IOObjectRelease(device)
        if result != KERN_SUCCESS {
            connection = 0
        }
    }

    deinit {
        if connection != 0 {
            IOServiceClose(connection)
        }
    }

    var isAvailable: Bool { connection != 0 }

    func doubleValue(forKey key: String) -> Double? {
        guard connection != 0, key.count == 4 else { return nil }
        var value = SMCValue(key)
        guard read(&value) == KERN_SUCCESS, value.dataSize > 0 else { return nil }
        return decode(value)
    }

    /// 多风扇时取最忙一档。0 转也算读到，显示 0%。
    func busiestFanUsage() -> Double? {
        guard let count = doubleValue(forKey: "FNum"), count >= 1 else { return nil }
        var busiest: Double?
        for index in 0..<min(Int(count), 8) {
            let current = doubleValue(forKey: "F\(index)Ac") ?? 0
            let maxSpeed = doubleValue(forKey: "F\(index)Mx")
            let minSpeed = doubleValue(forKey: "F\(index)Mn") ?? 0
            guard let maxSpeed, maxSpeed > minSpeed else { continue }
            let usage = (current - minSpeed) / (maxSpeed - minSpeed)
            busiest = max(busiest ?? 0, min(max(usage, 0), 1))
        }
        return busiest
    }

    private func decode(_ value: SMCValue) -> Double? {
        let bytes = value.bytes
        switch value.dataType {
        case "ui8 ":
            return Double(bytes[0])
        case "ui16":
            return Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
        case "ui32":
            return Double(UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3]))
        case "flt ":
            return Double(bytes.withUnsafeBytes { $0.load(fromByteOffset: 0, as: Float.self) })
        case "fpe2":
            return Double((Int(bytes[0]) << 6) + (Int(bytes[1]) >> 2))
        case "sp78":
            return Double(Int(bytes[0]) * 256 + Int(bytes[1])) / 256
        case "sp87":
            return Double(Int(bytes[0]) * 256 + Int(bytes[1])) / 128
        case "sp96":
            return Double(Int(bytes[0]) * 256 + Int(bytes[1])) / 64
        case "sp5a", "sp5A":
            return Double(UInt16(bytes[0]) * 256 + UInt16(bytes[1])) / 1024
        default:
            return nil
        }
    }

    private func read(_ value: UnsafeMutablePointer<SMCValue>) -> kern_return_t {
        var input = SMCKeyData()
        var output = SMCKeyData()
        input.key = FourCharCode(fromSMCKey: value.pointee.key)
        input.data8 = 9
        var result = call(2, input: &input, output: &output)
        guard result == KERN_SUCCESS else { return result }
        value.pointee.dataSize = UInt32(output.keyInfo.dataSize)
        value.pointee.dataType = output.keyInfo.dataType.smcFourCharString
        input.keyInfo.dataSize = output.keyInfo.dataSize
        input.data8 = 5
        result = call(2, input: &input, output: &output)
        guard result == KERN_SUCCESS else { return result }
        withUnsafeBytes(of: output.bytes) { source in
            value.pointee.bytes.withUnsafeMutableBytes { destination in
                guard let sourceAddress = source.baseAddress, let destinationAddress = destination.baseAddress else { return }
                memcpy(destinationAddress, sourceAddress, min(Int(value.pointee.dataSize), destination.count))
            }
        }
        return KERN_SUCCESS
    }

    private func call(_ index: UInt8, input: inout SMCKeyData, output: inout SMCKeyData) -> kern_return_t {
        let inputSize = MemoryLayout<SMCKeyData>.stride
        var outputSize = MemoryLayout<SMCKeyData>.stride
        return IOConnectCallStructMethod(connection, UInt32(index), &input, inputSize, &output, &outputSize)
    }
}

private struct SMCValue {
    var key: String
    var dataSize: UInt32 = 0
    var dataType: String = ""
    var bytes: [UInt8] = Array(repeating: 0, count: 32)

    init(_ key: String) {
        self.key = key
    }
}

private struct SMCKeyData {
    struct Version {
        var major: UInt8 = 0
        var minor: UInt8 = 0
        var build: UInt8 = 0
        var reserved: UInt8 = 0
        var release: UInt16 = 0
    }

    struct LimitData {
        var version: UInt16 = 0
        var length: UInt16 = 0
        var cpuPLimit: UInt32 = 0
        var gpuPLimit: UInt32 = 0
        var memPLimit: UInt32 = 0
    }

    struct KeyInfo {
        var dataSize: IOByteCount32 = 0
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
    }

    typealias SMCBytes = (
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
    )

    var key: UInt32 = 0
    var vers = Version()
    var pLimitData = LimitData()
    var keyInfo = KeyInfo()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: SMCBytes = (
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    )
}

private extension FourCharCode {
    init(fromSMCKey str: String) {
        self = str.utf8.reduce(0) { $0 << 8 | UInt32($1) }
    }

    var smcFourCharString: String {
        let chars = [
            UnicodeScalar(self >> 24 & 0xff) ?? UnicodeScalar(32)!,
            UnicodeScalar(self >> 16 & 0xff) ?? UnicodeScalar(32)!,
            UnicodeScalar(self >> 8 & 0xff) ?? UnicodeScalar(32)!,
            UnicodeScalar(self & 0xff) ?? UnicodeScalar(32)!
        ]
        return String(String.UnicodeScalarView(chars))
    }
}
