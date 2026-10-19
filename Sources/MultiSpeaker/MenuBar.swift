import SwiftUI
import AppKit

// MARK: - 主窗口控制：点关闭按钮 = 收进顶部状态栏

@MainActor
final class MainWindowController: NSObject, NSWindowDelegate {
    static let shared = MainWindowController()

    private weak var window: NSWindow?

    /// 关闭按钮的行为（可在「运行与日志」里关掉）：true = 收进状态栏，false = 正常关闭窗口
    var hideOnClose: Bool {
        UserDefaults.standard.object(forKey: "settings.hideOnClose") as? Bool ?? true
    }

    func attach(_ newWindow: NSWindow) {
        guard window !== newWindow else { return }
        window = newWindow
        newWindow.isReleasedWhenClosed = false
        newWindow.delegate = self
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard hideOnClose else {
            // 真关闭：丢掉引用，之后从状态栏打开会走 openWindow 重建窗口
            window = nil
            return true
        }
        hideToMenuBar()
        return false
    }

    /// 隐藏主窗口，只保留状态栏图标（同时隐藏 Dock 图标，像纯菜单栏 App）
    func hideToMenuBar() {
        window?.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
    }

    /// 显示主窗口；返回 false 表示窗口对象已不存在，需要由 SwiftUI 重新打开
    @discardableResult
    func showWindow() -> Bool {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        guard let w = window else { return false }
        w.makeKeyAndOrderFront(nil)
        return true
    }
}

/// 拿到 SwiftUI 场景所在的 NSWindow（`viewDidMoveToWindow` 时窗口一定已存在）
private final class WindowProbeView: NSView {
    var onWindow: ((NSWindow) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window { onWindow?(window) }
    }
}

struct WindowAccessor: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = WindowProbeView()
        view.onWindow = onWindow
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? WindowProbeView)?.onWindow = onWindow
    }
}

// MARK: - 状态栏图标

struct MenuBarLabel: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        // 运行时用实心图标，停止时用空心，一眼能看出当前状态
        Image(systemName: coordinator.camilla.isRunning ? "hifispeaker.2.fill" : "hifispeaker.2")
    }
}

// MARK: - 状态栏弹出面板

struct MenuBarPanel: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var settings = coordinator.settings

        VStack(alignment: .leading, spacing: 10) {
            // 状态
            HStack(spacing: 7) {
                Circle()
                    .fill(coordinator.camilla.isRunning ? Color.green : Color.secondary)
                    .frame(width: 8, height: 8)
                Text(L.t(coordinator.camilla.isRunning ? "正在播放" : "已停止"))
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(routeSummary)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            // 总音量（走 websocket 实时生效，不重启引擎）
            HStack(spacing: 8) {
                Button {
                    settings.muted.toggle()
                    coordinator.muteChanged()
                } label: {
                    Image(systemName: settings.muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .frame(width: 18)
                }
                .buttonStyle(.plain)
                .help(settings.muted ? L.t("取消静音") : L.t("静音"))

                Slider(value: $settings.volumePosition, in: 0...1)
                    .controlSize(.mini)
                    .onChange(of: settings.volumePosition) { _, _ in coordinator.volumeChanged() }

                Text(volumeLabel)
                    .font(.system(size: 10))
                    .monospacedDigit()
                    .foregroundStyle(settings.masterVolumeDb > 3 ? Color.orange : Color.secondary)
                    .frame(width: 52, alignment: .trailing)
            }

            Divider()

            // 主操作
            HStack(spacing: 8) {
                Button {
                    if coordinator.camilla.isRunning {
                        coordinator.stopEngine()
                    } else {
                        coordinator.startEngine()
                    }
                } label: {
                    Label(coordinator.camilla.isRunning ? L.t("停止") : L.t("启动"),
                          systemImage: coordinator.camilla.isRunning ? "stop.fill" : "play.fill")
                }
                .controlSize(.small)

                Button {
                    openMainWindow()
                } label: {
                    Label(L.t("打开主窗口"), systemImage: "macwindow")
                }
                .controlSize(.small)

                Spacer()

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .controlSize(.small)
                .help(L.t("退出 MultiSpeaker"))
            }

            if !coordinator.statusMessage.isEmpty {
                Text(coordinator.statusMessage)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(width: 330)
    }

    private var volumeLabel: String {
        let settings = coordinator.settings
        if settings.muted { return L.t("已静音") }
        if VolumeCurve.isSilent(settings.volumePosition) { return L.t("静音") }
        let percent = VolumeCurve.percent(forPosition: settings.volumePosition)
        let db = Int(settings.masterVolumeDb.rounded())
        return "\(percent)% · \(db > 0 ? "+" : "")\(db)dB"
    }

    private var routeSummary: String {
        let high = coordinator.devices.first { $0.uid == coordinator.settings.highDeviceUID }?.name ?? "—"
        let low = coordinator.devices.first { $0.uid == coordinator.settings.lowDeviceUID }?.name ?? "—"
        return "\(high) + \(low)"
    }

    /// 打开主窗口：优先复用已有窗口，没有就请 SwiftUI 重新开一个
    private func openMainWindow() {
        let panel = NSApp.keyWindow
        if !MainWindowController.shared.showWindow() {
            NSApp.setActivationPolicy(.regular)
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        // 收起状态栏面板
        panel?.orderOut(nil)
    }
}
