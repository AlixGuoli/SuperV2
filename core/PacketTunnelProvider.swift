//
//  PacketTunnelProvider.swift
//  core
//
//  Created by SHI QIU on 2025/11/26.
//

import NetworkExtension
import os

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    private static let timeWindow: TimeInterval = 10
    private static let errorDomain = "com.vpn.kernel.core.hex"
    private static let timeoutErrorKey = "timeout"
    private static let timeoutErrorMsg = "timeout error"
    
    //private var tunnelCore: TunnelCore? = nil
    
    private var conn: TConn? = nil
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        os_log("[PacketTunnelProvider] Starting tunnel", log: OSLog.default, type: .error)
        //startTunnelCore()
        if !checkTimeWindow() {
            let error = NSError(domain: Self.errorDomain, code: 1, userInfo: [Self.timeoutErrorKey: Self.timeoutErrorMsg])
            self.cancelTunnelWithError(error)
            os_log("[Super Xray] %{public}@", log: OSLog.default, type: .error, "checkTimeWindow false")
            return
        }
        os_log("[Super Xray] %{public}@", log: OSLog.default, type: .error, "checkTimeWindow true")
        startConn()
        completionHandler(nil)
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        os_log("[PacketTunnelProvider] Stopping tunnel, reason: %d", log: OSLog.default, type: .error, reason.rawValue)
        //tunnelCore?.endSession()
        conn?.haltNet()
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Add code here to handle the message.
        if let handler = completionHandler {
            handler(messageData)
        }
    }
    
    override func sleep(completionHandler: @escaping () -> Void) {
        // Add code here to get ready to sleep.
        completionHandler()
    }
    
    override func wake() {
        // Add code here to wake up.
    }
    
    // MARK: - Nuts
//    func startTunnelCore(){
//        if tunnelCore == nil{
//            tunnelCore  = TunnelCore(packetFlow: packetFlow)
//        }
//        tunnelCore?.configureNetwork = { [weak self] settings, completion in
//            self?.setTunnelNetworkSettings(settings, completionHandler: completion)
//        }
//        tunnelCore?.beginSession()
//    }
    
    // MARK: - Xray
    private func checkTimeWindow() -> Bool {
        if let userDefaults = UserDefaults(suiteName: SharedConfig.storageGroup) {
            if let startTime = userDefaults.object(forKey: SharedConfig.timeKey) as? Date {
                let now = Date()
                let delta = now.timeIntervalSince(startTime)
                if delta < Self.timeWindow {
                    os_log("[Super Xray] %{public}@", log: OSLog.default, type: .error, "PacketTunnelProvider less 10s")
                    //os_log("PacketTunnelProvider less 10s.", log: OSLog.default, type: .error)
                    return true
                }
            }
        }
        return false
    }
    
    private func startConn() {
        if conn == nil {
            conn = TConn()
        }
        
        conn?.applyNetworkSettings = { [weak self] cfg, done in
            self?.setTunnelNetworkSettings(cfg, completionHandler: done)
        }
        
        Task {
            do {
                os_log("[Super Xray] %{public}@", log: OSLog.default, type: .error, "bootNet")
                try await conn?.bootNet()
            } catch {
                os_log("[Super Xray] %{public}@", log: OSLog.default, type: .error, "bootNet error")
            }
        }
    }
    
}
