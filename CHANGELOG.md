# 更新日志

遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [1.1.0] - 2026-10-19

### 新增

- **实时音量通道**：音量/静音改走 CamillaDSP 的 websocket（`SetVolume` / `SetMute`），拖动即时生效，不再重写配置、不再重启引擎
- **感知音量曲线**：滑块位置与 dB 做分段映射（半格 −12dB、25% −26.5dB），解决"稍微调小就没声音"
- **更大音量**：上限从 0dB 提到 +12dB；超过 +3dB 时读数变橙色并提示削顶风险
- **中英双语**：全部界面文案 + 状态消息 + 错误信息支持中英文，可在「运行与日志 → 语言」切换（跟随系统 / 中文 / English），切换即时生效
- **App 名本地化**：`InfoPlist.strings`，Finder 与程序坞里的名字跟随系统语言
- **记忆页签**：重开或切语言后停在原来的页
- 英文文档：`README.en.md`、`docs/USAGE.en.md`

### 修复

- 音量滑块线性映射到 −60~0dB，用户拖到 30% 就已是 −42dB（听起来等于没声音）
- 每次拖动音量都触发 0.6 秒防抖重启，音量连续变化时音频断续
- `-g -5.0` 被 camilladsp 的 clap 当成新短选项解析，导致引擎启动即退出（改用 `-g=-5.0`）

### 变更

- 生成的 YAML 里不再包含 `master_gain` 滤镜，音量统一由 fader 控制；默认不再额外衰减 5dB
- 新增 `CamillaRemote.swift`（websocket 控制）、`VolumeCurve.swift`（音量曲线）、`L10n.swift`（双语）
- 启停开关、收起开关不再触发引擎重启

## [1.0.0] - 2026-10-19

首个可用版本。

### 新增

- 一键设置：检测 / 安装 BlackHole 2ch、创建 4 声道聚合设备、切换系统默认输出、启动引擎
- 双路分频输出：LR4（24dB/oct）分频，分频点 80–320Hz，高频链路 0–40ms 延迟补偿，两路独立增益
- 调音台：总音量、静音、分频点、延迟、双路增益、缓冲区（512/1024/2048），改动 0.6s 防抖热重启
- 进程托管：`--check` 预校验、日志流、2 秒巡检 + 看门狗自动重启（连续失败 3 次止）
- 菜单栏常驻：关闭窗口收进顶部状态栏，图标随运行状态切换实心/空心，面板内可调音量、启停、回主窗口
- 应用图标：CoreGraphics 生成的双喇叭图标（1024px icns）
- 开机自启：登录时启动 App（LaunchAgent）+ 启动后自动播放
- 麦克风权限引导：`NSMicrophoneUsageDescription` + 主动 `requestAccess`（未授权会静默无声）
- 内置 CamillaDSP v4.1.3（arm64）
- 命令行调试开关：`--cli-enumerate` / `--cli-create-aggregate` / `--cli-default-blackhole`

### 修复

- 旧版 YAML 用 `channel: 0` 在 CamillaDSP 4.x 非法，改为 `channels: [0, 1]`
- 读取音频传输类型时按 CFNumber 解析导致段错误，改为按裸 `UInt32` 读取
- 聚合设备子设备顺序反了导致声道错位/无声，改为高频设备在前并兼作时钟源
- 重建聚合设备后引擎不自动恢复，改为"先停引擎 → 重建 → 等 200ms → 按需重启"
- 配置残留 `silence_threshold` / `silence_timeout` 导致 5 秒后进入 Paused 且不再恢复，现已彻底移除
- App 退出后 camilladsp 变孤儿占住设备，加入 `willTerminate` 与 `SIGTERM/SIGINT/SIGHUP` 同步回收
- 重建后出现多个 camilladsp 实例同时抢设备
