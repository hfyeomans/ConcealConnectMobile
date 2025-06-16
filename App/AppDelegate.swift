import SwiftUI

@main
struct ConcealConnectApp: App {
    @StateObject private var vpnManager = VPNManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vpnManager)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var vpnManager: VPNManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text("👋 Conceal Connect")
                .font(.largeTitle)
                .padding()
            
            Text("Status: \(statusText)")
                .font(.headline)
            
            Text("On-Demand Rules Active")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Tunnel will automatically connect for:")
                .font(.caption)
            
            Text("*.masque.test domains")
                .font(.caption)
                .monospaced()
                .padding(.horizontal)
        }
        .padding()
    }
    
    private var statusText: String {
        switch vpnManager.status {
        case .invalid:
            return "Invalid"
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .reasserting:
            return "Reasserting..."
        case .disconnecting:
            return "Disconnecting..."
        @unknown default:
            return "Unknown"
        }
    }
}
