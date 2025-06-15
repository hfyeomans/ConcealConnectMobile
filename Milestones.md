Next most useful milestone

Wire the Packet Tunnel Provider to use MasqueClient so real iOS traffic can flow through the tunnel. That unlocks end-to-end manual testing from Safari or any other app.

⸻

Sprint “Tunnel Provider MVP”
Seq
Task
Owner
Deliverable / PR title
TP-1
Create PacketTunnelProvider.swift skeleton• instantiate a single MasqueClient• override startTunnel(options:completionHandler:) and call connect()
iOS
“Add PacketTunnelProvider skeleton”
TP-2
Domain list hand-off• hard-code [\"*.masque.test\"] for now• build NEOnDemandRuleEvaluateConnection in the main app to trigger the extension when those domains are accessed
iOS
“Hard-coded domain rule for tunnel”
TP-3
Forward packets• in packetFlow.readPackets() wrap each IPv4/UDP payload in MASQUE (send) and drop others• in poll() pass inbound bytes to packetFlow.writePackets()
iOS
“PacketFlow ↔ MasqueClient bridging”
TP-4
Simple lifecycle UI• add a “Connect” toggle in the app• call NETunnelProviderManager.loadFromPreferences and .saveToPreferences
iOS UI
“Basic connect toggle screen”
TP-5
Smoke test on device• iPhone/iPad running iOS 18 Simulator or a real device• browse http://masque.test → should load through the tunnel echo server
QA
n/a

Definition of Done
	•	MasqueClient logs “handshake completed” inside the provider.
	•	curl http://masque.test in MobileSafari returns the test HTML page.
	•	No crashes when toggling connect/disconnect five times in a row.

⸻

To get started
	1.	Add a new target
In Xcode ▸ File ▸ New ▸ Target ▸ Network Extension ▸ Packet Tunnel
Bundle ID suggestion: com.Conceal.PacketTunnel
	2.	Enable App Group & Network Extension entitlements
Both the app and the extension need the same App Group (e.g. group.com.Conceal.shared) so they can share the domain list later.
	3.	Copy your working MasqueClient.swift into the extension target (or link TunnelCore as a dependency).

    