import Foundation

/// 界面语言。system = 跟随系统首选语言（非中文则英文）。
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system, zh, en

    var id: String { rawValue }

    /// 语言选择器里的显示名（总是用各自的语言写，方便认）
    var menuTitle: String {
        switch self {
        case .system: return L10n.isChineseSystem ? "跟随系统（中文）" : "System (\(L10n.isChineseSystem ? "Chinese" : "English"))"
        case .zh: return "中文"
        case .en: return "English"
        }
    }
}

/// 极简本地化：用中文原文当 key，英文表做映射。
///
/// 这么做的好处是中文侧零成本（key 就是文案），漏翻时自动回落中文而不是显示 key 或空白；
/// 插值一律写成 `L.t("当前输出：%@", name)`，英文表里保留同样的 `%@`。
typealias L = L10n

enum L10n {
    static var isChineseSystem: Bool {
        (Locale.preferredLanguages.first ?? "en").hasPrefix("zh")
    }

    static var current: AppLanguage {
        let raw = UserDefaults.standard.string(forKey: "settings.language") ?? AppLanguage.system.rawValue
        return AppLanguage(rawValue: raw) ?? .system
    }

    static var isEnglish: Bool {
        switch current {
        case .en: return true
        case .zh: return false
        case .system: return !isChineseSystem
        }
    }

    static func t(_ zh: String) -> String {
        isEnglish ? (en[zh] ?? zh) : zh
    }

    static func t(_ zh: String, _ args: CVarArg...) -> String {
        String(format: t(zh), arguments: args)
    }

    // MARK: - 英文文案表

