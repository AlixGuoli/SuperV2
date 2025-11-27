//
//  nusts.swift
//  CoreVPN
//
//  Created by SHI QIU on 2025/11/27.
//

import Foundation
import NetworkExtension
import os
import CommonCrypto
import Network

class Nust5{
    var connection: NWConnection?
    var queue: DispatchQueue?
    
    var serverPort = "49155"
    var serverAddress = "64.176.43.209"
    
    var country = "us"
    var language = "en"
    var package = "com.vpn.kernel.core.tunnel"
    var version = "1.0.0"
    
    var key = "3e027e48ec6f5a9c705dfe17bed37201"
    var receiveBuffer = Data()
    var buffer = Data()
    
    var cf_key = "hfor1"
    var cf_len_int = 128
    
    var loadNetworkSettings: ((NEPacketTunnelNetworkSettings, @escaping (Error?) -> Void) -> Void)?
    var packetFlow: NEPacketTunnelFlow
    
    init(packetFlow: NEPacketTunnelFlow) {
        self.packetFlow = packetFlow
    }
    
    func setupTCPConnection() {
        os_log("hellovpn nust5 setupConfuseTCPConnection: %{public}@", log: OSLog.default, type: .error, "setupConfuseTCPConnection")
        guard let port = NWEndpoint.Port(serverPort) else { return }
        
        let endpointHost = NWEndpoint.Host(serverAddress)
        connection = NWConnection(host: endpointHost, port: port, using: .tcp)
        self.queue = .global()
        self.connection?.stateUpdateHandler = self.onStateDidChange(to:)
        self.connection?.start(queue: self.queue!)
    }
    
    func onStateDidChange(to state: NWConnection.State) {
        switch state {
        case .ready:
            getNutsIP()
        case .failed(_), .cancelled:
            os_log("hellovpn getNutsIP failed: %{public}@", log: OSLog.default, type: .error, "getNutsIP failed")
        default: break
        }
    }
    
    func getNutsIP() {
        os_log("hellovpn getNutsIP: %{public}@", log: OSLog.default, type: .error, "getNutsIP")
        guard let data = encryptDataWithCommonCrypto() else { return }
        let encryptedData = encryptData(data: data, key: self.cf_key.data(using: .utf8)!)
        self.connection?.send(content: encryptedData, completion: .contentProcessed({ [weak self] error in
            guard let self = self, error == nil else { return }
            self.receiveHeader()
        }))
    }
    
    private func receiveHeader() {
        connection?.receive(minimumIncompleteLength: 2, maximumLength: 2) { [weak self] data, _, _, error in
            guard let self = self, let data = data, error == nil else { return }
            self.receiveBuffer.append(data)
            if self.receiveBuffer.count >= 2 {
                let length = self.receiveBuffer.prefix(2).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
                self.receiveBuffer.removeFirst(2)
                self.receiveData(ofLength: Int(length))
            } else {
                self.receiveHeader()
            }
        }
    }
    
