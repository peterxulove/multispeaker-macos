#!/bin/bash
# 一键构建并打包 MultiSpeaker.app（含内置 camilladsp v4.1.3）
set -euo pipefail
cd "$(dirname "$0")"

echo "==> [1/4] swift build -c release"
swift build -c release --disable-sandbox

APP="MultiSpeaker.app"
echo "==> [2/4] assemble $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/MultiSpeaker" "$APP/Contents/MacOS/MultiSpeaker"
cp "Resources/camilladsp" "$APP/Contents/Resources/camilladsp"
chmod +x "$APP/Contents/Resources/camilladsp"
cp "Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
rm -f "Resources/camilladsp.tar.gz"

# 双语 App 名（菜单栏 / Finder / 关于本机里跟随系统语言）
mkdir -p "$APP/Contents/Resources/zh-Hans.lproj" "$APP/Contents/Resources/en.lproj"
cat > "$APP/Contents/Resources/zh-Hans.lproj/InfoPlist.strings" <<'S'
CFBundleDisplayName = "MultiSpeaker 多喇叭合奏";
CFBundleName = "MultiSpeaker";
S
cat > "$APP/Contents/Resources/en.lproj/InfoPlist.strings" <<'S'
CFBundleDisplayName = "MultiSpeaker";
CFBundleName = "MultiSpeaker";
S

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>zh_CN</string>
	<key>CFBundleDisplayName</key>
	<string>MultiSpeaker 多喇叭合奏</string>
	<key>CFBundleExecutable</key>
	<string>MultiSpeaker</string>
	<key>CFBundleIdentifier</key>
	<string>com.user.MultiSpeaker</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleIconName</key>
	<string>AppIcon</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleLocalizations</key>
	<array>
		<string>zh-Hans</string>
		<string>en</string>
	</array>
	<key>CFBundleName</key>
	<string>MultiSpeaker</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.1.0</string>
	<key>CFBundleVersion</key>
	<string>2</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSMicrophoneUsageDescription</key>
	<string>MultiSpeaker 需要采集 BlackHole 虚拟声卡的音频（BlackHole 在系统里表现为音频输入设备），才能把高低音分频后分别输出到多个喇叭。未授权时 CamillaDSP 只能收到静音，表现为「音乐在播放但没有声音」。</string>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
</dict>
</plist>
PLIST

echo "==> [3/4] ad-hoc codesign"
codesign --force --sign - "$APP" || echo "(codesign 跳过，不影响本地运行)"

echo "==> [4/4] zip"
mkdir -p dist
rm -f dist/MultiSpeaker.zip
ditto -c -k --sequesterRsrc --keepParent "$APP" dist/MultiSpeaker.zip
echo
echo "完成："
ls -la "$APP/Contents/MacOS/MultiSpeaker" "$APP/Contents/Resources/camilladsp" dist/MultiSpeaker.zip
