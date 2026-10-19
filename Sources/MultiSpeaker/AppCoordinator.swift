import Foundation
import AVFoundation
import Observation

/// 应用中枢：串联 CoreAudio / BlackHole / CamillaDSP / 自启，并驱动 UI 状态。
@MainActor
@Observable
final class AppCoordinator {
    let settings = SettingsModel()
    let blackhole = BlackHoleManager()
    let camilla = CamillaDSPManager()
    let launcher = LaunchAgentManager()

    /// 可选的输出设备（不含 BlackHole 和聚合设备自身）
    var devices: [AudioOutputDevice] = []
    var aggregateDevice: AudioOutputDevice?
    var blackHoleDevice: AudioOutputDevice?
    var defaultOutputDevice: AudioOutputDevice?

    var isBusy = false
    var statusMessage = ""
    var aggregateWarning = ""
    /// 麦克风权限被拒时为 true（BlackHole 是输入设备，采集它需要这个权限，否则 CamillaDSP 只收到静音）
    var micPermissionDenied = false

    private var pollTask: Task<Void, Never>?
    private var aggregateSeenBefore = false
    /// 看门狗复活计数（避免在设备真的缺失时无限重启）
    private var camillaRestartAttempts = 0

    init(autoStart: Bool = true) {
        settings.load()
        refreshDevices()
        startPolling()
        launcher.refresh()
        requestMicPermission()
        if autoStart, settings.startOnLaunch {
            maybeAutoStart()
        }
    }

