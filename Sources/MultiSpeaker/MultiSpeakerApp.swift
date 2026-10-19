import SwiftUI
import AppKit

/// CLI 模式检测（全局常量，早于任何对象初始化求值）。
private let isCLIMode = CommandLine.arguments.contains { $0.hasPrefix("--cli-") }

@main
struct MultiSpeakerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var coordinator = AppCoordinator(autoStart: !isCLIMode)

    init() {
        CLI.handleIfNeeded()
    }

    var body: some Scene {
        Window("MultiSpeaker · 多喇叭合奏", id: "main") {
            ContentView()
                .environment(coordinator)
        }
        .defaultSize(width: 800, height: 600)
        .windowResizability(.contentMinSize)

        // 顶部状态栏：关掉主窗口后仍可从这里控制
        MenuBarExtra {
            MenuBarPanel()
                .environment(coordinator)
        } label: {
            MenuBarLabel()
                .environment(coordinator)
        }
        .menuBarExtraStyle(.window)
    }
}

/// 处理「窗口已收起时再点一次 App 图标」等系统级回调
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            MainWindowController.shared.showWindow()
        }
        return true
    }
}

/// 给开发和排查用的命令行模式（不弹 GUI）：
///   MultiSpeaker --cli-enumerate
///   MultiSpeaker --cli-create-aggregate <highUID> <lowUID>
///   MultiSpeaker --cli-default-blackhole
private enum CLI {
    static func handleIfNeeded() {
        guard isCLIMode else { return }
        let args = CommandLine.arguments
        if args.contains("--cli-enumerate") {
            enumerate()
            exit(0)
        }
        if let i = args.firstIndex(of: "--cli-create-aggregate") {
            create(args, i)
            exit(0)
        }
        if args.contains("--cli-default-blackhole") {
            defaultBlackHole()
            exit(0)
        }
        FileHandle.standardError.write("unknown --cli- option\n".data(using: .utf8)!)
        exit(2)
    }

    static func enumerate() {
        print("== 输出设备 ==")
        for d in AudioEngine.allOutputDevices() {
            var flags: [String] = []
            if d.isBuiltin { flags.append("builtin") }
            if d.isBlackHole { flags.append("blackhole") }
            print("\(d.objectID)\t\(d.uid)\t\"\(d.name)\"\tch=\(d.outputChannels)\t\(flags.joined(separator: ","))")
        }
        if let bh = AudioEngine.findBlackHole() {
            let rate = AudioEngine.nominalSampleRate(bh.objectID).map { String(Int($0)) } ?? "?"
            print("BlackHole 2ch: 已安装（rate=\(rate)Hz）")
        } else {
            print("BlackHole 2ch: 未安装")
        }
        if let agg = AudioEngine.findAggregate() {
            print("聚合设备 \(AudioEngine.aggregateName): 已存在（\(agg.uid)）")
        } else {
            print("聚合设备 \(AudioEngine.aggregateName): 不存在")
        }
        if let def = AudioEngine.defaultOutput() {
            print("默认输出: \(def.name)")
        }
    }

    static func create(_ args: [String], _ i: Int) {
        guard args.count > i + 2 else {
            FileHandle.standardError.write("usage: --cli-create-aggregate <highUID> <lowUID>\n".data(using: .utf8)!)
            exit(2)
        }
        let devices = AudioEngine.allOutputDevices()
        guard let high = devices.first(where: { $0.uid == args[i + 1] }),
              let low = devices.first(where: { $0.uid == args[i + 2] }) else {
            FileHandle.standardError.write("device uid not found\n".data(using: .utf8)!)
            exit(3)
        }
        if let existing = AudioEngine.findAggregate() {
            AudioEngine.destroyAggregateDevice(existing.objectID)
        }
        do {
            let id = try AudioEngine.createAggregateDevice(high: high, low: low)
            print("created aggregate \(AudioEngine.aggregateName), objectID=\(id)")
        } catch {
            FileHandle.standardError.write("error: \(error)\n".data(using: .utf8)!)
            exit(4)
        }
    }

    static func defaultBlackHole() {
        guard let bh = AudioEngine.findBlackHole() else {
            FileHandle.standardError.write("blackhole missing\n".data(using: .utf8)!)
            exit(3)
        }
        do {
            try AudioEngine.setDefaultOutput(bh.objectID)
            print("default output -> \(bh.name)")
        } catch {
            FileHandle.standardError.write("error: \(error)\n".data(using: .utf8)!)
            exit(4)
        }
    }
}
