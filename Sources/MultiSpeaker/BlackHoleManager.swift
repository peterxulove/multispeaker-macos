import AppKit
import Foundation
import Observation

/// BlackHole 2ch 虚拟声卡的检测与安装。
@MainActor
@Observable
final class BlackHoleManager {
    var isInstalled = false
    var isInstalling = false
    var installLog: [String] = []
    var lastMessage = ""

    private var installTask: Task<Void, Never>?

    func refresh() {
        isInstalled = AudioEngine.findBlackHole() != nil
    }

    /// 优先走 Homebrew；没有 brew 则下载官方 pkg 并交给“安装器”。
    func install() {
        guard !isInstalling else { return }
        isInstalling = true
        installLog.removeAll()
        lastMessage = L.t("正在安装 BlackHole 2ch…")
        installTask = Task { [weak self] in
            guard let self else { return }
            defer { self.isInstalling = false }
            if FileManager.default.isExecutableFile(atPath: "/opt/homebrew/bin/brew")
                || FileManager.default.isExecutableFile(atPath: "/usr/local/bin/brew") {
                await self.installWithBrew()
            } else {
                await self.installWithPackage()
            }
        }
    }

    private func installWithBrew() async {
        lastMessage = L.t("正在通过 Homebrew 安装（可能需要输入管理员密码）…")
        var brew = "/opt/homebrew/bin/brew"
        if !FileManager.default.isExecutableFile(atPath: brew) { brew = "/usr/local/bin/brew" }
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        // Shell.run 继承 App 环境，PATH 已够用
        let code = await Shell.run(brew, ["install", "--cask", "blackhole-2ch"]) { [weak self] line in
            Task { @MainActor in
                self?.installLog.append(line)
                if self!.installLog.count > 300 { self!.installLog.removeFirst() }
            }
        }
        if code == 0 {
            lastMessage = L.t("安装完成。请到「系统设置 → 隐私与安全性」允许系统扩展，然后重启 Mac。")
        } else {
            lastMessage = L.t("Homebrew 安装失败（退出码 %d），请改用「下载安装包」方式。", code)
        }
    }

    func installWithPackage() async {
        lastMessage = L.t("正在从 GitHub 获取最新安装包…")
        guard let url = URL(string: "https://api.github.com/repos/ExistentialAudio/BlackHole/releases/latest") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let assets = json["assets"] as? [[String: Any]],
                  let asset = assets.first(where: { ($0["name"] as? String)?.contains("2ch") == true
                        && ($0["name"] as? String)?.hasSuffix(".pkg") == true }),
                  let name = asset["name"] as? String,
                  let downloadURLString = asset["browser_download_url"] as? String,
                  let downloadURL = URL(string: downloadURLString) else {
                lastMessage = L.t("没有找到 BlackHole 2ch 安装包。")
                return
            }
            let dest = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Downloads/\(name)")
            let (tmpLocal, _) = try await URLSession.shared.download(from: downloadURL)
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.copyItem(at: tmpLocal, to: dest)
            lastMessage = L.t("已下载到「下载」文件夹，正在打开安装器…")
            NSWorkspace.shared.open(dest)
        } catch {
            lastMessage = L.t("下载失败：%@", error.localizedDescription)
        }
    }
}
