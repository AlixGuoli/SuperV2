//
//  PacketTunnelProvider.swift
//  core
//
//  Created by SHI QIU on 2025/11/26.
//

import NetworkExtension
import OSLog

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    private var nust5: Nust5? = nil

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // Add code here to start the process of connecting the tunnel.
        startNust5()
        completionHandler(nil)
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // Add code here to start the process of stopping the tunnel.
        nust5?.stopPacketTunnel()
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
    
    func startNust5(){
           if nust5 == nil{
               nust5  = Nust5(packetFlow: packetFlow)
           }
           nust5?.loadNetworkSettings = { [weak self] settings, completion in
               self?.setTunnelNetworkSettings(settings, completionHandler: completion)
           }
           nust5?.setupTCPConnection()
       }
}
