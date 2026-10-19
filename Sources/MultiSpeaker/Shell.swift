import Foundation

/// 跑外部命令的小工具。
enum Shell {
    /// 异步执行，返回退出码。`onLine` 在后台队列调用（调用方需自行 hop 回主线程）。
    static func run(_ launchPath: String, _ arguments: [String], onLine: @escaping @Sendable (String) -> Void) async -> Int32 {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: launchPath)
                process.arguments = arguments
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: -1)
                    return
                }
                streamLines(pipe.fileHandleForReading, onLine: onLine)
                process.waitUntilExit()
                continuation.resume(returning: process.terminationStatus)
            }
        }
    }

    /// 阻塞读取 FileHandle 直到 EOF，按行回调（每行去掉换行符，空行忽略）。
    /// 纯同步函数，不含并发捕获，可在任意队列调用。
    static func streamLines(_ handle: FileHandle, onLine: @escaping @Sendable (String) -> Void) {
        var buffer = Data()
        while true {
            let chunk = handle.availableData // 阻塞读，EOF 时返回空
            if chunk.isEmpty { break }
            buffer.append(chunk)
            while let range = buffer.range(of: Data([0x0A])) {
                let lineData = buffer.subdata(in: 0..<range.lowerBound)
                buffer.removeSubrange(0...range.lowerBound)
                if let line = String(data: lineData, encoding: .utf8), !line.isEmpty {
                    onLine(line)
                }
            }
        }
        if !buffer.isEmpty, let line = String(data: buffer, encoding: .utf8), !line.isEmpty {
            onLine(line)
        }
    }

    /// 同步执行（只用于 launchctl 这类秒退的命令），返回退出码。
    @discardableResult
    static func runSync(_ launchPath: String, _ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try? process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }
}
