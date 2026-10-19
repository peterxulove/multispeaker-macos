import CoreAudio
import Foundation

/// 一个可用的音频输出设备（从 CoreAudio 枚举而来）。
struct AudioOutputDevice: Identifiable, Hashable, Sendable {
    let objectID: AudioObjectID
    let uid: String
    let name: String
    let outputChannels: Int
    let transportType: UInt32

    var id: AudioObjectID { objectID }
    var isBuiltin: Bool { transportType == kAudioDeviceTransportTypeBuiltIn }
    var isBlackHole: Bool {
        uid.lowercased().contains("blackhole") || name.lowercased() == "blackhole 2ch"
    }
}

enum CoreAudioError: LocalizedError {
    case osStatus(OSStatus, String)

    var errorDescription: String? {
        switch self {
        case .osStatus(let status, let message):
            return "\(message)（OSStatus \(status)）"
        }
    }
}

/// 对 CoreAudio C API 的轻量封装。
/// 全部为同步纯函数，不持有状态，可从任意线程调用。
enum AudioEngine {

    static let aggregateName = "MultiSpeaker"
    static let aggregateUID = "com.user.MultiSpeaker"
    static let blackHoleName = "BlackHole 2ch"

    /// 新 SDK 里 kAudioObjectSystemObject 以 Int32 字面量导入，显式转类型。
    private static let systemObject: AudioObjectID = AudioObjectID(kAudioObjectSystemObject)

    // MARK: - 设备枚举

    static func allOutputDevices() -> [AudioOutputDevice] {
        var addr = propertyAddress(kAudioHardwarePropertyDevices)
        var size = UInt32(0)
        guard AudioObjectGetPropertyDataSize(systemObject, &addr, 0, nil, &size) == noErr,
              size >= UInt32(MemoryLayout<AudioObjectID>.size) else { return [] }
        let count = Int(size) / MemoryLayout<AudioObjectID>.size
        var ids = [AudioObjectID](repeating: kAudioObjectUnknown, count: count)
        guard AudioObjectGetPropertyData(systemObject, &addr, 0, nil, &size, &ids) == noErr else { return [] }
        var out: [AudioOutputDevice] = []
        for id in ids where id != kAudioObjectUnknown {
            if let device = describeDevice(id) { out.append(device) }
        }
        return out
    }

    static func describeDevice(_ objectID: AudioObjectID) -> AudioOutputDevice? {
        guard let name = readString(objectID, kAudioObjectPropertyName),
              let uid = readString(objectID, kAudioDevicePropertyDeviceUID) else { return nil }
        return AudioOutputDevice(
            objectID: objectID,
            uid: uid,
            name: name,
            outputChannels: outputChannelCount(objectID),
            transportType: readNumberUInt32(objectID, kAudioDevicePropertyTransportType) ?? 0
        )
    }

    static func findBlackHole() -> AudioOutputDevice? {
        allOutputDevices().first { $0.isBlackHole }
    }

    static func findAggregate() -> AudioOutputDevice? {
        allOutputDevices().first { $0.uid == aggregateUID }
    }

    static func defaultOutput() -> AudioOutputDevice? {
        var addr = propertyAddress(kAudioHardwarePropertyDefaultOutputDevice)
        var id = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(systemObject, &addr, 0, nil, &size, &id) == noErr,
              id != kAudioObjectUnknown else { return nil }
        return describeDevice(id)
    }

    // MARK: - 聚合设备