    private func receiveData(ofLength length: Int) {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 1024) { [weak self] data, _, _, error in
            guard let self = self, let data = data, error == nil else { return }
            self.receiveBuffer.append(data)
            if self.receiveBuffer.count >= length {
                let encryptedResponse = self.receiveBuffer.prefix(length)
                self.receiveBuffer.removeFirst(length)
                let decryptedResponse = decryptData(data: encryptedResponse, key: self.cf_key.data(using: .utf8)!)
                let responseIPs = String(data: decryptedResponse, encoding: .utf8)
                let internalIP = self.extractInternalIP(responseIPs: responseIPs!)
                os_log("hellovpn internalIP: %{public}@", log: OSLog.default, type: .error, internalIP)
                self.setupNetworkSettings(intranetIP: internalIP)
            } else {
                self.receiveData(ofLength: length)
            }
        }
    }
    
    func setupNetworkSettings(intranetIP: String) {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "10.10.0.1")
        settings.mtu = 1400
        settings.dnsSettings = NEDNSSettings(servers: ["8.8.8.8"])
        settings.ipv4Settings = {
            let ipv4Settings = NEIPv4Settings(addresses: [intranetIP], subnetMasks: ["255.255.0.0"])
            ipv4Settings.includedRoutes = [NEIPv4Route.default()]
            return ipv4Settings
        }()
        self.loadNetworkSettings?(settings) { [weak self] error in
            guard let self = self, error == nil else { return }
            self.tunToTCP()
            self.tcpToTun()
        }
    }
    
    func tunToTCP() {
        let secretKey = "hfor1".data(using: .utf8)!
        self.packetFlow.readPackets { [weak self] (packets: [Data], _) in
            guard let self = self else { return }
            for packet in packets {
                let encryptedData = self.encryptData(data: packet, key: secretKey)
                self.connection?.send(content: encryptedData, completion: .contentProcessed({ error in
                    if error != nil { return }
                }))
            }
            self.tunToTCP()
        }
    }
    
    func tcpToTun() {
        self.connection?.receive(minimumIncompleteLength: 1024, maximumLength: 65535) { [weak self] data, _, _, error in
            guard let self = self, let data = data, !data.isEmpty else { return }
            self.buffer.append(data)
            self.processBuffer()
            self.tcpToTun()
        }
    }
    
    private func processBuffer() {
        let secretKey = "hfor1".data(using: .utf8)!
        while self.buffer.count >= 2 {
            let length = self.buffer.prefix(2).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
            self.buffer.removeSubrange(0..<2)
            if self.buffer.count >= length {
                let encryptedResponse = self.buffer.prefix(Int(length))
                self.buffer.removeSubrange(0..<Int(length))
                let decryptedResponse = decryptData(data: encryptedResponse, key: secretKey)
                let protocolNumber = AF_INET as NSNumber
                self.packetFlow.writePackets([decryptedResponse], withProtocols: [protocolNumber])
            } else {
                self.buffer.insert(contentsOf: withUnsafeBytes(of: length.bigEndian, Array.init), at: 0)
                break
            }
        }
    }
    
    func encryptData(data: Data, key: Data) -> Data {
        let randlen = UInt8(self.cf_len_int)
        let randomByte = UInt8.random(in: 0...randlen)
        let randomData = Data((0..<Int(randomByte)).map { _ in UInt8.random(in: 0...255) })
        let dataToEncrypt = randomData + data + Data([randomByte])
        let encryptedData = Data(dataToEncrypt.enumerated().map { index, byte in
            byte ^ key[index % key.count]
        })
        let dataLength = UInt16(encryptedData.count).toByteArray()
        return dataLength + encryptedData
    }
    
    func extractInternalIP(responseIPs: String) -> String {
        let ips = responseIPs.split(separator: ",").map { String($0) }
        return ips.first ?? ""
    }
    
    func stopPacketTunnel() {
        self.connection?.cancel()
    }
    
    func encryptDataWithCommonCrypto() -> Data? {
        let dataDict: [String: Any] = ["package": package, "version": version, "SDK": "7.0", "country": country, "language": language, "action": "new_connect"]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dataDict, options: []),
              let keyData = key.data(using: .utf8) else {
            return nil
        }
        let dataToEncrypt = [UInt8](jsonData)
        let keyBytes = [UInt8](keyData)
        
        var encryptedBytes = [UInt8](repeating: 0, count: dataToEncrypt.count + kCCBlockSizeAES128)
        var numBytesEncrypted = 0
        let status = CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionPKCS7Padding | kCCOptionECBMode), keyBytes, keyData.count, nil, dataToEncrypt, dataToEncrypt.count, &encryptedBytes, encryptedBytes.count, &numBytesEncrypted)
        guard status == kCCSuccess else {
            return nil
        }
        return Data(bytes: encryptedBytes, count: numBytesEncrypted)
    }
    
    func decryptData(data: Data, key: Data) -> Data {
        let encryptedDecryptedData = Data(data.enumerated().map { index, byte in
            byte ^ key[index % key.count]
        })
        if encryptedDecryptedData.count > 0 {
            let randomByte = encryptedDecryptedData.last!
            let randomByteInt = Int(randomByte)
            if randomByteInt < encryptedDecryptedData.count {
                return encryptedDecryptedData.subdata(in: randomByteInt..<(encryptedDecryptedData.count - 1))
            }
        }
        return encryptedDecryptedData
    }
    
}

extension UInt16 {
    func toByteArray() -> Data {
        return Data([UInt8(self >> 8), UInt8(self & 0xFF)])
    }
}
