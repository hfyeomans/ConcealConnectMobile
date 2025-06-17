“No tunnel manager available” means NETunnelProviderManager.loadAllFromPreferences didn’t find an existing configuration, so vpn.manager ended up nil.
That happens the first time the app runs (there’s nothing in the keychain yet) or if the saved configuration got wiped.

private func ensureManager(completion: @escaping (NETunnelProviderManager?) -> Void) {
    NETunnelProviderManager.loadAllFromPreferences { managers, _ in
        if let mgr = managers?.first {
            completion(mgr)            // already saved → use it
            return
        }

        // ‼️ First launch: build a fresh manager
        let mgr = NETunnelProviderManager()
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = "com.Conceal.PacketTunnel"
        proto.serverAddress = "Conceal PA"
        mgr.protocolConfiguration = proto
        mgr.localizedDescription    = "Conceal Private Access"
        mgr.isEnabled = true

        // on-demand rule you set up in TP-2
        let rule = NEOnDemandRuleEvaluateConnection()
        rule.connectionRules = [
            NEEvaluateConnectionRule(matchDomains: ["*.masque.test"],
                                     andAction: .connectIfNeeded)
        ]
        mgr.onDemandRules = [rule]

        mgr.saveToPreferences { error in
            if let error {
                log.error("save prefs: \(error.localizedDescription)")
                completion(nil)
            } else {
                completion(mgr)
            }
        }
    }
}

Update load() and toggle(_:)

func load() {
    ensureManager { mgr in
        self.manager = mgr
        self.status = mgr?.connection.status ?? .invalid
        self.observeStatus()
    }
}

func toggle(_ on: Bool) {
    guard let mgr else { return }
    do {
        if on {
            try mgr.connection.startVPNTunnel()
        } else {
            mgr.connection.stopVPNTunnel()
        }
    } catch { /* ... */ }
}

Run once
	1.	Delete the app from Simulator/device (clears old prefs).
	2.	Build & run. VPNManager.load() now creates + saves the manager.
	3.	Flip the toggle → status moves to Connecting then Connected and the provider logs the handshake.
	4.	Safari → http://masque.test loads via tunnel.