//
//  PacketTunnelProvider.swift
//  core
//
//  Created by SHI QIU on 2025/11/26.
//

import NetworkExtension
import OSLog

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    private var tunnelCore: TunnelCore? = nil

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        os_log("[PacketTunnelProvider] Starting tunnel", log: OSLog.default, type: .error)
        startTunnelCore()
        completionHandler(nil)
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        os_log("[PacketTunnelProvider] Stopping tunnel, reason: %d", log: OSLog.default, type: .error, reason.rawValue)
        tunnelCore?.endSession()
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
    
    func startTunnelCore(){
           if tunnelCore == nil{
               tunnelCore  = TunnelCore(packetFlow: packetFlow)
           }
           tunnelCore?.configureNetwork = { [weak self] settings, completion in
               self?.setTunnelNetworkSettings(settings, completionHandler: completion)
           }
           tunnelCore?.beginSession()
       }
}
