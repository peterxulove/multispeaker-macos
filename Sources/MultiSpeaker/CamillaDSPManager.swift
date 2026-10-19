import Foundation
import AppKit
import Observation

enum CamillaError: LocalizedError {
    case binaryMissing
    case configInvalid(String)

    var errorDescription: String? {
        switch self {
        case .binaryMissing:
            return L.t("找不到 camilladsp 可执行文件（已内置在 App 内，若从源码运行请放到 ~/camilladsp/）")
        case .configInvalid(let reason):
            return L.t("配置校验失败：%@", reason)
        }
    }
}

/// CamillaDSP 进程管理 + 按 GUI 参数动态生成 v4 格式配置。
@MainActor
@Observable
final class CamillaDSPManager {
    var isRunning = false
    var binaryPath: String?
    var configURL: URL?
    var logLines: [String] = []
    var lastErrorMessage = ""
    var pendingRestart = false
    /// 用户「期望」它处于运行状态（与进程实际状态解耦，供看门狗判断是否需要复活）
    var wantsToRun = false

    /// 实时音量通道（websocket）：音量/静音不写配置、不重启进程
    let remote = CamillaRemote()
    private var wsPort: UInt16 = 0

    private var process: Process?
    private var restartTask: Task<Void, Never>?
    private var stoppingByUser = false

    /// 当前子进程 pid（供 App 退出时同步清理，避免留下孤儿进程长期霸占聚合设备/BlackHole）
    private nonisolated(unsafe) static var childPID: pid_t?
    private nonisolated(unsafe) static var terminationHookInstalled = false

    let appSupportDir: URL

    init() {
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/MultiSpeaker")
        appSupportDir = base
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        binaryPath = Self.locateBinary()
        Self.installTerminationHook()
    }

