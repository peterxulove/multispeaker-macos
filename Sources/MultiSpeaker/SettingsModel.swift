import Foundation
import Observation

/// 全部可调参数（持久化在 UserDefaults）。
@Observable
final class SettingsModel: @unchecked Sendable {
    var highDeviceUID: String?       // 高频设备（笔记本喇叭）
    var lowDeviceUID: String?        // 低频设备（外接音箱）

    var crossoverHz: Double = 200    // 分频点 80~320Hz
    var delayMs: Double = 8          // 高频链路延迟补偿 0~40ms
    var gainBuiltinDb: Double = 0    // 高频增益 dB
    var gainMonitorDb: Double = 0    // 低频增益 dB
    var masterVolumeDb: Double = 0   // 总音量 dB（键盘音量键走 BlackHole 会失效，用这个）
    var muted: Bool = false
    var chunksize: Int = 1024        // 爆音/欠载时调到 2048

    var startOnLaunch: Bool = true   // 打开 App 自动跑 CamillaDSP
    var hideOnClose: Bool = true     // 点关闭按钮时收进顶部状态栏（而不是关掉窗口）

    @ObservationIgnored
    private let defaults = UserDefaults.standard

    func load() {
        let d = defaults
        highDeviceUID = d.string(forKey: "settings.highDeviceUID")
        lowDeviceUID = d.string(forKey: "settings.lowDeviceUID")
        crossoverHz = d.object(forKey: "settings.crossoverHz") as? Double ?? 200
        delayMs = d.object(forKey: "settings.delayMs") as? Double ?? 8
        gainBuiltinDb = d.object(forKey: "settings.gainBuiltinDb") as? Double ?? 0
        gainMonitorDb = d.object(forKey: "settings.gainMonitorDb") as? Double ?? 0
        masterVolumeDb = d.object(forKey: "settings.masterVolumeDb") as? Double ?? 0
        muted = d.bool(forKey: "settings.muted")
        chunksize = d.object(forKey: "settings.chunksize") as? Int ?? 1024
        startOnLaunch = (d.object(forKey: "settings.startOnLaunch") as? Bool) ?? true
        hideOnClose = (d.object(forKey: "settings.hideOnClose") as? Bool) ?? true
    }

    func save() {
        let d = defaults
        d.set(highDeviceUID, forKey: "settings.highDeviceUID")
        d.set(lowDeviceUID, forKey: "settings.lowDeviceUID")
        d.set(crossoverHz, forKey: "settings.crossoverHz")
        d.set(delayMs, forKey: "settings.delayMs")
        d.set(gainBuiltinDb, forKey: "settings.gainBuiltinDb")
        d.set(gainMonitorDb, forKey: "settings.gainMonitorDb")
        d.set(masterVolumeDb, forKey: "settings.masterVolumeDb")
        d.set(muted, forKey: "settings.muted")
        d.set(chunksize, forKey: "settings.chunksize")
        d.set(startOnLaunch, forKey: "settings.startOnLaunch")
        d.set(hideOnClose, forKey: "settings.hideOnClose")
    }
}
