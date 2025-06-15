#!/usr/bin/env bash
set -euo pipefail

# ----- guard rails ----------------------------------------------------------
[ -d App ] && { echo "❗️Project appears to exist; aborting."; exit 1; }

# ----- minimal source tree --------------------------------------------------
mkdir -p App Extensions/PacketTunnel

cat > App/AppDelegate.swift <<'SWIFT'
import SwiftUI
@main
struct ConcealConnectApp: App {
    var body: some Scene { WindowGroup { Text("👋 Conceal Connect") } }
}
SWIFT

cat > Extensions/PacketTunnel/PacketTunnelProvider.swift <<'SWIFT'
import NetworkExtension
final class PacketTunnelProvider: NEPacketTunnelProvider {
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        completionHandler(nil)  // stub
    }
}
SWIFT

# ----- Info.plists (text, not binary) ---------------------------------------
mkdir -p App/Resources Extensions/PacketTunnel/Resources

cat > App/Resources/Info.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>com.Conceal.ConcealConnect</string>
  <key>CFBundleName</key><string>ConcealConnect</string>
  <key>CFBundleExecutable</key><string>$(EXECUTABLE_NAME)</string>
</dict>
</plist>
PLIST

cat > Extensions/PacketTunnel/Resources/Info.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>com.Conceal.PacketTunnel</string>
  <key>NSExtension</key>
  <dict>
    <key>NSExtensionPointIdentifier</key><string>com.apple.networkextension.packet-tunnel</string>
  </dict>
</dict>
</plist>
PLIST

cat > Extensions/PacketTunnel/PacketTunnel.entitlements <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.networkextension.packet-tunnel-provider</key><true/>
</dict>
</plist>
XML

# ----- project.yml ----------------------------------------------------------
cat > project.yml <<'YAML'
name: ConcealConnect
options:
  bundleIdPrefix: com.Conceal
  deploymentTarget:
    iOS: "16.0"

targets:
  ConcealConnect:
    type: application
    platform: iOS
    sources: [App]
    resources: [App/Resources]
    info:
      path: App/Resources/Info.plist

  PacketTunnel:
    type: system-extension
    platform: iOS
    sources: [Extensions/PacketTunnel]
    resources: [Extensions/PacketTunnel/Resources]
    info:
      path: Extensions/PacketTunnel/Resources/Info.plist
    entitlements:
      path: Extensions/PacketTunnel/PacketTunnel.entitlements
YAML

# ----- generate & build -----------------------------------------------------
xcodegen generate
xcodebuild -scheme ConcealConnect \
           -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
           -quiet build
echo "✅ Xcode project generated and built."
