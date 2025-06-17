import NetworkExtension
import TunnelCore
import os.log

// Protocol family constants
private let AF_INET: Int32 = 2  // IPv4

// IP protocol constants
private let IPPROTO_TCP: UInt8 = 6
private let IPPROTO_UDP: UInt8 = 17

final class PacketTunnelProvider: NEPacketTunnelProvider {
    
    private var masqueClient: MasqueClient?
    private let logger = Logger(subsystem: "com.conceal.PacketTunnel", category: "Provider")
    private var isRunning = false
    private let packetQueue = DispatchQueue(label: "com.conceal.PacketTunnel.packets", qos: .userInitiated)
    private let pollQueue = DispatchQueue(label: "com.conceal.PacketTunnel.poll", qos: .userInitiated)
    private var hasLoggedHandshake = false
    
    override init() {
        super.init()
        logger.log("PacketTunnelProvider initialized")
    }
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        logger.log("Starting packet tunnel provider")
        logger.log("Options received: \(String(describing: options))")
        
        // Instantiate MasqueClient
        masqueClient = MasqueClient()
        
        // TODO: Extract server host/port from options or configuration
        let serverHost = "10.0.150.43" // Local test server on network
        let serverPort: UInt16 = 6121
        
        logger.log("Attempting to connect to MASQUE server at \(serverHost):\(serverPort)")
        
        do {
            // Call connect() on MasqueClient
            try masqueClient?.connect(host: serverHost, port: serverPort)
            logger.log("MasqueClient connect() called successfully to \(serverHost):\(serverPort)")
            
            // Check if handshake is complete (it may not be immediate)
            if let client = masqueClient, client.isHandshakeComplete() {
                logger.log("MasqueClient: handshake completed")
            } else {
                logger.log("MasqueClient: handshake pending, will complete asynchronously")
            }
            
            // Configure tunnel settings
            let tunnelSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: serverHost)
            
            // Configure IPv4 settings
            let ipv4Settings = NEIPv4Settings(addresses: ["10.0.0.2"], subnetMasks: ["255.255.255.0"])
            ipv4Settings.includedRoutes = [NEIPv4Route.default()]
            tunnelSettings.ipv4Settings = ipv4Settings
            
            // Configure DNS
            let dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "8.8.4.4"])
            // Match all domains to ensure they go through the tunnel
            dnsSettings.matchDomains = [""]
            tunnelSettings.dnsSettings = dnsSettings
            
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
        
        // Reset handshake flag
        hasLoggedHandshake = false
        
        // Give queues time to finish current operations
        let group = DispatchGroup()
        
        group.enter()
        packetQueue.async {
            group.leave()
        }
        
        group.enter()
        pollQueue.async {
            group.leave()
        }
        
        group.notify(queue: .main) { [weak self] in
            // Clean up MasqueClient after queues are done
            self?.masqueClient = nil
            self?.logger.log("Packet tunnel provider stopped cleanly")
            completionHandler()
        }
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
        
        // Parse IPv4 header to check protocol
        guard packet.count >= 20 else {
            logger.debug("Dropping packet: too small for IPv4 header")
            return
        }
        
        // Get IP protocol field (byte 9 in IPv4 header)
        let ipProtocol = packet[9]
        
        // Check if it's UDP or TCP
        guard ipProtocol == IPPROTO_UDP || ipProtocol == IPPROTO_TCP else {
            logger.debug("Dropping packet: unsupported IP protocol \(ipProtocol) (only TCP/UDP supported)")
            return
        }
        
        let protocolName = ipProtocol == IPPROTO_UDP ? "UDP" : "TCP"
        
        // Debug: Log specific ports
        if packet.count >= 24 {
            let destPort = (UInt16(packet[22]) << 8) | UInt16(packet[23])
            if destPort == 53 {
                logger.debug("DNS query detected on port 53")
            } else if destPort == 80 || destPort == 6121 {
                logger.debug("HTTP request detected to port \(destPort)")
            }
        }
        
        // Send the packet through MASQUE
        do {
            guard let client = masqueClient else {
                logger.error("MasqueClient is nil, dropping packet")
                return
            }
            
            let streamId = try client.send(packet)
            logger.debug("Sent \(protocolName) packet of size \(packet.count) bytes via MASQUE (stream ID: \(streamId))")
        } catch {
            logger.error("Failed to send packet via MASQUE: \(error.localizedDescription)")
        }
    }
    
    private func pollInboundData() {
        pollQueue.async { [weak self] in
            guard let self = self, self.isRunning else { return }
            
            // Check for handshake completion periodically
            if !self.hasLoggedHandshake, let client = self.masqueClient, client.isHandshakeComplete() {
                self.hasLoggedHandshake = true
                self.logger.log("MasqueClient: handshake completed")
            }
            
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
