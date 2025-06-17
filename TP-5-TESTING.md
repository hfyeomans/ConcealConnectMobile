# TP-5 Smoke Test Instructions

## Overview
This document provides instructions for completing the TP-5 milestone: Smoke test on device.

## Prerequisites
1. Physical iOS device running iOS 18.5+ (NetworkExtension does not work in simulator)
2. MASQUE test server running at `10.0.150.43:6121`
3. Xcode with valid development team for code signing
4. Device connected to same network as MASQUE server

## Success Criteria
The following must be achieved for TP-5 completion:

1. ✅ **MasqueClient logs "handshake completed"** inside the provider
2. ✅ **curl http://masque.test in Safari** returns the test HTML page
3. ✅ **No crashes** when toggling connect/disconnect five times in a row

## Tunnel Configuration Options

Before testing, you should understand the two tunnel configuration modes available in ConcealConnect Mobile. The current default is to route all traffic through the VPN, but you can also configure split tunneling for specific domains.

### All Traffic Mode (Current Default)

This mode routes all device traffic through the MASQUE tunnel, providing complete privacy protection.

**Current configuration in PacketTunnelProvider.swift (lines 54-61):**
```swift
// Configure IPv4 settings for all traffic
let ipv4Settings = NEIPv4Settings(addresses: ["10.0.0.2"], subnetMasks: ["255.255.255.0"])
ipv4Settings.includedRoutes = [NEIPv4Route.default()]  // Route all traffic
tunnelSettings.ipv4Settings = ipv4Settings

// Configure DNS without match domains
let dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "8.8.4.4"])
// No matchDomains set - DNS applies to all traffic
tunnelSettings.dnsSettings = dnsSettings
```

### Split Tunnel Mode (masque.test Only)

This mode only tunnels traffic for masque.test domains, allowing other traffic to bypass the VPN for better performance.

**To enable split tunneling, modify PacketTunnelProvider.swift (lines 54-61):**
```swift
// Configure IPv4 settings for split tunneling
let ipv4Settings = NEIPv4Settings(addresses: ["10.0.0.2"], subnetMasks: ["255.255.255.0"])
ipv4Settings.includedRoutes = []  // Empty array - no default route
tunnelSettings.ipv4Settings = ipv4Settings

// Configure DNS with match domains
let dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "8.8.4.4"])
dnsSettings.matchDomains = ["masque.test"]  // Only tunnel traffic for masque.test
tunnelSettings.dnsSettings = dnsSettings
```

### Testing Considerations

- **All Traffic Mode**: When testing with all traffic mode, you'll notice the VPN icon is always active and all network requests go through the tunnel. This may affect general browsing performance.

- **Split Tunnel Mode**: When testing with split tunnel mode, only requests to masque.test will go through the tunnel. Other traffic will use your regular internet connection. The VPN icon may not always be visible.

### Verifying Configuration

To verify which mode is active:
1. Check console logs for included routes configuration
2. Test accessing both masque.test and other websites
3. Monitor packet flow in the console to see which traffic is being tunneled

## Testing Steps

### 1. Build and Install
```bash
# Generate Xcode project
xcodegen generate

# Open in Xcode
open ConcealConnect.xcodeproj
```

1. Select your development team in project settings
2. Connect your iOS device
3. Select your device as the build target (not simulator)
4. Build and run (Cmd+R)

### 2. Monitor Console Logs
1. In Xcode, open the Console (View → Debug Area → Show Console)
2. Filter logs by "com.conceal" to see relevant messages
3. Look for these key log messages:
   - `"PacketTunnelProvider initialized"`
   - `"Starting packet tunnel provider"`
   - `"MasqueClient connect() called successfully"`
   - `"MasqueClient: handshake completed"` ✅ (Success Criteria #1)

### 3. Test VPN Connection
1. In the app, toggle the "Private Access" switch ON
2. Accept the VPN configuration prompt if shown
3. Check iOS Settings → VPN to confirm connection status
4. Look for the VPN icon in the status bar

### 4. Test masque.test Domain
1. Open Safari on the device
2. Navigate to `http://masque.test`
3. Verify the test HTML page loads ✅ (Success Criteria #2)

### 5. Stability Test
1. Toggle "Private Access" OFF
2. Wait 2-3 seconds
3. Toggle "Private Access" ON
4. Repeat 5 times
5. Verify no crashes occur ✅ (Success Criteria #3)

## Troubleshooting

### VPN Stays Disconnected
- Check console logs for connection errors
- Verify MASQUE server is running at `10.0.150.43:6121`
- Ensure device can reach the server IP
- Check for bundle identifier mismatches in logs

### No "handshake completed" Log
- The handshake may take a few seconds to complete
- Check that the MASQUE server supports the configured ALPN protocols
- Verify network connectivity between device and server

### Safari Can't Load masque.test
- Ensure VPN is connected (check status bar icon)
- Verify DNS settings in PacketTunnelProvider (should be 8.8.8.8, 8.8.4.4)
- Check that tunnel routes are correctly configured

### App Crashes on Toggle
- Check console for crash logs
- Look for memory leaks or race conditions
- Ensure proper cleanup in stopTunnel method

## Log Examples

### Successful Connection
```
PacketTunnelProvider initialized
Starting packet tunnel provider
Options received: nil
Attempting to connect to MASQUE server at 10.0.150.43:6121
MasqueClient connect() called successfully to 10.0.150.43:6121
MasqueClient: handshake pending, will complete asynchronously
Tunnel network settings applied successfully
Starting packet handling
MasqueClient: handshake completed
```

### Successful Disconnect
```
Stopping packet tunnel provider with reason: 1
Packet tunnel provider stopped cleanly
VPN status changed to: NEVPNStatus(rawValue: 1)
```

## Definition of Done Checklist
- [ ] MasqueClient logs "handshake completed" inside the provider
- [ ] curl http://masque.test in Safari returns the test HTML page  
- [ ] No crashes when toggling connect/disconnect five times in a row
- [ ] All changes committed to TP-5-smoke-test branch
- [ ] Pull request created with test results documented