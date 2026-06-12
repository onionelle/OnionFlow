import AudioToolbox
import Foundation
import IOBluetooth

struct AudioOutputDevice: Identifiable, Equatable {
    let id: String
    let name: String
}

enum AudioOutputDeviceService {
    static func outputDevices() -> [AudioOutputDevice] {
        allDeviceIDs().compactMap { deviceID in
            guard hasOutputStreams(deviceID),
                  let uid = stringProperty(kAudioDevicePropertyDeviceUID, on: deviceID),
                  let name = stringProperty(kAudioObjectPropertyName, on: deviceID) else {
                return nil
            }
            return AudioOutputDevice(id: uid, name: name)
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    @discardableResult
    static func selectOutputDevice(uid: String) -> Bool {
        guard !uid.isEmpty,
              let deviceID = allDeviceIDs().first(where: { stringProperty(kAudioDevicePropertyDeviceUID, on: $0) == uid }) else {
            return false
        }
        setDefaultOutputDevice(deviceID, selector: kAudioHardwarePropertyDefaultOutputDevice)
        setDefaultOutputDevice(deviceID, selector: kAudioHardwarePropertyDefaultSystemOutputDevice)
        return true
    }

    static func restorePreferredOutputDevice(uid: String) {
        guard !uid.isEmpty else { return }
        
        Task { @MainActor in
            for delay in [1.0, 3.0, 6.0, 10.0] {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                if selectOutputDevice(uid: uid) {
                    return
                }
            }
        }
    }

    static func pairedBluetoothAudioDevices() -> [(address: String, name: String, isConnected: Bool)] {
        guard let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else { return [] }
        let coreAudioDeviceNames = outputDevices().map { $0.name }
        
        return devices.filter { $0.deviceClassMajor == kBluetoothDeviceClassMajorAudio }.compactMap { device in
            let name = device.nameOrAddress ?? "未知设备"
            let isTrulyConnected = device.isConnected() && coreAudioDeviceNames.contains(name)
            return (device.addressString, name, isTrulyConnected)
        }
    }

    @discardableResult
    static func connectBluetoothDevice(address: String) -> Bool {
        guard let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else { return false }
        for device in devices {
            if device.addressString == address {
                if device.isConnected() {
                    let name = device.nameOrAddress ?? ""
                    let coreAudioDeviceNames = outputDevices().map { $0.name }
                    
                    if !coreAudioDeviceNames.contains(name) {
                        // 发现僵尸连接（系统显示已连接，但 CoreAudio 中没有该音频设备）
                        // 先断开原有连接，再重新发起连接
                        device.closeConnection()
                        Thread.sleep(forTimeInterval: 1.5)
                    } else {
                        return true
                    }
                }
                return device.openConnection() == kIOReturnSuccess
            }
        }
        return false
    }

    @discardableResult
    static func disconnectBluetoothDevice(address: String) -> Bool {
        guard let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else { return false }
        for device in devices {
            if device.addressString == address {
                if device.isConnected() {
                    return device.closeConnection() == kIOReturnSuccess
                }
                return true
            }
        }
        return false
    }

    private static func allDeviceIDs() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize) == noErr else {
            return []
        }
        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var devices = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &devices) == noErr else {
            return []
        }
        return devices
    }

    private static func hasOutputStreams(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize) == noErr, dataSize > 0 else {
            return false
        }

        let rawPointer = UnsafeMutableRawPointer.allocate(byteCount: Int(dataSize), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { rawPointer.deallocate() }
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, rawPointer) == noErr else {
            return false
        }

        let bufferList = UnsafeMutableAudioBufferListPointer(rawPointer.assumingMemoryBound(to: AudioBufferList.self))
        return bufferList.contains { $0.mNumberChannels > 0 }
    }

    private static func stringProperty(_ selector: AudioObjectPropertySelector, on deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: CFString = "" as CFString
        var dataSize = UInt32(MemoryLayout<CFString>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, &value) == noErr else {
            return nil
        }
        let string = value as String
        return string.isEmpty ? nil : string
    }

    private static func setDefaultOutputDevice(_ deviceID: AudioDeviceID, selector: AudioObjectPropertySelector) {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var outputDeviceID = deviceID
        AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &outputDeviceID
        )
    }
}
