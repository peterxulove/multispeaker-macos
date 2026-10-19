import SwiftUI

struct ContentView: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        TabView {
            SetupView()
                .tabItem { Label("一键设置", systemImage: "gear") }
                .tag(0)
            TuningView()
                .tabItem { Label("调音台", systemImage: "slider.vertical.3") }
                .tag(1)
            ControlView()
                .tabItem { Label("运行与日志", systemImage: "waveform.and.mic") }
                .tag(2)
        }
        .frame(minWidth: 760, minHeight: 560)
        .background(
            WindowAccessor { window in
                MainWindowController.shared.attach(window)
            }
        )
    }
}

// MARK: - 一键设置

private enum StepState {
    case ok, pending, warn, busy

    var color: Color {
        switch self {
        case .ok: return .green
        case .pending: return .gray
        case .warn: return .orange
        case .busy: return .blue
        }
    }

    var title: String {
        switch self {
        case .ok: return "就绪"
        case .pending: return "未完成"
        case .warn: return "注意"
        case .busy: return "进行中"
        }
    }
}

private struct StatusDot: View {
    let state: StepState
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(state.color)
                .frame(width: 9, height: 9)
            Text(state.title)
                .font(.caption)
                .foregroundStyle(state.color)
        }
        .fixedSize()
    }
}

private struct StepCard<Content: View>: View {
    let index: String
    let title: String
    let state: StepState
    @ViewBuilder var content: Content

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
        } label: {
            HStack {
                Text("\(index)  \(title)")
                    .font(.headline)
                Spacer()
                StatusDot(state: state)
            }
        }
    }
}

private func pill(_ text: String, color: Color) -> some View {
    Text(text)
        .font(.caption)
        .lineLimit(1)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.14), in: Capsule())
        .foregroundStyle(color)
        .fixedSize()
}

private func chainArrow() -> some View {
    Image(systemName: "arrow.right")
        .font(.caption)
        .foregroundStyle(.tertiary)
        .fixedSize()
}

