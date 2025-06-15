import NetworkExtension
import TunnelCore
import os.log

final class PacketTunnelProvider: NEPacketTunnelProvider {
    
    private var masqueClient: MasqueClient?
    private let logger = Logger(subsystem: "com.conceal.PacketTunnel", category: "Provider")
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        logger.log("Starting packet tunnel provider")
        
        // Instantiate MasqueClient
        masqueClient = MasqueClient()
        
        // TODO: Extract server host/port from options or configuration
        let serverHost = "masque.test" // Hard-coded for now
        let serverPort: UInt16 = 443
        
        do {
            // Call connect() on MasqueClient
            try masqueClient?.connect(host: serverHost, port: serverPort)
            logger.log("MasqueClient connected successfully to \(serverHost):\(serverPort)")
            
            // TODO: Configure tunnel settings
            
            completionHandler(nil)
        } catch {
            logger.error("Failed to connect MasqueClient: \(error.localizedDescription)")
            completionHandler(error)
        }
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        logger.log("Stopping packet tunnel provider with reason: \(reason.rawValue)")
        
        // Clean up MasqueClient
        masqueClient = nil
        
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        logger.log("Received app message of size: \(messageData.count)")
        completionHandler?(nil)
    }
}
