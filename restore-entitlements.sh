#!/bin/bash

# Restore entitlements after xcodegen clears them

cat > App/App.entitlements << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.networking.networkextension</key>
	<array>
		<string>packet-tunnel-provider</string>
	</array>
	<key>com.apple.developer.networking.vpn.api</key>
	<array>
		<string>allow-vpn</string>
	</array>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.com.conceal.shared</string>
	</array>
</dict>
</plist>
EOF

cat > Extensions/PacketTunnel/PacketTunnel.entitlements << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.networking.networkextension</key>
	<array>
		<string>packet-tunnel-provider</string>
	</array>
	<key>com.apple.developer.networking.vpn.api</key>
	<array>
		<string>allow-vpn</string>
	</array>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.com.conceal.shared</string>
	</array>
</dict>
</plist>
EOF

echo "Entitlements restored successfully!"