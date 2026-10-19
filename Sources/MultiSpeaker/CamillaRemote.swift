import Foundation

/// CamillaDSP 的 websocket 控制通道。
///
/// 为什么要有这一层：音量以前是写在 YAML 里的一个 Gain 滤镜，改一次就得重写配置 + 重启进程，
/// 拖动滑块时引擎反复重启，听感就是「声音一顿一顿、调小一点直接没声」。
/// 改成走 websocket 的 `SetVolume` / `SetMute` 之后，音量是浮点增益、即时生效，音频不断流。
@MainActor
final class CamillaRemote {
    private var task: URLSessionWebSocketTask?
    private var port: UInt16 = 0

    private var volume: Double = 0
    private var muted = false
    private var muteDirty = true
    private var flushing = false
    private var flushAgain = false
    private var flushScheduled = false
    private var connectTask: Task<Void, Never>?

    private(set) var isConnected = false

    // MARK: - 生命周期

    /// 引擎启动后挂上控制通道；连不上会自动重试（CamillaDSP 起来需要几百毫秒）
    func attach(port: UInt16, volume: Double, muted: Bool) {
        detach()
        self.port = port
        self.volume = volume
        self.muted = muted
        self.muteDirty = true
        connectTask = Task { [weak self] in
            guard let self else { return }
            for _ in 0..<40 {
                if Task.isCancelled { return }
                if await self.probe() {
                    self.isConnected = true
                    await self.flush()
                    return
                }
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
        }
    }

    func detach() {
        connectTask?.cancel()
        connectTask = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        isConnected = false
    }

    // MARK: - 对外接口

    func setVolume(_ db: Double) {
        volume = db
        scheduleFlush()
    }

    func setMute(_ on: Bool) {
        muted = on
        muteDirty = true
        scheduleFlush()
    }

    // MARK: - 内部

    /// 合并短时间内的多次改动（拖动滑块会连发几十次），最多 20Hz 下发给引擎
    private func scheduleFlush() {
        guard !flushScheduled else { return }
        flushScheduled = true
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 50_000_000)
            guard let self else { return }
            self.flushScheduled = false
            await self.flush()
        }
    }

    private func flush() async {
        if flushing {
            flushAgain = true
            return
        }
        guard let t = task else {
            // 还没连上（引擎刚启动）：重连一次，连上后会补发
            if connectTask == nil { reconnect() }
            return
        }
        flushing = true
        defer { flushing = false }

        do {
            try await t.send(.string(Self.volumeCommand(volume)))
            _ = try? await t.receive() // 丢弃 ack，避免缓冲堆积
            if muteDirty {
                try await t.send(.string("{\"SetMute\": \(muted)}"))
                _ = try? await t.receive()
                muteDirty = false
            }
            isConnected = true
        } catch {
            isConnected = false
            task = nil
            reconnect()
        }
        if flushAgain {
            flushAgain = false
            await flush()
        }
    }

    private func reconnect() {
        guard connectTask == nil else { return }
        let p = port
        guard p != 0 else { return }
        connectTask = Task { [weak self] in
            guard let self else { return }
            for _ in 0..<20 {
                if Task.isCancelled { return }
                if await self.probe() {
                    self.isConnected = true
                    await self.flush()
                    return
                }
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            self.connectTask = nil
        }
    }

    /// 开一条新连接并用 GetState 探活；成功则保留连接
    private func probe() async -> Bool {
        let t = URLSession.shared.webSocketTask(with: URL(string: "ws://127.0.0.1:\(port)")!)
        t.resume()
        task = t
        do {
            try await t.send(.string("{\"GetState\": null}"))
        } catch {
            task = nil
            t.cancel(with: .goingAway, reason: nil)
            return false
        }
        let reply = await Self.receive(t, timeout: 0.8)
        if reply?.contains("result") == true { return true }
        task = nil
        t.cancel(with: .goingAway, reason: nil)
        return false
    }

    private static func receive(_ t: URLSessionWebSocketTask, timeout: Double) async -> String? {
        await withTaskGroup(of: String?.self) { group in
            group.addTask {
                guard let msg = try? await t.receive(), case .string(let s) = msg else { return nil }
                return s
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    private static func volumeCommand(_ db: Double) -> String {
        String(format: "{\"SetVolume\": %.1f}", db)
    }
}
