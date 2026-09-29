#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Xiangqi"
BUILD_DIR=".build/release"
APP="build/${APP_NAME}.app"
ENGINE_DIR="${ENGINE_DIR:-$HOME/pikafish}"
DMG="build/${APP_NAME}.dmg"

echo ">> 构建 release"
swift build -c release

echo ">> 组装 ${APP}"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp "$BUILD_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"

# 嵌入引擎 + NNUE 到 Resources，App 路径解析优先取这里。
echo ">> 拷贝引擎"
cp "$ENGINE_DIR/pikafish"        "$APP/Contents/Resources/pikafish"
cp "$ENGINE_DIR/pikafish.nnue"   "$APP/Contents/Resources/pikafish.nnue"
chmod +x "$APP/Contents/Resources/pikafish"

# App 图标
echo ">> 拷贝图标"
cp "Assets/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>Xiangqi</string>
    <key>CFBundleDisplayName</key>     <string>象棋</string>
    <key>CFBundleIdentifier</key>      <string>local.xiangqi.Xiangqi</string>
    <key>CFBundleVersion</key>         <string>1.0</string>
    <key>CFBundleShortVersionString</key> <string>1.0</string>
    <key>CFBundleExecutable</key>      <string>Xiangqi</string>
    <key>CFBundleIconFile</key>        <string>AppIcon</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key> <string>6.0</string>
    <key>LSMinimumSystemVersion</key>  <string>15.0</string>
    <key>NSPrincipalClass</key>        <string>NSApplication</string>
    <key>NSHighResolutionCapable</key> <true/>
    <key>LSUIElement</key>             <false/>
</dict>
</plist>
PLIST

echo ">> ad-hoc 签名"
codesign --force --sign - "$APP"

echo ">> 打 DMG：$DMG"
rm -f "$DMG"
STAGE="build/dmg-stage"
rm -rf "$STAGE"
mkdir -p "$STAGE/.background"
cp -R "$APP" "$STAGE/"
# 拖拽安装用：Applications 文件夹快捷方式
ln -s /Applications "$STAGE/Applications"
# hdiutil create 要求源目录非空且临时可写；UDZO 压缩、单分区只读
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -fs HFS+ -format UDZO "$DMG"
rm -rf "$STAGE"

echo ">> 完成"
echo "  App: $APP"
echo "  DMG: $DMG"
echo "  启动（本地）: open $APP"
echo "  分享：把 $DMG 发给对方，双击挂载后拖入 Applications，首次右键打开。"
