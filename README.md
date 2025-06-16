# ConcealConnect Mobile

A privacy-focused iOS VPN client that uses the MASQUE (Multiplexed Application Substrate over QUIC Encryption) protocol to provide secure network tunneling.

## Overview

ConcealConnect Mobile is an iOS application that implements a packet tunnel provider using the MASQUE protocol. It automatically establishes secure connections when accessing configured domains, providing privacy and security for network traffic.

## Architecture

The project consists of three main components:

1. **Main App** (`ConcealConnect`) - The iOS application that manages VPN configuration and provides the user interface
2. **Packet Tunnel Extension** (`PacketTunnel`) - A Network Extension that handles the actual VPN tunnel and packet processing
3. **Tunnel Core Framework** (`TunnelCore`) - Shared framework containing the MASQUE client implementation

## Current Features

- MASQUE protocol implementation using libquiche
- Automatic VPN connection for configured domains (*.masque.test)
- Network Extension integration with iOS
- Real-time VPN status monitoring
- On-demand connection rules
- IPv4/UDP packet forwarding through MASQUE tunnel
- Bidirectional data flow with continuous polling

## Project Status

### Completed Milestones

#### TP-1: Create PacketTunnelProvider.swift skeleton ✅
- Created PacketTunnelProvider class extending NEPacketTunnelProvider
- Integrated MasqueClient for MASQUE protocol handling
- Implemented basic tunnel lifecycle (startTunnel/stopTunnel)
- Added comprehensive logging for debugging
- Hard-coded server configuration for initial testing

#### TP-2: Domain list hand-off ✅
- Implemented VPNManager class for tunnel configuration
- Configured NEOnDemandRuleEvaluateConnection for automatic connections
- Set up tunnel to trigger for masque.test domains
- Added NetworkExtension entitlements
- Created basic UI to display VPN status

#### TP-3: Forward packets ✅
- Implemented packetFlow.readPackets() to capture outbound packets
- Added IPv4/UDP packet filtering (drops non-IPv4/UDP traffic)
- Forward valid packets through MasqueClient.send() with stream tracking
- Implemented continuous polling via MasqueClient.poll()
- Write inbound packets back via packetFlow.writePackets()
- Configured tunnel network settings (10.0.0.2/24, Google DNS)
- Added dedicated dispatch queues for packet operations

### Upcoming Milestones

#### TP-4: Simple lifecycle UI
- Add "Connect" toggle in the app
- Implement manual connection controls with NETunnelProviderManager
- Enhance status display with connection details
- Allow manual start/stop of VPN tunnel

#### TP-5: Smoke test on device
- Test on iOS 18 Simulator or real device
- Verify http://masque.test loads through tunnel
- Validate connection stability
- Ensure no crashes during repeated connect/disconnect cycles

## Technical Details

### MASQUE Client Interface
```swift
// Connect to MASQUE server
connect(host: String, port: UInt16)

// Send data through tunnel
send(_ data: Data) -> UInt64  // Returns stream ID

// Receive data from tunnel
poll(maxBytes: Int) -> (UInt64, Data)?  // Returns stream ID and data
```

### Packet Forwarding Architecture
- **Outbound**: iOS → packetFlow.readPackets() → Filter IPv4/UDP → MasqueClient.send() → MASQUE Tunnel
- **Inbound**: MASQUE Tunnel → MasqueClient.poll() → packetFlow.writePackets() → iOS
- **Filtering**: Only IPv4 (AF_INET) packets with UDP protocol (17) are forwarded
- **Performance**: Separate dispatch queues for reading and polling operations

### Dependencies
- iOS 18.5+
- libquiche (QUIC implementation)
- NetworkExtension framework

## Building the Project

1. Clone the repository
2. Run `xcodegen generate` to create the Xcode project
3. Open `ConcealConnect.xcodeproj` in Xcode
4. Select your development team for code signing
5. Build and run on a device or simulator

### Requirements
- Xcode 15+
- iOS 18.5+ deployment target
- Valid Apple Developer account with Network Extension capability

## Configuration

The tunnel is configured to automatically connect when accessing:
- `masque.test`
- `*.masque.test`

The MASQUE server is currently hard-coded to `masque.test:443` for testing.

## Development Status

This project is under active development as part of the Tunnel Provider MVP sprint. Each milestone builds upon the previous work to create a fully functional MASQUE-based VPN client.

### Definition of Done
- MasqueClient logs "handshake completed" inside the provider
- curl http://masque.test in Safari returns the test HTML page
- No crashes when toggling connect/disconnect five times in a row

## Contributing

This is a private project. For questions or issues, please contact the development team.

## License

Proprietary - All rights reserved