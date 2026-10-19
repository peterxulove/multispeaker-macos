# 更新日志

遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

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
