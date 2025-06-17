# iOS Simulator Limitations

## NetworkExtension Not Supported in Simulator

The iOS Simulator does not support NetworkExtension framework functionality, which means VPN features cannot be tested in the simulator.

### Error Messages in Simulator

When running in the simulator, you'll see these errors:
```
Failed to send a 6 message to nehelper: Connection invalid
Failed to load configurations: Error Domain=NEConfigurationErrorDomain Code=11 "IPC failed"
Failed to load tunnel managers: IPC failed
```

### Why This Happens

1. **nehelper** (NetworkExtension helper) is not available in the simulator
2. IPC (Inter-Process Communication) with system VPN services fails
3. NETunnelProviderManager cannot create or load VPN configurations

### Solution

**You must test VPN functionality on a real iOS device.**

### App Behavior in Simulator

The app detects when running in the simulator and:
- Displays "VPN not supported in Simulator" status
- Shows warning message to use a real device
- Disables VPN toggle functionality
- Prevents crash from IPC failures

### Testing Requirements

To test VPN functionality:
1. Use a real iPhone or iPad
2. iOS 18.5 or later
3. Valid provisioning profile with NetworkExtension capability
4. Developer account with NetworkExtension entitlement

### Conditional Compilation

The code uses `#if targetEnvironment(simulator)` to handle simulator limitations gracefully.