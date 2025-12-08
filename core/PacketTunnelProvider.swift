//
//  PacketTunnelProvider.swift
//  core
//
//  Created by SHI QIU on 2025/11/26.
//

import NetworkExtension
import OSLog

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    //private var tunnelCore: TunnelCore? = nil
    
    private var netManager: TunnelConnectionHandler? = nil
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        os_log("[PacketTunnelProvider] Starting tunnel", log: OSLog.default, type: .error)
        //startTunnelCore()
        if !validateConnectionTimeframe() {
            let error = NSError(domain: "com.CatVPN.CatVPN", code: 1, userInfo: ["timeout": "timeout error"])
            self.cancelTunnelWithError(error)
            logOS("validateConnectionTimeframe false")
            return
        }
        logOS("validateConnectionTimeframe true")
        connect()
        completionHandler(nil)
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        os_log("[PacketTunnelProvider] Stopping tunnel, reason: %d", log: OSLog.default, type: .error, reason.rawValue)
        //tunnelCore?.endSession()
        netManager?.shutdownNetworkInfrastructure()
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
    func validateConnectionTimeframe() -> Bool {
        if let userDefaults = UserDefaults(suiteName: SharedConfig.storageGroup) {
            if let startDate = userDefaults.object(forKey: SharedConfig.timeKey) as? Date {
                let currentDate = Date()
                let timeInterval = currentDate.timeIntervalSince(startDate)
                if timeInterval < 10 {
                    logOS("PacketTunnelProvider less 10s")
                    //os_log("PacketTunnelProvider less 10s.", log: OSLog.default, type: .error)
                    return true
                }
            }
        }
        return false
    }
    
    func connect() {
        if netManager == nil {
            netManager = TunnelConnectionHandler()
        }
        
        netManager?.applyNetworkSettings = { [weak self] settings, completion in
            self?.setTunnelNetworkSettings(settings, completionHandler: completion)
        }
        
        Task {
            do {
                logOS("initializeNetworkTunnel")
                try await netManager?.initializeNetworkTunnel()
            } catch {
                logOS("initializeNetworkTunnel error")
            }
        }
    }
    
}
