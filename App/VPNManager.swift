import Foundation
import NetworkExtension
import os.log

/// Manages the VPN tunnel provider configuration and lifecycle
@MainActor
final class VPNManager: ObservableObject {
    private let logger = Logger(subsystem: "com.conceal.App", category: "VPNManager")
    
    @Published var isConnected = false
    @Published var status: NEVPNStatus = .invalid
    @Published var isLoading = true
    
    static let shared = VPNManager()
    
    private var tunnelManager: NETunnelProviderManager?
    
    private init() {
        #if targetEnvironment(simulator)
        logger.warning("NetworkExtension is not supported in the iOS Simulator. VPN functionality will not work.")
        self.status = .invalid
        self.isLoading = false
        #else
        loadTunnelConfiguration()
        #endif
    }
    
    /// Loads the existing tunnel configuration or creates a new one
    func loadTunnelConfiguration() {
        isLoading = true
        ensureManager { [weak self] manager in
            guard let self = self else { return }
            self.tunnelManager = manager
            self.isLoading = false
            self.observeStatus()
        }
    }
    
    /// Ensures a tunnel manager exists, creating one if needed
    private func ensureManager(completion: @escaping (NETunnelProviderManager?) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            guard let self = self else { 
                completion(nil)
                return 
            }
            
            if let error = error {
                self.logger.error("Failed to load tunnel managers: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            if let existingManager = managers?.first {
                self.logger.info("Using existing tunnel manager")
                completion(existingManager)
                return
            }
            
            // First launch: create and save a new manager
            self.logger.info("First launch: creating new tunnel manager")
            self.createAndSaveManager(completion: completion)
        }
    }
    
    /// Creates and saves a new tunnel provider configuration
    private func createAndSaveManager(completion: @escaping (NETunnelProviderManager?) -> Void) {
        let tunnelManager = NETunnelProviderManager()
        
        // Configure the tunnel provider protocol
        let tunnelProtocol = NETunnelProviderProtocol()
        tunnelProtocol.providerBundleIdentifier = "com.conceal.concealconnect.PacketTunnel"
        tunnelProtocol.serverAddress = "Conceal PA"  // Display name, actual server is in provider
        
        // Configure the tunnel
        tunnelManager.protocolConfiguration = tunnelProtocol
        tunnelManager.localizedDescription = "Conceal Private Access"
        tunnelManager.isEnabled = true
        
        // On-demand rule for masque.test domains
        let evaluateRule = NEOnDemandRuleEvaluateConnection()
        evaluateRule.connectionRules = [
            NEEvaluateConnectionRule(
                matchDomains: ["masque.test", "*.masque.test"],
                andAction: .connectIfNeeded
            )
        ]
        evaluateRule.interfaceTypeMatch = .any
        tunnelManager.onDemandRules = [evaluateRule]
        tunnelManager.isOnDemandEnabled = false  // Start with manual control
        
        // Save the configuration
        tunnelManager.saveToPreferences { [weak self] error in
            guard let self = self else { 
                completion(nil)
                return 
            }
            
            if let error = error {
                self.logger.error("Failed to save tunnel configuration: \(error.localizedDescription)")
                completion(nil)
            } else {
                self.logger.info("Tunnel configuration saved successfully")
                completion(tunnelManager)
            }
        }
    }
    
    /// Observes VPN status changes
    private func observeStatus() {
        guard let tunnelManager = tunnelManager else { return }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(vpnStatusDidChange(_:)),
            name: .NEVPNStatusDidChange,
            object: tunnelManager.connection
        )
        
        updateStatus(tunnelManager.connection.status)
    }
    
    @objc private func vpnStatusDidChange(_ notification: Notification) {
        guard let connection = notification.object as? NEVPNConnection else { return }
        updateStatus(connection.status)
    }
    
    private func updateStatus(_ status: NEVPNStatus) {
        DispatchQueue.main.async {
            self.status = status
            self.isConnected = (status == .connected)
            self.logger.info("VPN status changed to: \(String(describing: status))")
        }
    }
    
    /// Toggle VPN connection on/off
    func toggle(_ on: Bool) {
        #if targetEnvironment(simulator)
        logger.warning("Cannot toggle VPN in simulator - NetworkExtension not supported")
        return
        #endif
        
        guard let tunnelManager = tunnelManager else {
            logger.error("No tunnel manager available - ensuring manager exists")
            // Try to create manager if it doesn't exist
            ensureManager { [weak self] manager in
                guard let self = self, let manager = manager else { return }
                self.tunnelManager = manager
                self.performToggle(on)
            }
            return
        }
        
        // Disable on-demand when using manual toggle
        if tunnelManager.isOnDemandEnabled {
            tunnelManager.isOnDemandEnabled = false
            tunnelManager.saveToPreferences { [weak self] error in
                if let error = error {
                    self?.logger.error("Failed to update on-demand setting: \(error.localizedDescription)")
                    return
                }
                self?.performToggle(on)
            }
        } else {
            performToggle(on)
        }
    }
    
    private func performToggle(_ on: Bool) {
        guard let tunnelManager = tunnelManager else { return }
        
        do {
            if on {
                try tunnelManager.connection.startVPNTunnel()
                logger.info("Starting VPN tunnel")
            } else {
                tunnelManager.connection.stopVPNTunnel()
                logger.info("Stopping VPN tunnel")
            }
        } catch {
            logger.error("Toggle VPN failed: \(error.localizedDescription)")
        }
    }
    
    /// Manually starts the tunnel (for TP-4, not needed for on-demand)
    func connect() {
        toggle(true)
    }
    
    /// Manually stops the tunnel
    func disconnect() {
        toggle(false)
    }
}