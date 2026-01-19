//
//  TunnelCore.swift
//  CoreVPN
//
//  Created by SHI QIU on 2025/11/27.
//

import Foundation
import NetworkExtension
import os
import CommonCrypto
import Network

class TunnelCore {
    var channel: NWConnection?
    var executor: DispatchQueue?
    
    var inputBuffer = Data()
    var outputBuffer = Data()
    
    var configureNetwork: ((NEPacketTunnelNetworkSettings, @escaping (Error?) -> Void) -> Void)?
    var stream: NEPacketTunnelFlow
    
    init(packetFlow: NEPacketTunnelFlow) {
        self.stream = packetFlow
    }
    
    func beginSession() {
        os_log("[TunnelCore] Initializing session", log: OSLog.default, type: .error)
        guard let port = NWEndpoint.Port(TunnelConfig.serverPort) else {
            os_log("[TunnelCore] Invalid port configuration", log: OSLog.default, type: .error)
            return
        }
        
        let endpointHost = NWEndpoint.Host(TunnelConfig.serverAddress)
        channel = NWConnection(host: endpointHost, port: port, using: .tcp)
        self.executor = .global()
        self.channel?.stateUpdateHandler = self.sessionStateUpdated(_:)
        self.channel?.start(queue: self.executor!)
        os_log("[TunnelCore] Session started", log: OSLog.default, type: .error)
    }
    
    func sessionStateUpdated(_ state: NWConnection.State) {
        switch state {
        case .ready:
            os_log("[TunnelCore] Channel ready", log: OSLog.default, type: .error)
            acquireEndpoint()
        case .failed(let error):
            os_log("[TunnelCore] Channel failed: %{public}@", log: OSLog.default, type: .error, error.localizedDescription)
        case .waiting(let error):
            os_log("[TunnelCore] Channel waiting: %{public}@", log: OSLog.default, type: .error, error.localizedDescription)
        case .cancelled:
            os_log("[TunnelCore] Channel cancelled", log: OSLog.default, type: .error)
        default:
            os_log("[TunnelCore] Channel state: %{public}@", log: OSLog.default, type: .error, String(describing: state))
        }
    }
    
    func acquireEndpoint() {
        os_log("[TunnelCore] Requesting endpoint", log: OSLog.default, type: .error)
        guard let data = createHandshake() else {
            os_log("[TunnelCore] Failed to create handshake", log: OSLog.default, type: .error)
            return
        }
        let encryptedData = processData(data: data, key: getXorKeyBytes())
        self.channel?.send(content: encryptedData, completion: .contentProcessed({ [weak self] error in
            guard let self = self, error == nil else {
                os_log("[TunnelCore] Failed to send handshake: %{public}@", log: OSLog.default, type: .error, error?.localizedDescription ?? "Unknown")
                return
            }
            os_log("[TunnelCore] Handshake sent, waiting for response", log: OSLog.default, type: .error)
            self.readMetadata()
        }))
    }
    
    private func readMetadata() {
        channel?.receive(minimumIncompleteLength: 2, maximumLength: 2) { [weak self] data, _, _, error in
            guard let self = self, let data = data, error == nil else {
                if let error = error {
                    os_log("[TunnelCore] Failed to read metadata: %{public}@", log: OSLog.default, type: .error, error.localizedDescription)
                }
                return
            }
            self.inputBuffer.append(data)
            if self.inputBuffer.count >= 2 {
                let length = self.inputBuffer.prefix(2).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
                self.inputBuffer.removeFirst(2)
                os_log("[TunnelCore] Metadata received, content length: %d", log: OSLog.default, type: .error, Int(length))
                self.readContent(length: Int(length))
            } else {
                self.readMetadata()
            }
        }
    }
    
    private func readContent(length: Int) {
        channel?.receive(minimumIncompleteLength: 1, maximumLength: 1024) { [weak self] data, _, _, error in
            guard let self = self, let data = data, error == nil else {
                if let error = error {
                    os_log("[TunnelCore] Failed to read content: %{public}@", log: OSLog.default, type: .error, error.localizedDescription)
                }
                return
            }
            self.inputBuffer.append(data)
            if self.inputBuffer.count >= length {
                let encryptedResponse = self.inputBuffer.prefix(length)
                self.inputBuffer.removeFirst(length)
                let decryptedResponse = unprocessData(data: encryptedResponse, key: getXorKeyBytes())
                let responseIPs = String(data: decryptedResponse, encoding: .utf8)
                let internalIP = self.selectAddress(from: responseIPs!)
                os_log("[TunnelCore] Endpoint acquired: %{public}@", log: OSLog.default, type: .error, internalIP)
                self.configureEndpoint(ip: internalIP)
            } else {
                self.readContent(length: length)
            }
        }
    }
    
