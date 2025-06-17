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