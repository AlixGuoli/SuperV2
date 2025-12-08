//
//  SecureConfigDecoder.swift
//  CoreVPN
//
//  解密 core.tun / git 返回的加密配置，得到 JSON 文本
//

import Foundation
import CryptoKit

enum SecureConfigDecoder {

    /// 与旧项目一致的 AES 密钥字符串（不要改值，只换实现方式和命名）
    private static let rawAESKey = "f92mUj0K1uBnMlXGFQKrYP07Emgc4yFmWYS8WRgy4IY="

    /// 解密 core.tun / git 返回的加密字符串，得到 JSON 文本
    ///
    /// - Parameter encoded: 形如 `"base64Cipher,hexIV,extra"` 的字符串
    /// - Returns: 解密后的 JSON 字符串，失败返回 nil
    static func decodeConfigPayload(_ encoded: String) -> String? {
        //debugPrint("[Request] 解密配置开始 decodeConfigPayload")
        // 拆分为三段
        let segments = encoded.split(separator: ",")
        guard segments.count >= 2 else {
            debugPrint("[Request] 解密配置失败：格式错误（段数不足）")
            return nil
        }

        let base64Cipher = segments[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let hexIV = segments[1].trimmingCharacters(in: .whitespacesAndNewlines)

        // 生成对称密钥：取 aesKey 的前 32 字节
        guard let keyDataAll = rawAESKey.data(using: .utf8),
              keyDataAll.count >= 16 else {
            debugPrint("[Request] 解密配置失败：AES 密钥数据异常")
            return nil
        }
        let keyData = keyDataAll.subdata(in: 0..<min(32, keyDataAll.count))
        let symmetricKey = SymmetricKey(data: keyData)

        guard let ivData = data(fromHex: hexIV),
              let cipherData = Data(base64Encoded: base64Cipher) else {
            debugPrint("[Request] 解密配置失败：IV 或密文转换失败")
            return nil
        }

        do {
            // CryptoKit 的 AES.GCM.SealedBox(combined:) 期望的格式是 nonce(12字节)+cipher+tag
            // 旧项目里是 ivData + encryptedData，已经按 combined 格式拼好，这里保持一致
            let combined = ivData + cipherData
            let sealedBox = try AES.GCM.SealedBox(combined: combined)
            let decrypted = try AES.GCM.open(sealedBox, using: symmetricKey)
            let result = String(data: decrypted, encoding: .utf8)
            //debugPrint("[Request] 解密配置成功 decodeConfigPayload")
            return result
        } catch {
            debugPrint("[Request] 解密配置失败：\(error.localizedDescription)")
            return nil
        }
    }

    /// 从十六进制字符串构造 Data
    private static func data(fromHex hex: String) -> Data? {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count % 2 == 0 else { return nil }

        var data = Data(capacity: cleaned.count / 2)
        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let nextIndex = cleaned.index(index, offsetBy: 2)
            let byteString = cleaned[index..<nextIndex]
            guard let byte = UInt8(byteString, radix: 16) else {
                return nil
            }
            data.append(byte)
            index = nextIndex
        }
        return data
    }
}