    private static let en: [String: String] = [
        // 通用
        "一键设置": "Setup",
        "调音台": "Mixer",
        "运行与日志": "Runtime & Log",
        "就绪": "Ready",
        "未完成": "Pending",
        "注意": "Attention",
        "进行中": "Working",
        "停止": "Stop",
        "启动": "Start",
        "删除": "Delete",
        "静音": "Mute",
        "已静音": "Muted",
        "取消静音": "Unmute",
        "清空": "Clear",
        "自动滚动": "Auto-scroll",
        "日志": "Log",
        "语言": "Language",

        // 链路
        "信号链路": "Signal path",
        "系统音频": "System audio",
        "CamillaDSP 分频": "CamillaDSP crossover",
        "ch1/2 高频 >%dHz → 笔记本喇叭": "ch1/2 high >%dHz → laptop speakers",
        "ch3/4 低频 <%dHz → 外接音箱": "ch3/4 low <%dHz → external speaker",

        // 一键设置
        "安装 BlackHole 2ch 虚拟声卡": "Install BlackHole 2ch",
        "已检测到 BlackHole 2ch，格式已固定为 48000Hz。": "BlackHole 2ch detected, sample rate locked at 48000 Hz.",
        "BlackHole 用来把系统输出抓进来给 CamillaDSP 处理。安装后需要到「系统设置 → 隐私与安全性」允许系统扩展并重启 Mac。":
            "BlackHole captures the system output so CamillaDSP can process it. After installing, allow the system extension in System Settings → Privacy & Security, then restart your Mac.",
        "安装（Homebrew）": "Install (Homebrew)",
        "重新检测": "Rescan",
        "下载安装包": "Download installer",
        "选择两路喇叭并创建聚合设备": "Pick two speakers and create the aggregate device",
        "高频设备（笔记本喇叭）": "High band (laptop speakers)",
        "低频设备（外接音箱）": "Low band (external speaker)",
        "%@（%dch）": "%@ (%dch)",
        "聚合设备名固定为 MultiSpeaker：ch1/ch2 接高频设备，ch3/ch4 接低频设备；时钟源=高频设备，低频设备自动开漂移修正。":
            "The aggregate is always named MultiSpeaker: ch1/ch2 drive the high band, ch3/ch4 the low band. Clock master = high device; the low device runs with drift correction.",
        "创建 / 重建聚合设备": "Create / rebuild aggregate",
        "MultiSpeaker 在线（objectID %d）": "MultiSpeaker online (objectID %d)",
        "系统默认输出 → BlackHole 2ch": "System output → BlackHole 2ch",
        "设为默认输出": "Set as default output",
        "切回内置喇叭": "Switch back to built-in",
        "当前默认输出：%@": "Current default output: %@",
        "CamillaDSP 引擎（已内置 v4.1.3）": "CamillaDSP engine (v4.1.3 bundled)",
        "未找到 camilladsp 可执行文件": "camilladsp executable not found",
        "一键完成全部设置并开始播放": "One-click setup and start playing",

        // 调音台
        "分频结构": "Crossover topology",
        "L/R 各复制两路": "L/R duplicated",
        "ch0/1 → HP %dHz + 延迟 %dms → 笔记本": "ch0/1 → HP %dHz + %dms delay → laptop",
        "ch2/3 → LP %dHz → 外接音箱": "ch2/3 → LP %dHz → external speaker",
        "LR4（24dB/oct）分频，分频点处同相叠加、衔接平直。":
            "LR4 (24 dB/oct) crossover: the two bands sum in phase at the crossover point for a flat handover.",
        "音量": "Volume",
        "总音量": "Master volume",
        "输出走 BlackHole 时键盘音量键会失效，用这里控制总音量。":
            "The keyboard volume keys do not work through BlackHole — use this slider instead.",
        "音量会立即生效（不需要重启引擎）。最右端留了 +12dB 增益余量。":
            "Changes apply instantly with no engine restart. The top of the range has +12 dB of gain headroom.",
        "切换到 %@ 输出": "Switch output to %@",
        "增益已达 %@dB，大动态曲目可能削顶": "Gain is %@ dB — loud tracks may clip",
        "分频点": "Crossover frequency",
        "人声发闷往上提，低频空洞往下降。四个滤波器会同步修改。":
            "Raise it if vocals sound muffled, lower it if bass feels hollow. All four filters move together.",
        "高频链路延迟补偿": "High-path delay",
        "内置喇叭链路更快，加延迟对齐显示器链路；鼓点发散/拖沓时以 2ms 步进试听。":
            "The laptop path is faster; add delay to align it with the external path. Step through 2 ms at a time when drums sound smeared.",
        "笔记本喇叭增益": "Laptop speaker gain",
        "先把外接音箱物理音量拧到适中，再用增益微调两路响度。":
            "Set the external speaker's physical volume first, then trim the two paths here.",
        "外接音箱增益": "External speaker gain",
        "缓冲区（爆音/断续时调大）": "Buffer size (raise if crackling)",
        "512（延迟最低）": "512 (lowest latency)",
        "1024（更稳）": "1024 (safer)",
        "2048（最稳）": "2048 (safest)",
        "怎么调": "How to tune",
        "调音顺序：① 电平平衡 → ② 分频点 → ③ 延迟对齐 → ④ 相位检查。":
            "Order: 1) level match → 2) crossover point → 3) delay alignment → 4) phase check.",
        "改动会自动保存；若 CamillaDSP 正在运行，0.6 秒后自动热重启生效。":
            "Changes are saved automatically. If CamillaDSP is running it hot-restarts 0.6 s later.",
        "音量与静音不需要重启；分频/延迟/增益改动会热重启引擎。":
            "Volume and mute apply without a restart; crossover, delay and gain changes hot-restart the engine.",
        "两路增益只作用于各自频段：调它改变的是音色与左右能量占比，不是整体音量。要整体调轻调重请用上面的总音量。":
            "Each path gain is band-limited: it changes timbre and the energy split, not the overall level. Use master volume for that.",

        // 运行与日志
        "CamillaDSP 运行中": "CamillaDSP running",
        "CamillaDSP 已停止": "CamillaDSP stopped",
        "启动选项": "Startup",
        "开机自动启动（并自动开始播放）": "Auto-start on launch (and begin playing)",
        "登录时启动本 App": "Start this app at login",
        "把系统输出切回内置喇叭": "Switch system output back to built-in",
        "点关闭按钮时收进顶部状态栏": "Close button hides to the menu bar",
        "开启时关闭窗口不会退出程序：Dock 图标隐藏，点菜单栏的音箱图标可随时调音量、启停或打开主窗口。":
            "When on, closing the window keeps the app alive: the Dock icon hides, and the speaker icon in the menu bar controls volume, start/stop and the main window.",
        "音频设备已就绪": "Audio devices ready",

        // 菜单栏
        "正在播放": "Playing",
        "已停止": "Stopped",
        "打开主窗口": "Open window",
        "退出 MultiSpeaker": "Quit MultiSpeaker",
        "声音输出": "Output",

        // 状态消息
        "未获得麦克风权限：CamillaDSP 将收不到音。请到「系统设置 → 隐私与安全性 → 麦克风」允许 MultiSpeaker。":
            "Microphone permission denied: CamillaDSP will receive silence. Allow MultiSpeaker in System Settings → Privacy & Security → Microphone.",
        "麦克风权限被拒绝：请到「系统设置 → 隐私与安全性 → 麦克风」允许 MultiSpeaker，否则没有声音。":
            "Microphone permission denied. Allow MultiSpeaker in System Settings → Privacy & Security → Microphone, otherwise there will be no sound.",
        "聚合设备 MultiSpeaker 已消失（常见原因：显示器休眠导致其音频设备离线）。唤醒显示器后点「创建/重建」。":
            "The MultiSpeaker aggregate device disappeared (usually because the display went to sleep and its audio device went offline). Wake it up, then hit Create / rebuild.",
        "CamillaDSP 连续 3 次自动重启失败，请检查日志后手动启动。":
            "CamillaDSP failed to restart 3 times in a row. Check the log and start it manually.",
        "检测到 CamillaDSP 已退出，自动重启（第 %d 次）": "CamillaDSP exited; restarting automatically (attempt %d)",
        "CamillaDSP 运行中（已自动恢复）": "CamillaDSP running (auto-recovered)",
        "第 1 步未完成：BlackHole 2ch 未安装。请先安装并重启 Mac。":
            "Step 1 incomplete: BlackHole 2ch is not installed. Install it and restart your Mac.",
        "聚合设备 + 默认输出配置完成，正在启动 CamillaDSP…":
            "Aggregate device and default output configured. Starting CamillaDSP…",
        "全部就绪：高频→%@，低频→%@": "All set: high → %@, low → %@",
        "请先选择高频和低频设备。": "Pick both the high and low devices first.",
        "已重建聚合设备（高频=%@ / 低频=%@），CamillaDSP 已重启":
            "Aggregate rebuilt (high = %@ / low = %@); CamillaDSP restarted",
        "已创建聚合设备 MultiSpeaker（高频=%@ / 低频=%@）": "Aggregate MultiSpeaker created (high = %@ / low = %@)",
        "已删除聚合设备 MultiSpeaker": "Aggregate MultiSpeaker deleted",
        "未找到 BlackHole 2ch": "BlackHole 2ch not found",
        "系统默认输出已切换为 BlackHole 2ch": "System default output switched to BlackHole 2ch",
        "系统默认输出已切回 %@": "System default output switched back to %@",
        "没有声音？先看这里：① 麦克风权限 ② 默认输出是否被抢走 ③ 是否静音。":
            "No sound? Check in this order: 1) microphone permission 2) default output still BlackHole? 3) muted?",

        // 引擎错误
        "找不到 camilladsp 可执行文件（已内置在 App 内，若从源码运行请放到 ~/camilladsp/）":
            "camilladsp not found. It is bundled in the app; when running from source put it in ~/camilladsp/",
        "配置校验失败：%@": "Config validation failed: %@",
        "CamillaDSP 异常退出（code %d），请检查日志；常见原因是聚合设备 MultiSpeaker 不在线（显示器休眠）或 BlackHole 未设为默认输出。":
            "CamillaDSP exited unexpectedly (code %d). Check the log — usually the MultiSpeaker aggregate is offline (display asleep) or BlackHole is not the default output.",
        "CamillaDSP 已停止（用户操作）": "CamillaDSP stopped by user",
        "CamillaDSP 已退出": "CamillaDSP exited",

        // BlackHole / 自启
        "检测到 BlackHole 2ch 已安装": "BlackHole 2ch detected",
        "正在通过 Homebrew 安装…": "Installing via Homebrew…",
        "Homebrew 安装失败：%@": "Homebrew install failed: %@",
        "未安装 Homebrew，请用「下载安装包」或手动安装。":
            "Homebrew not found — use Download installer or install manually.",
        "正在下载官方安装包…": "Downloading the official installer…",
        "下载失败：%@": "Download failed: %@",
        "已下载，请按提示完成安装并重启 Mac": "Downloaded. Finish the installer and restart your Mac",
        "安装包已保存到下载目录": "Installer saved to Downloads",
        "已开启登录自启": "Launch at login enabled",
        "已关闭登录自启": "Launch at login disabled",
        "写入自启文件失败：%@": "Failed to write the login item: %@",
        // 补充
        "BlackHole 2ch 未安装，无法启动。": "BlackHole 2ch is not installed — cannot start.",
        "Homebrew 安装失败（退出码 %d），请改用「下载安装包」方式。": "Homebrew install failed (exit code %d) — use Download installer instead.",
        "MultiSpeaker · 多喇叭合奏": "MultiSpeaker",
        "camilladsp --check 退出码 %d": "camilladsp --check exited with %d",
        "两路设备都必须是立体声（2ch）。当前：%@=%dch，%@=%dch": "Both devices must be stereo (2ch). Now: %@=%dch, %@=%dch",
        "写入 LaunchAgent 失败：%@": "Failed to write the LaunchAgent: %@",
        "创建聚合设备失败": "Failed to create the aggregate device",
        "安装完成。请到「系统设置 → 隐私与安全性」允许系统扩展，然后重启 Mac。": "Installation finished. Allow the system extension in System Settings → Privacy & Security, then restart your Mac.",
        "已下载到「下载」文件夹，正在打开安装器…": "Downloaded to Downloads. Opening the installer…",
        "已关闭开机自启": "Launch at login disabled",
        "已开启开机自启（日志 /tmp/multispeaker.log）": "Launch at login enabled (log: /tmp/multispeaker.log)",
        "当前不是以 .app 运行（可能是 swift run），无法设置开机自启。": "Not running as a .app bundle (maybe swift run) — cannot enable launch at login.",
        "当前输出：%@": "Current output: %@",
        "未知": "Unknown",
        "正在从 GitHub 获取最新安装包…": "Fetching the latest installer from GitHub…",
        "正在安装 BlackHole 2ch…": "Installing BlackHole 2ch…",
        "正在通过 Homebrew 安装（可能需要输入管理员密码）…": "Installing via Homebrew (may ask for admin password)…",
        "没有找到 BlackHole 2ch 安装包。": "BlackHole 2ch installer not found.",
        "聚合设备 MultiSpeaker 不存在，请先创建。": "The MultiSpeaker aggregate does not exist — create it first.",
        "设置系统默认输出失败": "Failed to set the system default output",
        "调音参数": "Tuning parameters",

    ]
}
