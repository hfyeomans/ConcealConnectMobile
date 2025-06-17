# DNS Setup for masque.test

## Problem
The VPN is connected but `http://masque.test` doesn't resolve because:
1. `masque.test` is not a real domain
2. The PacketTunnel needs to handle DNS resolution for test domains

## Solutions

### Option 1: Direct IP Testing (Quick Test)
Instead of `http://masque.test`, try:
```
http://10.0.150.43:6121
```
This bypasses DNS and tests if the MASQUE tunnel is working.

### Option 2: Configure DNS in PacketTunnelProvider
The tunnel is currently using Google DNS (8.8.8.8, 8.8.4.4) which doesn't know about `masque.test`.

**Current configuration in PacketTunnelProvider.swift:**
```swift
// Configure DNS
tunnelSettings.dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "8.8.4.4"])
```

**Options to fix:**

1. **Use local DNS server** that knows about masque.test:
```swift
tunnelSettings.dnsSettings = NEDNSSettings(servers: ["10.0.150.43"])
```

2. **Add search domains**:
```swift
let dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "8.8.4.4"])
dnsSettings.matchDomains = ["masque.test", "*.masque.test"]
dnsSettings.searchDomains = ["masque.test"]
tunnelSettings.dnsSettings = dnsSettings
```

3. **Use NEDNSSettings with specific domain mappings** (iOS 14+):
```swift
if #available(iOS 14.0, *) {
    let dnsSettings = NEDNSSettings(servers: ["8.8.8.8"])
    // Force masque.test domains through the tunnel
    dnsSettings.matchDomains = ["masque.test", "*.masque.test"]
    tunnelSettings.dnsSettings = dnsSettings
}
```

### Option 3: Hosts File on MASQUE Server
Configure your MASQUE server to handle DNS or respond to masque.test requests.

### Option 4: Use On-Demand Rules (Already Configured)
The on-demand rules in VPNManager.swift are set up for masque.test:
```swift
NEEvaluateConnectionRule(
    matchDomains: ["masque.test", "*.masque.test"],
    andAction: .connectIfNeeded
)
```

But this only triggers the VPN connection - it doesn't resolve the domain.

## Testing Steps

1. **Verify tunnel is working with direct IP**:
   - Open Safari
   - Navigate to `http://10.0.150.43:6121`
   - If this works, the tunnel is functioning

2. **Check DNS resolution**:
   - In Xcode console, add logging to see DNS requests
   - Check if packets for port 53 (DNS) are being forwarded

3. **Check MASQUE server logs**:
   - Verify the server is receiving connection attempts
   - Check if HTTP requests are reaching the server

## Quick Fix for Testing

Add this to PacketTunnelProvider.swift after line 44:
```swift
// For testing: Add masque.test resolution
let dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "8.8.4.4"])
dnsSettings.matchDomains = [""] // Match all domains
tunnelSettings.dnsSettings = dnsSettings

// Alternative: Use a local DNS server if you have one
// tunnelSettings.dnsSettings = NEDNSSettings(servers: ["10.0.150.43"])
```

## Debug Logging

Add this to PacketTunnelProvider to see what's happening:
```swift
private func handleOutboundPacket(_ packet: Data, protocolFamily: NSNumber) {
    // ... existing code ...
    
    // Debug: Log DNS queries (port 53)
    if ipProtocol == IPPROTO_UDP && packet.count >= 28 {
        let destPort = (UInt16(packet[22]) << 8) | UInt16(packet[23])
        if destPort == 53 {
            logger.debug("DNS query detected")
        }
    }
    
    // Debug: Log HTTP requests (port 80)
    if ipProtocol == IPPROTO_TCP && packet.count >= 24 {
        let destPort = (UInt16(packet[22]) << 8) | UInt16(packet[23])
        if destPort == 80 || destPort == 6121 {
            logger.debug("HTTP request to port \(destPort)")
        }
    }
}
```

## Expected Behavior

When everything is working:
1. Safari tries to resolve `masque.test`
2. DNS query goes through the tunnel
3. DNS returns 10.0.150.43 (or tunnel handles it)
4. HTTP request goes to 10.0.150.43:6121 through MASQUE
5. Response comes back through the tunnel
6. Page displays in Safari