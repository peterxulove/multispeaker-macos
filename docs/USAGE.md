# MultiSpeaker 使用手册

> 面向实际使用：从装到调，从排障到卸载。原理与代码结构见 [README](../README.md)。

## 目录

- [1. 安装与首次启动](#1-安装与首次启动)
- [2. 五步跑通](#2-五步跑通)
- [3. 调音实战](#3-调音实战)
- [4. 菜单栏与日常操作](#4-菜单栏与日常操作)
- [5. 故障排查树](#5-故障排查树)
- [6. 客观验收：用麦克风量化](#6-客观验收用麦克风量化)
- [7. 文件位置与命令行工具](#7-文件位置与命令行工具)
- [8. 升级与卸载](#8-升级与卸载)

---

## 1. 安装与首次启动

### 1.1 放 App

解压 `MultiSpeaker.zip`，把 `MultiSpeaker.app` 拖进 `/Applications`。

App 用了 ad-hoc 签名（没有 Apple 开发者账号做公证），所以：

- **首次打开**：Finder 里右键 App → 打开 → 弹窗里再点"打开"
- 如果提示"已损坏，无法打开"，执行一次：

```bash
xattr -dr com.apple.quarantine /Applications/MultiSpeaker.app
```

### 1.2 装 BlackHole 2ch

BlackHole 是系统级音频驱动（不是普通 App），装它需要管理员密码。

- 在 App「一键设置」第 1 步点 **安装（Homebrew）**：需要机器上已有 Homebrew
- 或者点 **下载安装包**：走官方 pkg
- 也可以手动：`brew install --cask blackhole-2ch`

装完后系统音频服务有时不会立刻发现新设备，执行：

```bash
sudo launchctl kickstart -k system/com.apple.audio.coreaudiod
```

仍然看不到设备就重启一次 Mac。

### 1.3 麦克风权限（务必给）

第一次点「一键完成全部设置」时会弹权限请求。**必须允许。**

> **为什么放音还要麦克风？** BlackHole 是 input-capable 的虚拟设备，CamillaDSP 需要打开它的输入端口把声音抓出来处理。未授权时 CoreAudio 不报错，只是返回全零样本 —— 界面上一切正常，CamillaDSP 也显示 Running，但**一点声音都没有**。

权限被拒过的补救：

1. 系统设置 → 隐私与安全性 → 麦克风 → 打开 MultiSpeaker
2. 完全退出 App（菜单栏图标 → 电源按钮，或 `killall MultiSpeaker`）再重开

---

## 2. 五步跑通

### 步骤 1 · 确认 BlackHole 就绪

第 1 步卡片变绿，说明系统里有 `BlackHole 2ch` 且采样率是 48000Hz。

### 步骤 2 · 选两路喇叭，建聚合设备

| 选项 | 建议 |
|---|---|
| 高频设备（笔记本喇叭） | `MacBook Pro 扬声器`（BuiltInSpeakerDevice） |
| 低频设备（外接音箱） | 你的外接音箱 / 显示器 / USB 声卡 |

点 **创建 / 重建聚合设备**。成功后出现绿色提示 `MultiSpeaker 在线（objectID xxx）`。

聚合设备内部结构（固定）：

```
MultiSpeaker（4ch）
├── ch1 / ch2  →  高频设备
├── ch3 / ch4  →  低频设备
├── 时钟源（master） = 高频设备
└── 低频设备 drift correction = 1
```

> 顺序不能反。高频设备在前是因为它同时充当聚合设备的时钟源；反了会声道错位、甚至完全没声。

### 步骤 3 · 系统默认输出切到 BlackHole

这一步让所有 App 的声音先进入虚拟声卡，再被 CamillaDSP 捞走处理。

点 **设为默认输出**，卡片变绿即完成。想临时恢复原状点「切回内置喇叭」。

### 步骤 4 · CamillaDSP 引擎

内置 v4.1.3，卡片会显示实际路径。若是黄色（未找到二进制），说明 App 包被改动过，重新解压一份。

### 步骤 5 · 一键开始

点 **一键完成全部设置并开始播放**。它会串行完成：建聚合设备 → 设默认输出 → 启动引擎 → 开始播放。

想验证真的在响：随便放首歌，「运行与日志」页应该看到 CamillaDSP 的 `Playback` 日志持续滚动。

---

## 3. 调音实战

调音顺序不要乱：**先电平 → 再分频 → 再延迟 → 最后听相位**。

### 3.1 电平平衡

1. 把外接音箱的**物理音量旋钮**拧到一个日常位置（不要用 App 增益当主音量）
2. 放一首人声居中的歌，闭眼听人声位置是否偏左/偏右
3. 如果人声往笔记本方向靠 → 笔记本太响，把"笔记本喇叭增益"往下调 1~2dB
4. 反复微调，直到人声稳定在两只喇叭的中间

经验值：内置喇叭通常比外接音箱灵敏，`笔记本喇叭增益 ≈ −3 ~ −6dB` 是常见起点。

### 3.2 分频点

| 听感 | 处理 |
|---|---|
| 人声发闷、像捂着嘴 | 分频点往上提（250 → 320Hz） |
| 低频空洞、鼓没量感 | 分频点往下压（150 → 100Hz） |
| 中频发硬、乐器轮廓模糊 | 分频点往中间收（180–220Hz） |

调整时只动分频点，其他先别碰。四个滤波器（两路各两个二阶）会同步改。

### 3.3 延迟补偿

内置喇叭和显示器/USB 音箱的处理链路长度不同，差几毫秒就会出现"鼓点发散"。

1. 放节奏清晰的曲子（鼓、拍手、电子乐）
2. 以 **2ms 为步进**调「高频链路延迟补偿」，从 0 往上试
3. 找到鼓点最"实"、最有冲击力的位置；再往上调会开始糊

典型值 6~12ms。如果你的外接音箱走蓝牙，延迟可能是几十毫秒量级，这个滑块（上限 40ms）不够用 —— 蓝牙不适合做这件事。

### 3.4 总音量

输出走 BlackHole 后，键盘音量键会失效（它控制的是物理设备），系统音量条也不再起作用，总音量只能在 App 里调：**调音台 → 总音量**，或**菜单栏面板**的滑块。两处是同一个值。

滑块位置与实际增益（感知曲线，不是线性 dB）：

| 滑块 | 25% | 50% | 72% | 85% | 100% |
|---|---|---|---|---|---|
| 增益 | −26.5 dB | −12 dB | −5 dB | −0.1 dB | +12 dB |

- 低位段更细，夜里小音量也能听清；以前线性映射时拖到一半就是 −30dB，听感上等于没声音
- 85% 以上进入 0dB 以上的增益区，用来榨干喇叭余量；超过 +3dB 数字会变橙色，那是削顶提醒
- 音量和静音走的是 CamillaDSP 的 websocket 通道，**即时生效、不重启引擎**，所以拖动是连续的，不会一顿一顿
- 左侧的喇叭按钮是独立静音开关，与滑块位置无关

**还是不够大？** ① 滑块推到 85% 以上；② 检查两只喇叭自己的系统音量/物理旋钮是否拉满；③ 外接音箱走 USB 声卡时看声卡硬件增益。再往上只有削顶 —— 实测 0dB → +12dB 只多出约 8dB 就到内置喇叭的物理极限了。

**缓冲区**：出现爆音、断续、卡顿就往上调（1024 → 2048）。代价是端到端延迟增加，看电影会有口型不同步的风险。

---

## 4. 菜单栏与日常操作

点窗口红叉 → 窗口收起，Dock 图标消失，顶部状态栏留下音箱图标。这**不会中断播放**。

| 图标 | 含义 |
|---|---|
| 实心 🔊 | CamillaDSP 正在播放 |
| 空心 🔈 | 已停止 |

点图标弹出面板：

- 运行状态 + 两路设备摘要（`MacBook Pro 扬声器 + Headphone`）
- 音量滑块（0–100%，实时生效）+ 静音按钮
- 启动 / 停止
- 打开主窗口
- 退出（电源按钮）

**退出要从严**：请用面板里的电源按钮或 `killall MultiSpeaker`，这样 App 会同步回收 CamillaDSP 子进程。强行 `kill -9` 可能留下 camilladsp 孤儿进程占住聚合设备，下次启动就会没声音。

### 界面语言

「运行与日志」页最下方有语言选择：**跟随系统 / 中文 / English**。切换即时生效，不需要重启 App。

- 默认「跟随系统」：系统首选语言是中文就用中文，否则用英文
- App 在 Finder / 程序坞里的名字由系统语言决定（`InfoPlist.strings`），与上面的开关无关
- 菜单栏面板的文案会跟着切换，但面板已经打开时需要点一下别处再打开才刷新

---

## 5. 故障排查树

### 5.1 "音乐在播放，但没声音"

按顺序排查，**越靠前越常见**：

```
① 麦克风权限没给？
   系统设置 → 隐私与安全性 → 麦克风 → MultiSpeaker 是否开启
   → 没开：打开后重启 App。这是最常见的元凶。

② CamillaDSP 真的在跑？
   「运行与日志」页：状态点绿色 + 日志没有红色 ✗
   → 红色报错一般是设备被占用 / YAML 非法，看报错原文

③ 系统默认输出还是 BlackHole 吗？
   系统设置 → 声音 → 输出 = BlackHole 2ch
   → 被其他 App（如某些会议软件）抢走就会变成静音直达

④ 总音量/静音？
   看「调音台」或菜单栏面板，是不是 −60dB 或勾了静音

⑤ 聚合设备还在吗？
   「一键设置」第 2 步是否显示"在线"
   → 不在了点「创建 / 重建聚合设备」

⑥ 外接音箱本身
   物理音量、电源、输入源选择（很多音箱有 USB/蓝牙/模拟 多路输入）
```

### 5.2 只有一边有声音

聚合设备的子设备顺序被改坏了（比如在「音频 MIDI 设置」里手动拖过）。到「一键设置」第 2 步点 **创建 / 重建聚合设备**。

### 5.3 爆音、断续、每隔几秒卡一下

- 缓冲区调到 2048
- 确认两只设备都接在同一个稳定的接口上（USB hub 供电不足会导致 USB 声卡周期性重连）
- 关闭其他同时占用音频设备的 App（录屏、会议、直播软件）

### 5.4 开机 / 重启后没声音

- 系统默认输出可能被系统切回内置喇叭 → 重新点「设为默认输出」
- 「运行与日志」页打开「开机自动启动（并自动开始播放）」
- 「登录时启动本 App」需要 LaunchAgent，若显示不可用看该行的提示信息

### 5.5 BlackHole 装了但设备列表里没有

```bash
sudo launchctl kickstart -k system/com.apple.audio.coreaudiod
```

不行就重启。极少数情况是 pkg 装失败，`brew reinstall --cask blackhole-2ch`。

### 5.6 两个实例抢设备

同一时刻只能有一个 CamillaDSP 占用聚合设备。症状是第二个实例启动失败、或第一路变哑。

```bash
killall MultiSpeaker        # 全关
pgrep -fl camilladsp        # 应该为空；有残留就 kill 掉
```

---

## 6. 客观验收：用麦克风量化

耳朵会被"以为在响"骗，麦克风不会。

```bash
# 第一步：确认设备索引（顺序会随安装的驱动变化，别硬编码）
ffmpeg -f avfoundation -list_devices true -i ""
```

输出里找到：

```
[x] MacBook Pro麦克风        ← 用这个索引（通常 3）
[x] BlackHole 2ch            ← 用这个验证"音源是否进了虚拟声卡"
```

录音并测电平：

```bash
ffmpeg -f avfoundation -i ":3" -t 4 -y /tmp/mic.wav
ffmpeg -i /tmp/mic.wav -af volumedetect -f null -
```

判读标准：

| mean_volume | 含义 |
|---|---|
| −91 dB | 数字死寂，链路完全没通 |
| −45 ~ −50 dB | 环境底噪（房间安静时） |
| −9 ~ −31 dB | 正常在出声 |

更精确的做法是窄带对比，排除环境噪声干扰：

```bash
# 放 440Hz 测试音的同时录 4 秒，然后只测 440Hz 附近的能量
ffmpeg -i /tmp/mic.wav -af "bandpass=f=440:width_type=h:w=60,volumedetect" -f null -
```

有音与静音两组对比，差距 **15dB 以上** 就说明链路确实在出声。

验证音源是否进入 BlackHole（把索引换成 BlackHole 的那个）：

```bash
ffmpeg -f avfoundation -i ":1" -t 4 -y /tmp/bh.wav
ffmpeg -i /tmp/bh.wav -af volumedetect -f null -
```

这一段有信号 = 系统输出确实进了虚拟声卡；这一段静音 = 默认输出被抢走了。

---

## 7. 文件位置与命令行工具

| 内容 | 路径 |
|---|---|
| 用户参数 | `~/Library/Preferences/com.user.MultiSpeaker.plist` |
| 生成的 CamillaDSP 配置 | `~/Library/Application Support/MultiSpeaker/multispeaker.yml` |
| 登录自启（可选） | `~/Library/LaunchAgents/com.user.MultiSpeaker.plist` |

命令行工具（App 内二进制自带）：

```bash
APP=/Applications/MultiSpeaker.app/Contents/MacOS/MultiSpeaker

# 列出所有输出设备、BlackHole 状态、聚合设备状态、当前默认输出
$APP --cli-enumerate

# 手动建聚合设备（高频 UID 在前）
$APP --cli-create-aggregate BuiltInSpeakerDevice <低频设备UID>

# 把默认输出切成 BlackHole
$APP --cli-default-blackhole
```

这些命令不弹 GUI，适合写脚本或远程排障。

---

## 8. 升级与卸载

### 升级

覆盖 `/Applications/MultiSpeaker.app` 即可，用户参数和 YAML 不会丢。升级后建议重启 App 让它重新拉起引擎。

### 完整卸载

```bash
killall MultiSpeaker
rm -rf /Applications/MultiSpeaker.app
rm -rf ~/Library/Application\ Support/MultiSpeaker
rm -f  ~/Library/LaunchAgents/com.user.MultiSpeaker.plist
defaults delete com.user.MultiSpeaker 2>/dev/null

# 聚合设备：打开「音频 MIDI 设置」，选中 MultiSpeaker 点左下角 −
# 或者直接删掉 BlackHole（如果不再需要虚拟声卡）
brew uninstall --cask blackhole-2ch
```

卸载前记得把系统默认输出切回内置喇叭，否则会变成"系统没声音"。