    /// BlackHole 2ch 在系统里是「音频输入设备」，CamillaDSP 采集它必须拿到麦克风权限。
    /// 没有这个权限时 CoreAudio 只会给静音，症状就是「音乐在播放但完全没声音」。
    func requestMicPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            micPermissionDenied = false
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                Task { @MainActor in
                    guard let s = self else { return }
                    s.micPermissionDenied = !granted
                    if !granted {
                        s.statusMessage = "未获得麦克风权限：CamillaDSP 将收不到音。请到「系统设置 → 隐私与安全性 → 麦克风」允许 MultiSpeaker。"
                    }
                }
            }
        case .denied, .restricted:
            micPermissionDenied = true
            statusMessage = "麦克风权限被拒绝：请到「系统设置 → 隐私与安全性 → 麦克风」允许 MultiSpeaker，否则没有声音。"
        @unknown default:
            break
        }
    }

    // MARK: - 设备状态

    func refreshDevices() {
        let all = AudioEngine.allOutputDevices()
        devices = all.filter { !$0.isBlackHole && $0.uid != AudioEngine.aggregateUID && $0.outputChannels > 0 }
        aggregateDevice = AudioEngine.findAggregate()
        blackHoleDevice = AudioEngine.findBlackHole()
        defaultOutputDevice = AudioEngine.defaultOutput()
        blackhole.isInstalled = blackHoleDevice != nil

        if aggregateDevice != nil { aggregateSeenBefore = true }
        aggregateWarning = (aggregateSeenBefore && aggregateDevice == nil)
            ? "聚合设备 MultiSpeaker 已消失（常见原因：显示器休眠导致其音频设备离线）。唤醒显示器后点「创建/重建」。"
            : ""

        // 首次运行给出合理默认：高频=内置，低频=第一个非内置设备
        if settings.highDeviceUID == nil, let builtin = devices.first(where: { $0.isBuiltin }) {
            settings.highDeviceUID = builtin.uid
        }
        if settings.lowDeviceUID == nil, let monitor = devices.first(where: { !$0.isBuiltin }) {
            settings.lowDeviceUID = monitor.uid
        }
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled, let self else { return }
                self.refreshDevices()
                if self.blackhole.isInstalling == false {
                    self.blackhole.refresh()
                }
                await self.reviveCamillaIfNeeded()
            }
        }
    }

    /// 看门狗：用户期望它在跑，但进程已经没了（例如聚合设备被重建、显示器休眠导致设备掉线），
    /// 就在设备齐全时自动拉起来。连续失败 3 次后放弃，避免刷屏。
    private func reviveCamillaIfNeeded() async {
        guard camilla.wantsToRun, !camilla.isRunning, !camilla.pendingRestart else {
            if camilla.isRunning { camillaRestartAttempts = 0 }
            return
        }
        // 设备不齐时重启也没用（比如聚合设备真的没了），等用户处理
        guard blackHoleDevice != nil, aggregateDevice != nil else { return }
        guard camillaRestartAttempts < 3 else {
            camilla.wantsToRun = false
            statusMessage = "CamillaDSP 连续 3 次自动重启失败，请检查日志后手动启动。"
            return
        }
        camillaRestartAttempts += 1
        camilla.appendLog("── 检测到 CamillaDSP 已退出，自动重启（第 \(camillaRestartAttempts) 次）")
        do {
            try await camilla.start(settings: settings)
            statusMessage = "CamillaDSP 运行中（已自动恢复）"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    // MARK: - 一键设置

    func setupEverything() {
        Task { [weak self] in
            guard let self else { return }
            self.isBusy = true
            defer { self.isBusy = false }
            self.refreshDevices()

            guard self.blackHoleDevice != nil else {
                self.statusMessage = "第 1 步未完成：BlackHole 2ch 未安装。请先安装并重启 Mac。"
                return
            }
            if let bh = self.blackHoleDevice, AudioEngine.nominalSampleRate(bh.objectID) != 48000 {
                _ = AudioEngine.setNominalSampleRate(bh.objectID, rate: 48000)
            }
            guard await self.rebuildAggregate() else { return }
            self.statusMessage = "聚合设备 + 默认输出配置完成，正在启动 CamillaDSP…"
            do {
                try await self.camilla.start(settings: self.settings)
                let highName = self.devices.first { $0.uid == self.settings.highDeviceUID }?.name ?? "?"
                let lowName = self.devices.first { $0.uid == self.settings.lowDeviceUID }?.name ?? "?"
                self.statusMessage = "全部就绪：高频→\(highName)，低频→\(lowName)"
            } catch {
                self.statusMessage = error.localizedDescription
            }
        }
    }

    /// 重建聚合设备（安全版本）：
    /// 1) 先停 CamillaDSP 并等它真正退出（否则它持有旧设备，会报 device no longer alive 后退出）
    /// 2) 销毁旧聚合 → 建新聚合
    /// 3) 默认输出切回 BlackHole 2ch
    /// 4) 若之前是运行状态，则重新拉起 CamillaDSP
    @discardableResult
    private func rebuildAggregate() async -> Bool {
        refreshDevices()
        guard let high = devices.first(where: { $0.uid == settings.highDeviceUID }),
              let low = devices.first(where: { $0.uid == settings.lowDeviceUID }) else {
            statusMessage = "请先选择高频和低频设备。"
            return false
        }

        let wasRunning = camilla.wantsToRun

        // 关键：必须先让 CamillaDSP 松手，再动聚合设备
        await camilla.stopAndWait()

        if let existing = aggregateDevice {
            AudioEngine.destroyAggregateDevice(existing.objectID)
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        do {
            _ = try AudioEngine.createAggregateDevice(high: high, low: low)
        } catch {
            statusMessage = error.localizedDescription
            refreshDevices()
            return false
        }
        try? await Task.sleep(nanoseconds: 200_000_000)
        refreshDevices()

        guard let bh = blackHoleDevice else { return false }
        if AudioEngine.nominalSampleRate(bh.objectID) != 48000 {
            _ = AudioEngine.setNominalSampleRate(bh.objectID, rate: 48000)
        }
        try? AudioEngine.setDefaultOutput(bh.objectID)
        refreshDevices()

        if wasRunning {
            do {
                try await camilla.start(settings: settings)
                statusMessage = "已重建聚合设备（高频=\(high.name) / 低频=\(low.name)），CamillaDSP 已重启"
            } catch {
                statusMessage = error.localizedDescription
            }
        } else {
            statusMessage = "已创建聚合设备 MultiSpeaker（高频=\(high.name) / 低频=\(low.name)）"
        }
        return true
    }

    func createAggregate() {
        Task { [weak self] in
            guard let self else { return }
            self.isBusy = true
            defer { self.isBusy = false }
            await self.rebuildAggregate()
        }
    }

    func destroyAggregate() {
        guard let agg = aggregateDevice else { return }
        AudioEngine.destroyAggregateDevice(agg.objectID)
        aggregateSeenBefore = false
        statusMessage = "已删除聚合设备 MultiSpeaker"
        refreshDevices()
    }

    func setBlackHoleAsDefault() {
        guard let bh = blackHoleDevice else {
            statusMessage = "未找到 BlackHole 2ch"
            return
        }
        if AudioEngine.nominalSampleRate(bh.objectID) != 48000 {
            _ = AudioEngine.setNominalSampleRate(bh.objectID, rate: 48000)
        }
        do {
            try AudioEngine.setDefaultOutput(bh.objectID)
            statusMessage = "系统默认输出已切换为 BlackHole 2ch"
        } catch {
            statusMessage = error.localizedDescription
        }
        refreshDevices()
    }

    func restoreBuiltinOutput() {
        if let builtin = devices.first(where: { $0.isBuiltin }) {
            try? AudioEngine.setDefaultOutput(builtin.objectID)
            statusMessage = "系统默认输出已切回 \(builtin.name)"
        }
        refreshDevices()
    }

    // MARK: - 运行控制

    func startEngine() {
        Task { [weak self] in
            guard let self else { return }
            self.isBusy = true
            defer { self.isBusy = false }
            self.refreshDevices()
            guard self.blackHoleDevice != nil else {
                self.statusMessage = "BlackHole 2ch 未安装，无法启动。"
                return
            }
            guard self.aggregateDevice != nil else {
                self.statusMessage = "聚合设备 MultiSpeaker 不存在，请先创建。"
                return
            }
            if let bh = self.blackHoleDevice {
                try? AudioEngine.setDefaultOutput(bh.objectID)
            }
            self.camillaRestartAttempts = 0
            do {
                try await self.camilla.start(settings: self.settings)
                self.statusMessage = "CamillaDSP 运行中"
            } catch {
                self.statusMessage = error.localizedDescription
            }
        }
    }

    func stopEngine() {
        camilla.stop()
        // 停了就没有声音了，顺手把系统输出切回内置喇叭
        if let builtin = devices.first(where: { $0.isBuiltin }) {
            try? AudioEngine.setDefaultOutput(builtin.objectID)
        }
        refreshDevices()
    }

    func settingsChanged() {
        settings.save()
        camilla.scheduleRestart(settings: settings)
    }

    private func maybeAutoStart() {
        guard blackHoleDevice != nil, aggregateDevice != nil else { return }
        startEngine()
    }

    func toggleAutostart(_ enabled: Bool) {
        launcher.setEnabled(enabled)
    }
}
