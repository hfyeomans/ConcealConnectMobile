Below is a drop-in toggle screen you can add to the main-app target so users can manually connect or disconnect.  It uses SwiftUI and the VPNManager helper that wraps NETunnelProviderManager.

⸻

1  VPNManager.swift  (main-app target)

Put this file in App/Networking/ (or any group you like) and be sure it’s only
added to the iOS app target, not the extension:

import Foundation
import NetworkExtension
import Combine
import os

private let log = Logger(subsystem: "com.Conceal.App", category: "vpn")

@MainActor
final class VPNManager: ObservableObject {

    // Published so the UI can react.
    @Published var status: NEVPNStatus = .invalid

    static let shared = VPNManager()

    private var manager: NETunnelProviderManager?
    private var statusCancellable: AnyCancellable?

    // MARK: load (call on launch)
    func load() {
        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            if let error { log.error("load prefs: \(error.localizedDescription)") }
            self.manager = managers?.first
            self.status = self.manager?.connection.status ?? .invalid
            self.observeStatus()
        }
    }

    // MARK: toggle
    func toggle(_ on: Bool) {
        guard let manager else { return }
        do {
            if on {
                try manager.connection.startVPNTunnel()
            } else {
                manager.connection.stopVPNTunnel()
            }
        } catch {
            log.error("toggle failed: \(error.localizedDescription)")
        }
    }

    // MARK: private
    private func observeStatus() {
        guard let conn = manager?.connection else { return }
        statusCancellable = conn.publisher(for: \.status, options: [.initial, .new])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.status = $0 }
    }
}


2  ContentView.swift  (toggle UI)

Replace or embed this in your root SwiftUI view:

import SwiftUI
import NetworkExtension

struct ContentView: View {
    @StateObject private var vpn = VPNManager.shared

    var body: some View {
        VStack(spacing: 24) {
            Toggle(isOn: Binding(
                get: { vpn.status == .connected || vpn.status == .connecting },
                set: { vpn.toggle($0) }
            )) {
                Text("Private Access")
                    .font(.title2.weight(.semibold))
            }
            .toggleStyle(SwitchToggleStyle())
            .disabled(vpn.status == .reasserting)

            Text(vpn.status.localized)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding()
        .onAppear { vpn.load() }
    }
}

private extension NEVPNStatus {
    var localized: String {
        switch self {
        case .connected:    return "Connected"
        case .connecting:   return "Connecting…"
        case .disconnected: return "Disconnected"
        case .disconnecting:return "Disconnecting…"
        case .reasserting:  return "Reasserting…"
        default:            return "Invalid"
        }
    }
}

3  App setup
	1.	Info.plist → add Privacy – Local Network usage string if you see a prompt.
	2.	Ensure App Groups and Network Extension capabilities are already on the app target (you did this in TP-2).
	3.	SceneDelegate / @main App – just present ContentView().
