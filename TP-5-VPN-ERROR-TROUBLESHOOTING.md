# VPN Configuration Error Troubleshooting

## Error: NEVPNErrorDomain error 1 (NEVPNErrorConfigurationInvalid)

This error occurs when toggling the VPN switch and indicates that the VPN configuration is invalid.

## Common Causes and Solutions

### 1. Bundle Identifier Mismatch
- **Issue**: The provider bundle identifier in VPNManager doesn't match the actual PacketTunnel bundle ID
- **Check**: 
  - VPNManager.swift: `tunnelProtocol.providerBundleIdentifier = "com.conceal.concealconnect.PacketTunnel"`
  - project.yml PacketTunnel: `PRODUCT_BUNDLE_IDENTIFIER: com.conceal.concealconnect.PacketTunnel`
  - Xcode: Select PacketTunnel target → Build Settings → Product Bundle Identifier

### 2. Missing or Incorrect Entitlements
- **Required entitlements for main app**:
  ```xml
  <key>com.apple.developer.networking.networkextension</key>
  <array>
      <string>packet-tunnel-provider</string>
  </array>
  <key>com.apple.developer.networking.vpn.api</key>
  <array>
      <string>allow-vpn</string>
  </array>
  ```
- **Required entitlements for PacketTunnel extension**: Same as above

### 3. App Groups Configuration
- **Issue**: App groups must match between app and extension
- **Check**: Both entitlements files should have:
  ```xml
  <key>com.apple.security.application-groups</key>
  <array>
      <string>group.com.Conceal.shared</string>
  </array>
  ```

### 4. NetworkExtension Framework Not Linked
- **Check**: Both targets must link NetworkExtension.framework
- **In project.yml**:
  ```yaml
  dependencies:
    - sdk: NetworkExtension.framework
  ```

### 5. Provisioning Profile Issues
- **Check in Xcode**:
  - Main app target → Signing & Capabilities → NetworkExtension capability enabled
  - PacketTunnel target → Signing & Capabilities → NetworkExtension capability enabled
  - Both targets using same development team

### 6. First Launch Configuration
- **Issue**: VPN configuration might not be saved properly on first launch
- **Solution**: Check VPNManager.ensureManager() implementation
- **Console logs to check**:
  ```
  "Failed to save tunnel configuration: <error>"
  "No tunnel manager available - ensuring manager exists"
  ```

## Debugging Steps

1. **Check Console Logs**:
   ```bash
   # In Xcode console, filter by:
   com.conceal
   ```

2. **Verify Bundle IDs**:
   ```bash
   # Check main app bundle ID
   xcodebuild -showBuildSettings -target ConcealConnect | grep PRODUCT_BUNDLE_IDENTIFIER
   
   # Check extension bundle ID  
   xcodebuild -showBuildSettings -target PacketTunnel | grep PRODUCT_BUNDLE_IDENTIFIER
   ```

3. **Check Entitlements**:
   ```bash
   # After building, check actual entitlements
   codesign -d --entitlements - /path/to/ConcealConnect.app
   codesign -d --entitlements - /path/to/ConcealConnect.app/PlugIns/PacketTunnel.appex
   ```

4. **Reset VPN Configuration**:
   - Go to Settings → General → VPN & Device Management → VPN
   - Delete any existing ConcealConnect configurations
   - Try toggling the switch again

## Implementation Checklist

- [ ] Bundle IDs match in VPNManager and project configuration
- [ ] NetworkExtension framework linked to both targets
- [ ] Entitlements include NetworkExtension and VPN capabilities
- [ ] App groups match between app and extension
- [ ] Development team set for both targets
- [ ] Provisioning profiles support NetworkExtension capability
- [ ] PacketTunnel.appex is properly embedded in main app

## Additional Notes

- NetworkExtension requires a physical device (not simulator)
- The app must be signed with a development team that has NetworkExtension capability
- On first launch, iOS will prompt for VPN configuration permission