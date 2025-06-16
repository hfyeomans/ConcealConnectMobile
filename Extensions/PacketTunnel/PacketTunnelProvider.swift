import NetworkExtension
import TunnelCore
import os.log

// Protocol family constants
private let AF_INET: Int32 = 2  // IPv4

final class PacketTunnelProvider: NEPacketTunnelProvider {
    
    private var masqueClient: MasqueClient?
    private let logger = Logger(subsystem: "com.conceal.PacketTunnel", category: "Provider")
    private var isRunning = false
    private let packetQueue = DispatchQueue(label: "com.conceal.PacketTunnel.packets", qos: .userInitiated)
    private let pollQueue = DispatchQueue(label: "com.conceal.PacketTunnel.poll", qos: .userInitiated)
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        logger.log("Starting packet tunnel provider")
        
        // Instantiate MasqueClient
        masqueClient = MasqueClient()
        
        // TODO: Extract server host/port from options or configuration
        let serverHost = "10.0.150.43" // Local test server on network
        let serverPort: UInt16 = 6121
        
        do {
            // Call connect() on MasqueClient
            try masqueClient?.connect(host: serverHost, port: serverPort)
            logger.log("MasqueClient connected successfully to \(serverHost):\(serverPort)")
            
            // Configure tunnel settings
            let tunnelSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: serverHost)
            
            // Configure IPv4 settings
            let ipv4Settings = NEIPv4Settings(addresses: ["10.0.0.2"], subnetMasks: ["255.255.255.0"])
            ipv4Settings.includedRoutes = [NEIPv4Route.default()]
            tunnelSettings.ipv4Settings = ipv4Settings
            
            // Configure DNS
            tunnelSettings.dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "8.8.4.4"])
            
            // Apply tunnel settings
            setTunnelNetworkSettings(tunnelSettings) { [weak self] error in
                if let error = error {
                    self?.logger.error("Failed to set tunnel network settings: \(error.localizedDescription)")
                    completionHandler(error)
                } else {
                    self?.logger.log("Tunnel network settings applied successfully")
                    self?.isRunning = true
                    self?.startPacketHandling()
                    completionHandler(nil)
                }
            }
        } catch {
            logger.error("Failed to connect MasqueClient: \(error.localizedDescription)")
            completionHandler(error)
        }
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        logger.log("Stopping packet tunnel provider with reason: \(reason.rawValue)")
        
        // Stop packet handling
        isRunning = false
        
        // Clean up MasqueClient
        masqueClient = nil
        
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        logger.log("Received app message of size: \(messageData.count)")
        completionHandler?(nil)
    }
    
    // MARK: - Packet Handling
    
    private func startPacketHandling() {
        logger.log("Starting packet handling")
        
        // Start reading packets from the device
        readPacketsFromDevice()
        
        // Start polling for inbound data
        pollInboundData()
    }
    
    private func readPacketsFromDevice() {
        packetQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.packetFlow.readPackets { packets, protocols in
                guard self.isRunning else { return }
                
                for (index, packet) in packets.enumerated() {
                    let protocolFamily = protocols[index]
                    self.handleOutboundPacket(packet, protocolFamily: protocolFamily)
                }
                
                // Continue reading packets
                if self.isRunning {
                    self.readPacketsFromDevice()
                }
            }
        }
    }
    
    private func handleOutboundPacket(_ packet: Data, protocolFamily: NSNumber) {
        // Check if it's IPv4 (AF_INET = 2)
        guard protocolFamily.intValue == AF_INET else {
            logger.debug("Dropping non-IPv4 packet (protocol family: \(protocolFamily))")
            return
        }
        
        // Parse IPv4 header to check if it's UDP
        guard packet.count >= 20 else {
            logger.debug("Dropping packet: too small for IPv4 header")
            return
        }
        
        // Get IP protocol field (byte 9 in IPv4 header)
        let ipProtocol = packet[9]
        
        // Check if it's UDP (protocol number 17)
        guard ipProtocol == 17 else {
            logger.debug("Dropping non-UDP packet (IP protocol: \(ipProtocol))")
            return
        }
        
        // Send the packet through MASQUE
        do {
            guard let client = masqueClient else {
                logger.error("MasqueClient is nil, dropping packet")
                return
            }
            
            let streamId = client.send(packet)
            logger.debug("Sent packet of size \(packet.count) bytes via MASQUE (stream ID: \(streamId))")
        } catch {
            logger.error("Failed to send packet via MASQUE: \(error.localizedDescription)")
        }
    }
    
    private func pollInboundData() {
        pollQueue.async { [weak self] in
            guard let self = self, self.isRunning else { return }
            
            // Poll for data with a reasonable timeout
            if let client = self.masqueClient,
               let (streamId, data) = client.poll(maxBytes: 65536) {
                self.logger.debug("Received \(data.count) bytes from MASQUE (stream ID: \(streamId))")
                
                // Write the packet back to the device
                self.packetFlow.writePackets([data], withProtocols: [NSNumber(value: AF_INET)])
            }
            
            // Continue polling
            if self.isRunning {
                // Add a small delay to avoid busy-waiting
                self.pollQueue.asyncAfter(deadline: .now() + 0.001) {
                    self.pollInboundData()
                }
            }
        }
    }
}
