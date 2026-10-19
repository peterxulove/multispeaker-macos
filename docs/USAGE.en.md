# MultiSpeaker user manual

> Practical guide: install → run → tune → troubleshoot → uninstall. For the architecture and code, see the [README](../README.en.md).

## Contents

- [1. Install and first launch](#1-install-and-first-launch)
- [2. Five steps to sound](#2-five-steps-to-sound)
- [3. Tuning in practice](#3-tuning-in-practice)
- [4. Volume](#4-volume)
- [5. Menu bar](#5-menu-bar)
- [6. Troubleshooting tree](#6-troubleshooting-tree)
- [7. Objective checks with a microphone](#7-objective-checks-with-a-microphone)
- [8. Files and CLI](#8-files-and-cli)
- [9. Upgrade and uninstall](#9-upgrade-and-uninstall)

---

## 1. Install and first launch

### 1.1 Put the app in place

Unzip `MultiSpeaker.zip`, drag `MultiSpeaker.app` into `/Applications`.

The app is ad-hoc signed (no Apple developer account, no notarisation), so:

- **First launch**: right-click the app → Open → Open again in the dialog
- If macOS claims the app is damaged: `xattr -dr com.apple.quarantine /Applications/MultiSpeaker.app`

### 1.2 Install BlackHole 2ch

BlackHole is a system audio driver, not an app; installing it needs an admin password.

- App → Setup → step 1 → **Install (Homebrew)** (requires Homebrew), or
- **Download installer** for the official pkg, or
- Manually: `brew install --cask blackhole-2ch`

The audio service sometimes misses new devices:

```bash
sudo launchctl kickstart -k system/com.apple.audio.coreaudiod
```

Still missing? Reboot.

### 1.3 Microphone permission (grant it)

The first one-click setup triggers the permission prompt. **Allow it.**

> **Why a microphone to play audio?** BlackHole is input-capable; CamillaDSP opens its input to capture the stream. Without permission CoreAudio does not fail — it returns zeros. The UI looks fine and CamillaDSP reports Running, but there is no sound.

If it was denied: System Settings → Privacy & Security → Microphone → enable MultiSpeaker, then fully quit and relaunch the app.

---

## 2. Five steps to sound

### Step 1 · BlackHole ready

The card turns green when `BlackHole 2ch` exists at 48 000 Hz.

### Step 2 · Pick the two speakers

| Field | Suggested |
|---|---|
| High band (laptop) | `MacBook Pro Speakers` (BuiltInSpeakerDevice) |
| Low band (external) | your speaker / display / USB interface |

Hit **Create / rebuild aggregate**. On success you see `MultiSpeaker online (objectID xxx)`.

```
MultiSpeaker (4ch)
├── ch1 / ch2  →  high device
├── ch3 / ch4  →  low device
├── clock master = high device
└── low device drift correction = 1
```

> Order matters. The high device comes first because it is also the clock master; reversed, channels misroute or you get silence.

### Step 3 · System default output → BlackHole

This routes every app's audio into the virtual device so CamillaDSP can grab it. Hit **Set as default output**; the card turns green. "Switch back to built-in" undoes it.

### Step 4 · CamillaDSP engine

v4.1.3 is bundled; the card shows the resolved path. Yellow means the binary is missing — re-extract the app.

### Step 5 · One-click start

Hit **One-click setup and start playing**: aggregate → default output → engine → playback.

To confirm it is really producing sound, play something and watch the log scroll in Runtime & Log.

---

## 3. Tuning in practice

Do it in this order: **levels → crossover → delay → phase**.

### 3.1 Level match

1. Set the external speaker's **physical** volume to a normal listening level (don't use app gain as the main volume)
2. Play a track with a centred vocal
3. If the vocal pulls toward the laptop, lower laptop gain by 1–2 dB
4. Repeat until the vocal sits between the two speakers

Rule of thumb: laptop gain around −3 to −6 dB is a common starting point.

### 3.2 Crossover

| What you hear | What to do |
|---|---|
| Vocals muffled, "covered" | Raise the crossover (250 → 320 Hz) |
| Hollow bass, no weight | Lower it (150 → 100 Hz) |
| Hard mids, blurry instruments | Move toward 180–220 Hz |

Change one thing at a time.

### 3.3 Delay

1. Play something rhythmic (drums, claps, electronic)
2. Step high-path delay 2 ms at a time from 0
3. Stop where the kick is tightest; further up it starts to smear

Typical 6–12 ms. Bluetooth speakers add tens of milliseconds — the 40 ms slider won't cover that; Bluetooth is the wrong tool here.

---

## 4. Volume

Output goes through BlackHole, so the keyboard volume keys and the system volume slider no longer control anything. Use the app:

- **Mixer → Master volume**, or the slider in the **menu bar** popover
- Both are the same value, stored in the app's preferences

How it behaves:

| Slider | 25% | 50% | 72% | 85% | 100% |
|---|---|---|---|---|---|
| Gain | −26.5 dB | −12 dB | −5 dB | −0.1 dB | +12 dB |

- The mapping is a **perceptual curve**: halfway is −12 dB, not −30 dB. Low positions stay usable at night
- Past 85% you are in gain territory; above +3 dB the readout turns orange — that's the clipping warning
- Volume and mute are pushed over CamillaDSP's websocket, so they take effect instantly and **never restart the engine**
- Mute is separate from the slider: the speaker button at the left toggles it

**Not loud enough?**

1. Push the slider past 85% (that's where >0 dB lives)
2. Check both speakers' own system volumes are at 100%
3. Check the physical knob / hardware gain on the external speaker
4. Beyond that you only get clipping — measured on this machine, 0 → +12 dB bought ~8 dB before the laptop speakers hit their limit

**Two path gains (Mixer → Laptop / External speaker gain)** are *band-limited*: they change how much of a band is present (timbre, energy split), not the overall level. Use them to balance the two speakers, not as volume.

---

## 5. Menu bar

Clicking the red close button hides the window, removes the Dock icon and keeps playback running.

| Icon | Meaning |
|---|---|
| Filled | Playing |
| Outline | Stopped |

The popover has: status, the two-device summary, volume + mute, start/stop, open window, quit.

**Quit properly** — use the power button in the panel or `killall MultiSpeaker`, so the child process is reclaimed. `kill -9` can orphan camilladsp and the next launch will have no sound.

---

## 6. Troubleshooting tree

### 6.1 "Music plays but there's no sound"

```
1. Microphone permission?
   System Settings → Privacy & Security → Microphone → MultiSpeaker
   → the most common cause by far

2. Is CamillaDSP actually running?
   Runtime & Log: green dot, no red ✗ lines
   → red usually means the device is busy or the YAML is invalid

3. Is the default output still BlackHole?
   System Settings → Sound → Output
   → a meeting/streaming app can steal it

4. Volume / mute?
   Check the slider and the speaker button

5. Is the aggregate still online?
   Setup → step 2 → if not, Create / rebuild

6. The speaker itself
   Power, physical volume, input source (USB / Bluetooth / analogue)
```

### 6.2 Only one side plays

The subdevice order got mangled (often by editing the aggregate in Audio MIDI Setup). Setup → **Create / rebuild aggregate**.

### 6.3 Crackling, dropouts every few seconds

- Buffer → 2048
- Make sure both devices sit on stable ports (an underpowered USB hub makes USB interfaces re-enumerate)
- Close other apps that hold audio devices (screen recording, meetings, streaming)

### 6.4 No sound after a reboot

- The default output may have fallen back to the built-in speakers → Set as default again
- Enable "Auto-start on launch"
- "Start at login" needs the LaunchAgent; check the message under the toggle if it is disabled

### 6.5 BlackHole installed but not listed

```bash
sudo launchctl kickstart -k system/com.apple.audio.coreaudiod
```

Then reboot if needed. If the pkg install failed: `brew reinstall --cask blackhole-2ch`.

### 6.6 Two instances fighting over the devices

```bash
killall MultiSpeaker
pgrep -fl camilladsp    # should be empty; kill any leftovers
```

---

## 7. Objective checks with a microphone

Your ears can lie about "it sounds like it's playing"; a microphone cannot.

```bash
# Always confirm indices first — they change with installed drivers
ffmpeg -f avfoundation -list_devices true -i ""
```

Find the built-in microphone (usually `3`) and BlackHole (usually `1`).

```bash
ffmpeg -f avfoundation -i ":3" -t 4 -y /tmp/mic.wav
ffmpeg -i /tmp/mic.wav -af volumedetect -f null -
```

| mean_volume | Meaning |
|---|---|
| −91 dB | Digital silence — the chain is broken |
| −45 ~ −50 dB | Room noise (quiet room) |
| −9 ~ −31 dB | Normal playback |

For precision, use a narrow band so room noise does not dominate:

```bash
ffmpeg -i /tmp/mic.wav -af "bandpass=f=440:width_type=h:w=60,volumedetect" -f null -
```

A 15 dB gap between "playing" and "silent" proves the chain works.

To check the source reached BlackHole (use the BlackHole index):

```bash
ffmpeg -f avfoundation -i ":1" -t 4 -y /tmp/bh.wav
ffmpeg -i /tmp/bh.wav -af volumedetect -f null -
```

---

## 8. Files and CLI

| What | Where |
|---|---|
| Preferences | `~/Library/Preferences/com.user.MultiSpeaker.plist` |
| Generated CamillaDSP config | `~/Library/Application Support/MultiSpeaker/multispeaker.yml` |
| Login item (optional) | `~/Library/LaunchAgents/com.user.MultiSpeaker.plist` |

```bash
APP=/Applications/MultiSpeaker.app/Contents/MacOS/MultiSpeaker
$APP --cli-enumerate
$APP --cli-create-aggregate BuiltInSpeakerDevice <lowDeviceUID>
$APP --cli-default-blackhole
```

These do not open a GUI — handy for scripts and remote debugging.

---

## 9. Upgrade and uninstall

### Upgrade

Replace `/Applications/MultiSpeaker.app`. Preferences and the YAML survive; restart the app so the engine is relaunched with the new binary.

### Full uninstall

```bash
killall MultiSpeaker
rm -rf /Applications/MultiSpeaker.app
rm -rf ~/Library/Application\ Support/MultiSpeaker
rm -f  ~/Library/LaunchAgents/com.user.MultiSpeaker.plist
defaults delete com.user.MultiSpeaker 2>/dev/null

# Aggregate: open Audio MIDI Setup, select MultiSpeaker, click −
# BlackHole, if you no longer need it:
brew uninstall --cask blackhole-2ch
```

Switch the system default output back to the built-in speakers **before** uninstalling, otherwise the Mac ends up silent.
