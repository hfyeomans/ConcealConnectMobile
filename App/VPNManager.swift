import Foundation
import NetworkExtension
import os.log

/// Manages the VPN tunnel provider configuration and lifecycle
@MainActor
final class VPNManager: ObservableObject {
    private let logger = Logger(subsystem: "com.conceal.App", category: "VPNManager")
    
    @Published var isConnected = false
    @Published var status: NEVPNStatus = .invalid
    
    static let shared = VPNManager()
    
    private var tunnelManager: NETunnelProviderManager?
    
    private init() {
        loadTunnelConfiguration()
    }
    
    /// Loads the existing tunnel configuration or creates a new one
    func loadTunnelConfiguration() {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            guard let self = self else { return }
            
            if let error = error {
                self.logger.error("Failed to load tunnel managers: \(error.localizedDescription)")
                return
            }
            
            if let existingManager = managers?.first {
                self.logger.info("Using existing tunnel manager")
                self.tunnelManager = existingManager
                self.observeStatus()
            } else {
                self.logger.info("No existing tunnel manager found, creating new one")
                self.createTunnelConfiguration()
            }
        }
    }
    
    /// Creates a new tunnel provider configuration with on-demand rules
    private func createTunnelConfiguration() {
        let tunnelManager = NETunnelProviderManager()
        
        // Configure the tunnel provider protocol
        let tunnelProtocol = NETunnelProviderProtocol()
        tunnelProtocol.providerBundleIdentifier = "com.Conceal.PacketTunnel"
        tunnelProtocol.serverAddress = "10.0.150.43:6121"
        
        // Hard-code domain list for TP-2: ["*.masque.test"]
        let evaluateRule = NEOnDemandRuleEvaluateConnection()
        evaluateRule.connectionRules = [
            NEEvaluateConnectionRule(
                matchDomains: ["masque.test", "*.masque.test"],
                andAction: .connectIfNeeded
            )
        ]
        evaluateRule.interfaceTypeMatch = .any
        
        // Set up on-demand rules
        tunnelManager.onDemandRules = [evaluateRule]
        tunnelManager.isOnDemandEnabled = true
        
        // Configure the tunnel
        tunnelManager.protocolConfiguration = tunnelProtocol
        tunnelManager.localizedDescription = "ConcealConnect MASQUE Tunnel"
        tunnelManager.isEnabled = true
        
        // Save the configuration
        tunnelManager.saveToPreferences { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                self.logger.error("Failed to save tunnel configuration: \(error.localizedDescription)")
                return
            }
            
            self.logger.info("Tunnel configuration saved successfully")
            self.tunnelManager = tunnelManager
            self.observeStatus()
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
        guard let tunnelManager = tunnelManager else {
            logger.error("No tunnel manager available")
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