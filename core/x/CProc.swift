//
//  NetHelper.swift
//  CoreVPN
//
//  Created by SHI QIU on 2025/12/8.
//

import Foundation
import os

class CProc {
    
    // MARK: - 静态常量
    
    // 原始Base32字符串（保持不变）
    static let originalBase32 = """
OR2W43TFNQ5AUIBANV2HKORAHEYDAMAKONXWG23TGU5AUIBAOBXXE5B2EA4DAOBQBIQCAYLEMRZGK43THIQDUORRBIQCA5LEOA5CAJ3VMRYCOCTNNFZWGOQKEAQHIYLTNMWXG5DBMNVS243JPJSTUIBSGA2DQMAKEAQGG33ONZSWG5BNORUW2ZLPOV2DUIBVGAYDACRAEBZGKYLEFV3XE2LUMUWXI2LNMVXXK5B2EA3DAMBQGAFCAIDMN5TS2ZTJNRSTUIDTORSGK4TSBIQCA3DPM4WWYZLWMVWDUIDFOJZG64QKEAQGY2LNNF2C23TPMZUWYZJ2EA3DKNJTGU======
"""
    
    private static let cfgFile = "ConfigCore"
    private static let socksFile = "SocksCore"

    // MARK: - Base32解码算法
    
    static func b32Plain(_ input: String) -> String? {
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        var bitCount = 0
        var acc = 0
        var buffer = Data()
        
        for char in input.uppercased() {
            if char == "=" {
                break
            }
            
            guard let charVal = alphabet.firstIndex(of: char)?.encodedOffset else {
                return nil
            }
            
            acc = (acc << 5) | charVal
            bitCount += 5
            
            while bitCount >= 8 {
                bitCount -= 8
                buffer.append(UInt8((acc >> bitCount) & 0xFF))
            }
        }
        
        return String(data: buffer, encoding: .utf8)
    }
    
    // MARK: - 配置解码
    
    static var plainCfg: String? {
        // 直接按原始Base32解码（移除旧包装前后缀）
        return b32Plain(originalBase32)
    }
    
    // MARK: - 数据准备
    
    private static func grabCfg() -> String {
        let userDefaults = UserDefaults(suiteName: SharedConfig.storageGroup)
        return userDefaults?.string(forKey: SharedConfig.dataKey) ?? ""
    }
    
    private static func cfgBytes() -> Data? {
        return plainCfg?.data(using: .utf8)
    }
    
    // MARK: - 文件操作
    
    static func docHome() -> URL {
        let fileManager = FileManager.default
        let directoryURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return directoryURL
    }
    
    static func store(withName name: String, data: Data?) -> URL {
        let directoryURL = docHome()
        let fileURL = directoryURL.appendingPathComponent(name)
        
        do {
            try data?.write(to: fileURL)
        } catch {
            os_log("[Super Xray] %{public}@", log: OSLog.default, type: .error, "writeDataToFile Error : \(error)")
        }
        
        return fileURL
    }
    
    // MARK: - 文件创建
    
    private static func outCfg(with configData: String) -> URL {
        return store(withName: cfgFile, data: configData.data(using: .utf8))
    }
    
    private static func outSocks(with data: Data?) -> URL {
        return store(withName: socksFile, data: data)
    }
    
    private static func jsonCfg(with filePath: URL) -> String {
        return """
            {
                "datDir": "",
                "configPath": "\(filePath.path)",
                "maxMemory": \(31457280)
            }
            """
    }
    
    // MARK: - 配置管理
    
    static func mkDirCfg() -> String {
        return mkDirCfgInner()
    }
    
    private static func mkDirCfgInner() -> String {
        let cfgRaw = grabCfg()
        let cfgURL = outCfg(with: cfgRaw)
        return jsonCfg(with: cfgURL)
    }
    
    static func mkSocksPath() -> String {
        return mkSocksPathInner()
    }
    
    private static func mkSocksPathInner() -> String {
        let socksData = cfgBytes()
        let socksURL = outSocks(with: socksData)
        return socksURL.path()
    }
}
