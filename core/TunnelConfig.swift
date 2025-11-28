//
//  TunnelConfig.swift
//  core
//
//  Created by SHI QIU on 2025/11/27.
//

import Foundation

class TunnelConfig {
    // 服务器配置
    static let serverPort = "49155"
    static let serverAddress = "64.176.43.209"
    
    // 加密密钥
    static let aesKey = "3e027e48ec6f5a9c705dfe17bed37201"
    static let xorKey = "hfor1"
    static let xorKeyLength = 128
    
    // 网络配置
    static let tunnelRemoteAddress = "10.10.0.1"
    static let dnsServer = "8.8.8.8"
    static let subnetMask = "255.255.0.0"
    static let mtu = 1400
    
    // 协议配置
    static let packageName = "com.vpn.kernel.core.tunnel"
    static let version = "1.0.0"
    static let country = "us"
    static let language = "en"
    static let sdkVersion = "7.0"
    static let actionNewConnect = "new_connect"
}

