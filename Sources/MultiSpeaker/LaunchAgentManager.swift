import Foundation
import Observation

/// 登录自启（LaunchAgent）。只在以 .app 形式运行时有效。
@MainActor
@Observable
final class LaunchAgentManager {
    var isEnabled = false
    var canEnable = true
    var message = ""

    static let label = "com.user.MultiSpeaker"

    static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    private var appBinaryPath: String? {
        let bundle = Bundle.main.bundlePath
        guard bundle.hasSuffix(".app") else { return nil }
        let exe = (Bundle.main.executableURL?.path) ?? "\(bundle)/Contents/MacOS/MultiSpeaker"
        return exe
    }

    func refresh() {
        if appBinaryPath == nil {
            canEnable = false
            isEnabled = false
            message = L.t("当前不是以 .app 运行（可能是 swift run），无法设置开机自启。")
        } else {
            canEnable = true
            isEnabled = FileManager.default.fileExists(atPath: Self.plistURL.path)
        }
    }

    func setEnabled(_ enabled: Bool) {
        guard canEnable, let exe = appBinaryPath else { return }
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(Self.label)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(exe)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>StandardOutPath</key>
            <string>/tmp/multispeaker.log</string>
            <key>StandardErrorPath</key>
            <string>/tmp/multispeaker.log</string>
        </dict>
        </plist>
        """
        if enabled {
            do {
                try plist.write(to: Self.plistURL, atomically: true, encoding: .utf8)
            } catch {
                message = L.t("写入 LaunchAgent 失败：%@", error.localizedDescription)
                return
            }
            _ = Shell.runSync("/bin/launchctl", ["bootstrap", "gui/\(getuid())", Self.plistURL.path])
            isEnabled = true
            message = L.t("已开启开机自启（日志 /tmp/multispeaker.log）")
        } else {
            _ = Shell.runSync("/bin/launchctl", ["bootout", "gui/\(getuid())/\(Self.label)"])
            try? FileManager.default.removeItem(at: Self.plistURL)
            isEnabled = false
            message = L.t("已关闭开机自启")
        }
    }
}
