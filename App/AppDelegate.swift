import SwiftUI
import NetworkExtension

@main
struct ConcealConnectApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @StateObject private var vpnManager = VPNManager.shared
    
    var body: some View {
        VStack(spacing: 24) {
            Text("👋 Conceal Connect")
                .font(.largeTitle)
                .padding(.top, 40)
            
            Spacer()
            
            VStack(spacing: 16) {
                Toggle(isOn: Binding(
                    get: { vpnManager.status == .connected || vpnManager.status == .connecting },
                    set: { vpnManager.toggle($0) }
                )) {
                    Text("Private Access")
                        .font(.title2.weight(.semibold))
                }
                .toggleStyle(SwitchToggleStyle())
                .disabled(vpnManager.isLoading || vpnManager.status == .reasserting)
                .padding(.horizontal, 40)
                
                Text(statusText)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                #if targetEnvironment(simulator)
                Text("⚠️ Simulator Detected")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.orange)
                
                Text("Please run on a real iOS device for VPN functionality")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                #else
                Text("On-Demand Rules")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                
                Text("Auto-connects for *.masque.test domains")
                    .font(.caption)
                    .foregroundColor(.secondary)
                #endif
            }
            .padding(.bottom, 40)
        }
        .padding()
        .onAppear { vpnManager.loadTunnelConfiguration() }
    }
    
    private var statusText: String {
        #if targetEnvironment(simulator)
        return "VPN not supported in Simulator"
        #else
        if vpnManager.isLoading {
            return "Loading configuration..."
        }
        
        switch vpnManager.status {
        case .connected:
            return "Connected to MASQUE relay"
        case .connecting:
            return "Connecting..."
        case .disconnected:
            return "Not connected"
        case .disconnecting:
            return "Disconnecting..."
        case .reasserting:
            return "Reasserting..."
        case .invalid:
            return "Configuration needed"
        @unknown default:
            return "Unknown status"
        }
        #endif
    }
}