struct SetupView: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        @Bindable var settings = coordinator.settings

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // 链路图
                GroupBox {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            pill("系统音频", color: .primary)
                            chainArrow()
                            pill("BlackHole 2ch", color: .purple)
                            chainArrow()
                            pill("CamillaDSP 分频", color: .blue)
                            chainArrow()
                            pill("MultiSpeaker 4ch", color: .teal)
                            chainArrow()
                            VStack(alignment: .leading, spacing: 3) {
                                pill("ch1/2 高频 >\(Int(settings.crossoverHz))Hz → 笔记本喇叭", color: .orange)
                                pill("ch3/4 低频 <\(Int(settings.crossoverHz))Hz → 外接音箱", color: .indigo)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } label: {
                    Text("信号链路").font(.headline)
                }

                // 第 1 步：BlackHole
                StepCard(index: "1", title: "安装 BlackHole 2ch 虚拟声卡", state: coordinator.blackhole.isInstalled ? .ok : (coordinator.blackhole.isInstalling ? .busy : .pending)) {
                    VStack(alignment: .leading, spacing: 8) {
                        if coordinator.blackhole.isInstalled {
                            Text("已检测到 BlackHole 2ch，格式已固定为 48000Hz。")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("BlackHole 用来把系统输出抓进来给 CamillaDSP 处理。安装后需要到「系统设置 → 隐私与安全性」允许系统扩展并重启 Mac。")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            if !coordinator.blackhole.isInstalled {
                                Button {
                                    coordinator.blackhole.install()
                                } label: {
                                    Label("安装（Homebrew）", systemImage: "arrow.down.circle")
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(coordinator.blackhole.isInstalling)
                            }
                            Button("重新检测") { coordinator.refreshDevices() }
                            Button("下载安装包") { Task { await coordinator.blackhole.installWithPackage() } }
                        }
                        if !coordinator.blackhole.lastMessage.isEmpty {
                            Text(coordinator.blackhole.lastMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }

                // 第 2 步：设备与聚合
                StepCard(index: "2", title: "选择两路喇叭并创建聚合设备", state: coordinator.aggregateDevice != nil ? .ok : .pending) {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("高频设备（笔记本喇叭）", selection: $settings.highDeviceUID) {
                            ForEach(coordinator.devices) { d in
                                Text("\(d.name)（\(d.outputChannels)ch）").tag(d.uid as String?)
                            }
                        }
                        Picker("低频设备（外接音箱）", selection: $settings.lowDeviceUID) {
                            ForEach(coordinator.devices) { d in
                                Text("\(d.name)（\(d.outputChannels)ch）").tag(d.uid as String?)
                            }
                        }
                        Text("聚合设备名固定为 MultiSpeaker：ch1/ch2 接高频设备，ch3/ch4 接低频设备；时钟源=高频设备，低频设备自动开漂移修正。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Button {
                                coordinator.createAggregate()
                            } label: {
                                Label("创建 / 重建聚合设备", systemImage: "plus.square")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(coordinator.isBusy)
                            Button("删除", role: .destructive) { coordinator.destroyAggregate() }
                                .disabled(coordinator.aggregateDevice == nil)
                            if let agg = coordinator.aggregateDevice {
                                Text("MultiSpeaker 在线（objectID \(agg.objectID)）")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }

                // 第 3 步：默认输出
                StepCard(index: "3", title: "系统默认输出 → BlackHole 2ch", state: (coordinator.blackHoleDevice != nil && coordinator.defaultOutputDevice?.isBlackHole == true) ? .ok : .pending) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Button {
                                coordinator.setBlackHoleAsDefault()
                            } label: {
                                Label("设为默认输出", systemImage: "speaker.wave.2")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(coordinator.blackHoleDevice == nil)
                            Button("切回内置喇叭") { coordinator.restoreBuiltinOutput() }
                        }
                        Text("当前默认输出：\(coordinator.defaultOutputDevice?.name ?? "未知")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // 第 4 步：CamillaDSP
                StepCard(index: "4", title: "CamillaDSP 引擎（已内置 v4.1.3）", state: coordinator.camilla.binaryPath != nil ? .ok : .warn) {
                    Text(coordinator.camilla.binaryPath ?? "未找到 camilladsp 可执行文件")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                // 底部操作
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        coordinator.setupEverything()
                    } label: {
                        Label("一键完成全部设置并开始播放", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(coordinator.isBusy)

                    if !coordinator.aggregateWarning.isEmpty {
                        Label(coordinator.aggregateWarning, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !coordinator.statusMessage.isEmpty {
                        Text(coordinator.statusMessage)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 4)
            }
            .padding(16)
        }
    }
}

// MARK: - 调音台

private struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String
    var hint: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value, specifier: "%.1f") \(unit)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range, step: step)
            if !hint.isEmpty {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct TuningView: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        @Bindable var settings = coordinator.settings

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            pill("stereo in", color: .primary)
                            chainArrow()
                            pill("L/R 各复制两路", color: .blue)
                            chainArrow()
                            VStack(alignment: .leading, spacing: 3) {
                                pill("ch0/1 → HP \(Int(settings.crossoverHz))Hz + 延迟 \(Int(settings.delayMs))ms → 笔记本", color: .orange)
                                pill("ch2/3 → LP \(Int(settings.crossoverHz))Hz → 外接音箱", color: .indigo)
                            }
                        }
                        Text("LR4（24dB/oct）分频，分频点处同相叠加、衔接平直。")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(6)
                } label: {
                    Text("分频结构").font(.headline)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        SliderRow(title: "总音量", value: $settings.masterVolumeDb, range: -60...0, step: 1, unit: "dB",
                                  hint: "输出走 BlackHole 时键盘音量键会失效，用这里控制总音量。")
                        Toggle("静音", isOn: $settings.muted)
                        Divider()
                        SliderRow(title: "分频点", value: $settings.crossoverHz, range: 80...320, step: 5, unit: "Hz",
                                  hint: "人声发闷往上提，低频空洞往下降。四个滤波器会同步修改。")
                        SliderRow(title: "高频链路延迟补偿", value: $settings.delayMs, range: 0...40, step: 2, unit: "ms",
                                  hint: "内置喇叭链路更快，加延迟对齐显示器链路；鼓点发散/拖沓时以 2ms 步进试听。")
                        Divider()
                        SliderRow(title: "笔记本喇叭增益", value: $settings.gainBuiltinDb, range: -24...6, step: 0.5, unit: "dB",
                                  hint: "先把外接音箱物理音量拧到适中，再用增益微调两路响度。")
                        SliderRow(title: "外接音箱增益", value: $settings.gainMonitorDb, range: -24...6, step: 0.5, unit: "dB")
                        Divider()
                        Picker("缓冲区（爆音/断续时调大）", selection: $settings.chunksize) {
                            Text("512（延迟最低）").tag(512)
                            Text("1024（更稳）").tag(1024)
                            Text("2048（最稳）").tag(2048)
                        }
                    }
                    .padding(6)
                } label: {
                    Text("调音参数").font(.headline)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("调音顺序：① 电平平衡 → ② 分频点 → ③ 延迟对齐 → ④ 相位检查。")
                            .font(.callout)
                        Text("改动会自动保存；若 CamillaDSP 正在运行，0.6 秒后自动热重启生效。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(6)
                } label: {
                    Text("怎么调").font(.headline)
                }
            }
            .padding(16)
        }
        .onChange(of: settings.crossoverHz) { _, _ in coordinator.settingsChanged() }
        .onChange(of: settings.delayMs) { _, _ in coordinator.settingsChanged() }
        .onChange(of: settings.gainBuiltinDb) { _, _ in coordinator.settingsChanged() }
        .onChange(of: settings.gainMonitorDb) { _, _ in coordinator.settingsChanged() }
        .onChange(of: settings.masterVolumeDb) { _, _ in coordinator.settingsChanged() }
        .onChange(of: settings.muted) { _, _ in coordinator.settingsChanged() }
        .onChange(of: settings.chunksize) { _, _ in coordinator.settingsChanged() }
    }
}

// MARK: - 运行与日志

struct ControlView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @State private var autoScroll = true

    var body: some View {
        @Bindable var settings = coordinator.settings

        VStack(alignment: .leading, spacing: 14) {
            // 状态 + 主按钮
            GroupBox {
                HStack(spacing: 12) {
                    Circle()
                        .fill(coordinator.camilla.isRunning ? .green : .gray)
                        .frame(width: 12, height: 12)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(coordinator.camilla.isRunning ? "CamillaDSP 运行中" : "CamillaDSP 已停止")
                            .font(.headline)
                        if !coordinator.statusMessage.isEmpty {
                            Text(coordinator.statusMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if coordinator.camilla.isRunning {
                        Button("停止", role: .destructive) { coordinator.stopEngine() }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                    } else {
                        Button("启动") { coordinator.startEngine() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                    }
                }
                .padding(6)
            }

            if !coordinator.camilla.lastErrorMessage.isEmpty {
                Label(coordinator.camilla.lastErrorMessage, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // 自启 / 恢复
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("开机自动启动（并自动开始播放）", isOn: $settings.startOnLaunch)
                        .onChange(of: settings.startOnLaunch) { _, new in
                            coordinator.settingsChanged()
                        }
                    HStack {
                        Toggle("登录时启动本 App", isOn: Binding(
                            get: { coordinator.launcher.isEnabled },
                            set: { coordinator.toggleAutostart($0) }
                        ))
                        .disabled(!coordinator.launcher.canEnable)
                        Button("把系统输出切回内置喇叭") { coordinator.restoreBuiltinOutput() }
                    }
                    Toggle("点关闭按钮时收进顶部状态栏", isOn: $settings.hideOnClose)
                        .onChange(of: settings.hideOnClose) { _, _ in
                            coordinator.settingsChanged()
                        }
                    Text("开启时关闭窗口不会退出程序：Dock 图标隐藏，点菜单栏的音箱图标可随时调音量、启停或打开主窗口。")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                    if !coordinator.launcher.message.isEmpty {
                        Text(coordinator.launcher.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(6)
            } label: {
                Text("启动选项").font(.headline)
            }

            // 日志
            GroupBox {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(coordinator.camilla.logLines.indices, id: \.self) { i in
                                let line = coordinator.camilla.logLines[i]
                                Text(line)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(line.hasPrefix("✗") ? .red : .secondary)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(i)
                            }
                        }
                        .padding(6)
                    }
                    .onChange(of: coordinator.camilla.logLines.count) { _, _ in
                        if autoScroll, !coordinator.camilla.logLines.isEmpty {
                            proxy.scrollTo(coordinator.camilla.logLines.count - 1, anchor: .bottom)
                        }
                    }
                }
            } label: {
                HStack {
                    Text("日志").font(.headline)
                    Spacer()
                    Toggle("自动滚动", isOn: $autoScroll)
                        .toggleStyle(.checkbox)
                        .font(.caption)
                    Button("清空") { coordinator.camilla.clearLog() }
                        .font(.caption)
                }
            }
        }
        .padding(16)
    }
}