    func configureEndpoint(ip: String) {
        os_log("[TunnelCore] Configuring endpoint with IP: %{public}@", log: OSLog.default, type: .error, ip)
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: TunnelConfig.tunnelRemoteAddress)
        settings.mtu = TunnelConfig.mtu as NSNumber
        settings.dnsSettings = NEDNSSettings(servers: [TunnelConfig.dnsServer])
        settings.ipv4Settings = {
            let ipv4Settings = NEIPv4Settings(addresses: [ip], subnetMasks: [TunnelConfig.subnetMask])
            ipv4Settings.includedRoutes = [NEIPv4Route.default()]
            return ipv4Settings
        }()
        self.configureNetwork?(settings) { [weak self] error in
            guard let self = self, error == nil else {
                os_log("[TunnelCore] Failed to configure network: %{public}@", log: OSLog.default, type: .error, error?.localizedDescription ?? "Unknown")
                return
            }
            os_log("[TunnelCore] Network configured, starting data flow", log: OSLog.default, type: .error)
            self.transmitOut()
            self.transmitIn()
        }
    }
    
    func transmitOut() {
        let secretKey = getXorKeyBytes()
        self.stream.readPackets { [weak self] (packets: [Data], _) in
            guard let self = self else { return }
            for packet in packets {
                let encryptedData = self.processData(data: packet, key: secretKey)
                self.channel?.send(content: encryptedData, completion: .contentProcessed({ error in
                    if error != nil { return }
                }))
            }
            self.transmitOut()
        }
    }
    
    func transmitIn() {
        self.channel?.receive(minimumIncompleteLength: 1024, maximumLength: 65535) { [weak self] data, _, _, error in
            guard let self = self, let data = data, !data.isEmpty else { return }
            self.outputBuffer.append(data)
            self.handleContent()
            self.transmitIn()
        }
    }
    
    private func handleContent() {
        let secretKey = getXorKeyBytes()
        while self.outputBuffer.count >= 2 {
            guard let length = parsePacketLength() else {
                break
            }
            if self.outputBuffer.count >= length {
                let encryptedResponse = self.outputBuffer.prefix(Int(length))
                self.outputBuffer.removeSubrange(0..<Int(length))
                writeDecryptedPacket(encryptedResponse, key: secretKey)
            } else {
                self.outputBuffer.insert(contentsOf: withUnsafeBytes(of: length.bigEndian, Array.init), at: 0)
                break
            }
        }
    }
    
    private func parsePacketLength() -> UInt16? {
        guard self.outputBuffer.count >= 2 else {
            return nil
        }
        let length = self.outputBuffer.prefix(2).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
        self.outputBuffer.removeSubrange(0..<2)
        return length
    }
    
    private func writeDecryptedPacket(_ encryptedData: Data, key: Data) {
        let decryptedResponse = unprocessData(data: encryptedData, key: key)
        let protocolNumber = AF_INET as NSNumber
        self.stream.writePackets([decryptedResponse], withProtocols: [protocolNumber])
    }
    
    func processData(data: Data, key: Data) -> Data {
        let (randomPadding, randomByte) = generateRandomPadding()
        let dataToEncrypt = randomPadding + data + Data([randomByte])
        let encryptedData = applyXorTransform(dataToEncrypt, key: key)
        return prependLengthHeader(encryptedData)
    }
    
    private func generateRandomPadding() -> (Data, UInt8) {
        let randlen = UInt8(TunnelConfig.xorKeyLength)
        let randomByte = UInt8.random(in: 0...randlen)
        let randomData = Data((0..<Int(randomByte)).map { _ in UInt8.random(in: 0...255) })
        return (randomData, randomByte)
    }
    
    private func applyXorTransform(_ data: Data, key: Data) -> Data {
        return Data(data.enumerated().map { index, byte in
            byte ^ key[index % key.count]
        })
    }
    
    private func prependLengthHeader(_ data: Data) -> Data {
        let dataLength = UInt16(data.count).asBytes()
        return dataLength + data
    }
    
    func selectAddress(from responseIPs: String) -> String {
        let ips = responseIPs.split(separator: ",").map { String($0) }
        return ips.first ?? ""
    }
    
    func endSession() {
        os_log("[TunnelCore] Ending session", log: OSLog.default, type: .error)
        self.channel?.cancel()
    }
    
    // MARK: - 辅助方法
    
    private func getXorKeyBytes() -> Data {
        return TunnelConfig.xorKey.data(using: .utf8)!
    }
    
    private func getAesKeyBytes() -> Data {
        return TunnelConfig.aesKey.data(using: .utf8)!
    }
    
    func createHandshake() -> Data? {
        guard let jsonData = buildHandshakeDict() else {
            os_log("[TunnelCore] Failed to prepare handshake data", log: OSLog.default, type: .error)
            return nil
        }
        guard let encryptedData = encryptHandshakeData(jsonData) else {
            return nil
        }
        os_log("[TunnelCore] Handshake created successfully", log: OSLog.default, type: .error)
        return encryptedData
    }
    
    private func buildHandshakeDict() -> Data? {
        let dataDict: [String: Any] = ["package": TunnelConfig.packageName, "version": TunnelConfig.version, "SDK": TunnelConfig.sdkVersion, "country": TunnelConfig.country, "language": TunnelConfig.language, "action": TunnelConfig.actionNewConnect]
        return try? JSONSerialization.data(withJSONObject: dataDict, options: [])
    }
    
    private func encryptHandshakeData(_ jsonData: Data) -> Data? {
        let keyData = getAesKeyBytes()
        let dataToEncrypt = [UInt8](jsonData)
        let keyBytes = [UInt8](keyData)
        
        var encryptedBytes = [UInt8](repeating: 0, count: dataToEncrypt.count + kCCBlockSizeAES128)
        var numBytesEncrypted = 0
        let status = CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionPKCS7Padding | kCCOptionECBMode), keyBytes, keyData.count, nil, dataToEncrypt, dataToEncrypt.count, &encryptedBytes, encryptedBytes.count, &numBytesEncrypted)
        guard status == kCCSuccess else {
            os_log("[TunnelCore] Encryption failed with status: %d", log: OSLog.default, type: .error, status)
            return nil
        }
        return Data(bytes: encryptedBytes, count: numBytesEncrypted)
    }
    
    func unprocessData(data: Data, key: Data) -> Data {
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
    func asBytes() -> Data {
        return Data([UInt8(self >> 8), UInt8(self & 0xFF)])
    }
}