    /// 创建聚合设备 "MultiSpeaker"。
    /// - 通道顺序：ch1/ch2 = 高频设备（笔记本喇叭），ch3/ch4 = 低频设备（外接音箱）。
    /// - 时钟源 = 高频设备；低频设备开启漂移修正（对应 Audio MIDI 里的“漂移修正”勾选）。
    @discardableResult
    static func createAggregateDevice(high: AudioOutputDevice, low: AudioOutputDevice, driftOnLow: Bool = true) throws -> AudioObjectID {
        guard high.outputChannels == 2, low.outputChannels == 2 else {
            throw CoreAudioError.osStatus(
                -50,
                "两路设备都必须是立体声（2ch）。当前：\(high.name)=\(high.outputChannels)ch，\(low.name)=\(low.outputChannels)ch"
            )
        }
        let subHigh: [String: Any] = [
            kAudioSubDeviceUIDKey: high.uid,
            kAudioSubDeviceNameKey: high.name,
            kAudioSubDeviceOutputChannelsKey: high.outputChannels,
            kAudioSubDeviceDriftCompensationKey: 0,
            kAudioSubDeviceDriftCompensationQualityKey: 0x40,
        ]
        let subLow: [String: Any] = [
            kAudioSubDeviceUIDKey: low.uid,
            kAudioSubDeviceNameKey: low.name,
            kAudioSubDeviceOutputChannelsKey: low.outputChannels,
            kAudioSubDeviceDriftCompensationKey: driftOnLow ? 1 : 0,
            kAudioSubDeviceDriftCompensationQualityKey: 0x60,
        ]
        let description: [String: Any] = [
            kAudioAggregateDeviceUIDKey: aggregateUID,
            kAudioAggregateDeviceNameKey: aggregateName,
            kAudioAggregateDeviceIsPrivateKey: 0,   // 发布到全系统（可被其他 App 选择）
            kAudioAggregateDeviceIsStackedKey: 0,   // 非堆叠：子设备通道按顺序拼接
            kAudioAggregateDeviceMainSubDeviceKey: high.uid, // 时钟源 = 高频设备
            kAudioAggregateDeviceSubDeviceListKey: [subHigh, subLow],
        ]
        var newID = kAudioObjectUnknown
        let status = AudioHardwareCreateAggregateDevice(description as CFDictionary, &newID)
        guard status == noErr, newID != kAudioObjectUnknown else {
            throw CoreAudioError.osStatus(status, "创建聚合设备失败")
        }
        // 统一到 48kHz（失败不阻塞，例如外接设备不支持 48k 时会由 HAL 重采样）
        _ = setNominalSampleRate(newID, rate: 48000)
        return newID
    }

    static func destroyAggregateDevice(_ objectID: AudioObjectID) {
        AudioHardwareDestroyAggregateDevice(objectID)
    }

    // MARK: - 默认输出 / 采样率

    static func setDefaultOutput(_ objectID: AudioObjectID) throws {
        var addr = propertyAddress(kAudioHardwarePropertyDefaultOutputDevice)
        var id = objectID
        let status = AudioObjectSetPropertyData(systemObject, &addr, 0, nil, UInt32(MemoryLayout<AudioObjectID>.size), &id)
        guard status == noErr else {
            throw CoreAudioError.osStatus(status, "设置系统默认输出失败")
        }
    }

    @discardableResult
    static func setNominalSampleRate(_ objectID: AudioObjectID, rate: Float64) -> OSStatus {
        var addr = propertyAddress(kAudioDevicePropertyNominalSampleRate)
        var r = rate
        return AudioObjectSetPropertyData(objectID, &addr, 0, nil, UInt32(MemoryLayout<Float64>.size), &r)
    }

    static func nominalSampleRate(_ objectID: AudioObjectID) -> Float64? {
        var addr = propertyAddress(kAudioDevicePropertyNominalSampleRate)
        var value = Float64(0)
        var size = UInt32(MemoryLayout<Float64>.size)
        guard AudioObjectGetPropertyData(objectID, &addr, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    // MARK: - 底层读取

    private static func propertyAddress(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
    }

    static func readString(
        _ objectID: AudioObjectID,
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> String? {
        var addr = propertyAddress(selector, scope: scope)
        // CoreAudio 返回 +1 retain 的 CFString，用 Unmanaged 显式接管所有权
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(objectID, &addr, 0, nil, &size, &value)
        guard status == noErr, let v = value else { return nil }
        return v.takeRetainedValue() as String
    }

    /// 读 UInt32 数值属性（如 TransportType）。
    /// 注意：HAL 对数值属性返回的是裸值而非 CFNumber，按 CFTypeRef 读会拿到野指针。
    static func readNumberUInt32(_ objectID: AudioObjectID, _ selector: AudioObjectPropertySelector) -> UInt32? {
        var addr = propertyAddress(selector)
        var value = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(objectID, &addr, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    static func outputChannelCount(_ objectID: AudioObjectID) -> Int {
        var addr = propertyAddress(kAudioDevicePropertyStreamConfiguration, scope: kAudioObjectPropertyScopeOutput)
        var size = UInt32(0)
        guard AudioObjectGetPropertyDataSize(objectID, &addr, 0, nil, &size) == noErr, size > 0 else { return 0 }
        let ptr = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { ptr.deallocate() }
        guard AudioObjectGetPropertyData(objectID, &addr, 0, nil, &size, ptr) == noErr else { return 0 }
        let list = UnsafeMutableAudioBufferListPointer(ptr.assumingMemoryBound(to: AudioBufferList.self))
        var total = 0
        for buffer in list { total += Int(buffer.mNumberChannels) }
        return total
    }
}