    /// App 退出（⌘Q / 被杀）时同步结束 CamillaDSP 子进程。
    /// 不做这一步的话子进程会变成孤儿继续运行，下次启动就会出现两个实例抢同一张聚合设备。
    private static func installTerminationHook() {
        guard !terminationHookInstalled else { return }
        terminationHookInstalled = true
        // ⌘Q / 正常退出
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: nil
        ) { _ in
            CamillaDSPManager.killChild()
        }
        // 被 kill / SIGINT 时也要带走子进程（willTerminate 不会触发）
        for sig in [SIGTERM, SIGINT, SIGHUP] {
            signal(sig) { _ in
                CamillaDSPManager.killChild()
                _exit(0)
            }
        }
    }

    private nonisolated static func killChild() {
        if let pid = childPID, pid > 0 {
            kill(pid, SIGTERM)
        }
    }

    /// 查找顺序：App 内置 → ~/camilladsp → Homebrew → /usr/local/bin
    static func locateBinary() -> String? {
        let candidates: [String] = [
            Bundle.main.resourceURL?.appendingPathComponent("camilladsp").path,
            NSString(string: "~/camilladsp/camilladsp").expandingTildeInPath,
            "/opt/homebrew/bin/camilladsp",
            "/usr/local/bin/camilladsp",
        ].compactMap { $0 }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    // MARK: - 配置生成（CamillaDSP v4 格式）

    static func generateYAML(settings: SettingsModel) -> String {
        let freq = settings.crossoverHz
        let fInt = Int(freq.rounded())
        let fStr = String(format: "%.1f", freq)
        let delay = String(format: "%.1f", settings.delayMs)
        let gb = String(format: "%.1f", settings.gainBuiltinDb)
        let gm = String(format: "%.1f", settings.gainMonitorDb)

        return """
        # 由 MultiSpeaker 自动生成 · 改动请在 App 的「调音台」里进行
        devices:
          samplerate: 48000
          chunksize: \(settings.chunksize)
          queuelimit: 4
          enable_rate_adjust: true
        # 注意：绝对不要在这里加 silence_threshold / silence_timeout。
        # CamillaDSP 4.x 在启动后 5 秒无音频会切到 Paused，且收到新音频后
        # 不会自动恢复（实测连续播 10 秒仍为 Paused），表现为「音乐在放但没声音」。
          capture:
            type: CoreAudio
            channels: 2
            device: "BlackHole 2ch"
          playback:
            type: CoreAudio
            channels: 4
            device: "MultiSpeaker"

        filters:
          hp_\(fInt)_a:
            type: Biquad
            parameters:
              type: Highpass
              freq: \(fStr)
              q: 0.7071
          hp_\(fInt)_b:
            type: Biquad
            parameters:
              type: Highpass
              freq: \(fStr)
              q: 0.7071

          lp_\(fInt)_a:
            type: Biquad
            parameters:
              type: Lowpass
              freq: \(fStr)
              q: 0.7071
          lp_\(fInt)_b:
            type: Biquad
            parameters:
              type: Lowpass
              freq: \(fStr)
              q: 0.7071

          delay_builtin:
            type: Delay
            parameters:
              delay: \(delay)
              unit: ms
              subsample: false

          gain_builtin:
            type: Gain
            parameters:
              gain: \(gb)
              inverted: false
              mute: false
          gain_monitor:
            type: Gain
            parameters:
              gain: \(gm)
              inverted: false
              mute: false

        mixers:
          split_stereo_to_4ch:
            channels:
              in: 2
              out: 4
            mapping:
              - dest: 0
                sources:
                  - channel: 0
                    gain: 0
                    inverted: false
                    scale: dB
              - dest: 1
                sources:
                  - channel: 1
                    gain: 0
                    inverted: false
                    scale: dB
              - dest: 2
                sources:
                  - channel: 0
                    gain: 0
                    inverted: false
                    scale: dB
              - dest: 3
                sources:
                  - channel: 1
                    gain: 0
                    inverted: false
                    scale: dB

        pipeline:
          - type: Mixer
            name: split_stereo_to_4ch
          - type: Filter
            channels: [0, 1]
            names: [hp_\(fInt)_a, hp_\(fInt)_b, delay_builtin, gain_builtin]
          - type: Filter
            channels: [2, 3]
            names: [lp_\(fInt)_a, lp_\(fInt)_b, gain_monitor]
        """
    }

    func writeConfig(settings: SettingsModel) throws -> URL {
        let url = appSupportDir.appendingPathComponent("multispeaker.yml")
        try Self.generateYAML(settings: settings).write(to: url, atomically: true, encoding: .utf8)
        configURL = url
        return url
    }

    // MARK: - 进程生命周期

    func start(settings: SettingsModel) async throws {
        guard !isRunning else { return }
        guard let binary = binaryPath ?? Self.locateBinary() else { throw CamillaError.binaryMissing }
        binaryPath = binary
        let config = try writeConfig(settings: settings)

        // 先干跑校验，提前给出可读错误
        let check = await Shell.run(binary, ["--check", config.path]) { _ in }
        if check != 0 {
            throw CamillaError.configInvalid(L.t("camilladsp --check 退出码 %d", check))
        }

        let p = Process()
        let pipe = Pipe()
        p.executableURL = URL(fileURLWithPath: binary)
        // -p：websocket 端口（音量/静音实时调，不重启）；-g / -m：启动即带上当前音量状态
        let port = Self.freePort()
        wsPort = port
        // 注意 -g 必须用等号写法：`-g -5.0` 会被 clap 当成新的短选项而报错
        var args = [config.path, "-l", "info", "-p", "\(port)",
                    "-g=\(String(format: "%.1f", settings.masterVolumeDb))"]
        if settings.muted { args.append("-m") }
        p.arguments = args
        p.standardOutput = pipe
        p.standardError = pipe
        p.currentDirectoryURL = appSupportDir

        let manager = self
        let readQueue = DispatchQueue(label: "com.user.multispeaker.camilladsp.log")
        readQueue.async {
            Shell.streamLines(pipe.fileHandleForReading) { line in
                Task { @MainActor in
                    manager.appendLog(line)
                }
            }
        }

        stoppingByUser = false
        p.terminationHandler = { [weak self] proc in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.handleTermination(code: proc.terminationStatus)
            }
        }

        do {
            try p.run()
        } catch {
            throw error
        }
        process = p
        Self.childPID = p.processIdentifier
        isRunning = true
        wantsToRun = true
        remote.attach(port: port, volume: settings.masterVolumeDb, muted: settings.muted)
        appendLog("── CamillaDSP 已启动（\(config.lastPathComponent)，控制端口 \(port)）")
    }

    // MARK: - 实时音量（不重启）

    func setVolume(_ db: Double) {
        remote.setVolume(db)
    }

    func setMute(_ muted: Bool) {
        remote.setMute(muted)
    }

    /// 交给 camilladsp 的 websocket 端口：先绑 0 号端口拿到内核分配的空闲端口
    private static func freePort() -> UInt16 {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return 12345 }
        defer { close(fd) }
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0 else { return 12345 }
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        let named = withUnsafeMutablePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(fd, $0, &len)
            }
        }
        guard named == 0, addr.sin_port != 0 else { return 12345 }
        return UInt16(bigEndian: addr.sin_port)
    }

    /// 停止并阻塞等待进程真正退出（重建聚合设备前必须先调用，
    /// 否则 CamillaDSP 会持有已被销毁的设备并报 `Playback device is no longer alive`）。
    func stopAndWait(timeout: TimeInterval = 4.0) async {
        wantsToRun = false
        guard isRunning || process != nil else { return }
        stop()
        let deadline = Date().addingTimeInterval(timeout)
        while isRunning, Date() < deadline {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        if isRunning {
            process?.terminate()
            let hardDeadline = Date().addingTimeInterval(2.0)
            while isRunning, Date() < hardDeadline {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }

    func stop() {
        wantsToRun = false
        guard let p = process, isRunning else { return }
        stoppingByUser = true
        remote.detach()
        p.interrupt() // SIGINT，CamillaDSP 会干净退出
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard let self, self.isRunning else { return }
            self.process?.terminate() // 3 秒不退就 SIGTERM
        }
    }

    /// 参数变化后防抖重启（0.6s）。
    func scheduleRestart(settings: SettingsModel) {
        guard isRunning else { return }
        pendingRestart = true
        restartTask?.cancel()
        restartTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled, let self else { return }
            self.pendingRestart = false
            self.stop()
            // 等进程真正退出再启动，避免抢占声卡
            for _ in 0..<30 {
                try? await Task.sleep(nanoseconds: 100_000_000)
                if !self.isRunning { break }
            }
            guard !Task.isCancelled else { return }
            try? await self.start(settings: settings)
        }
    }

    private func handleTermination(code: Int32) {
        isRunning = false
        process = nil
        Self.childPID = nil
        remote.detach()
        if stoppingByUser {
            appendLog("── " + L.t("CamillaDSP 已停止（用户操作）"))
        } else if code != 0 {
            lastErrorMessage = L.t("CamillaDSP 异常退出（code %d），请检查日志；常见原因是聚合设备 MultiSpeaker 不在线（显示器休眠）或 BlackHole 未设为默认输出。", code)
            appendLog("✗ CamillaDSP 异常退出，code \(code)")
        } else {
            appendLog("── " + L.t("CamillaDSP 已退出"))
        }
    }

    func appendLog(_ line: String) {
        logLines.append(line)
        if logLines.count > 600 { logLines.removeFirst(logLines.count - 600) }
    }

    func clearLog() {
        logLines.removeAll()
    }
}
