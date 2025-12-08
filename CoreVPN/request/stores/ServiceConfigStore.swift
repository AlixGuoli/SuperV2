//
//  ServiceConfigStore.swift
//  CoreVPN
//
//  服务配置存储管理
//

import Foundation

final class ServiceConfigStore {
    
    static let shared = ServiceConfigStore()
    
    private init() {}
    
    // MARK: - UserDefaults Keys
    
    private struct Keys {
        static let serviceConfig = "ServiceConfigStore.ServiceConfig"
        static let saveDate = "ServiceConfigStore.SaveDate"
    }
    
    // MARK: - 内存状态（不持久化）
    
    /// 当前服务配置（加密字符串，内存中）
    var nowServiceCF: String? = nil
    
    /// 解析出的 IP 地址（内存中）
    var ipService: String? = nil
    
    /// 配置来源标识（true=接口请求，false=UserDefaults）
    var isFromRequest: Bool = true
    
    // MARK: - Public: 保存与读取
    
    /// 保存服务配置（加密字符串）
    func saveServiceConfig(_ config: String) {
        guard !config.isEmpty else {
            debugPrint("[Request] 服务配置为空，未保存")
            return
        }
        
        // 保存到内存
        nowServiceCF = config
        
        // 保存到 UserDefaults
        UserDefaults.standard.set(config, forKey: Keys.serviceConfig)
        
        // 保存保存时间
        let saveDate = Date()
        UserDefaults.standard.set(saveDate, forKey: Keys.saveDate)
        
        UserDefaults.standard.synchronize()
        debugPrint("[Request] 服务配置已保存，保存时间：\(saveDate)")
    }
    
    /// 从 UserDefaults 读取服务配置（加密字符串）
    func getServiceConfig() -> String? {
        guard let config = UserDefaults.standard.string(forKey: Keys.serviceConfig),
              !config.isEmpty else {
            debugPrint("[Request] UserDefaults 服务配置为空")
            return nil
        }
        return config
    }
    
    /// 获取配置保存时间
    func getConfigSaveDate() -> Date? {
        return UserDefaults.standard.object(forKey: Keys.saveDate) as? Date
    }
    
    /// 清除保存的服务配置（仅用于测试）
    func clearServiceConfig() {
        UserDefaults.standard.removeObject(forKey: Keys.serviceConfig)
        UserDefaults.standard.removeObject(forKey: Keys.saveDate)
        UserDefaults.standard.synchronize()
        // 清除内存状态
        nowServiceCF = nil
        ipService = nil
        isFromRequest = true
        debugPrint("[Request] 已清除保存的服务配置（测试用）")
    }
    
    // MARK: - 配置解析
    
    /// 解析网络配置，提取 IP 地址
    /// - Parameters:
    ///   - input: 解密后的 JSON 字符串
    ///   - isValid: 是否来自接口请求（true=接口请求，false=UserDefaults）
    func scanCfg(input: String?, isValid: Bool) {
        guard let data = input?.data(using: .utf8) else {
            debugPrint("[Request] 解析网络配置失败：输入数据为空")
            return
        }
        
        do {
            let obj = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any]
            let bds = obj?["outbounds"] as? [[String: Any]]
            
            bds?.forEach { bd in
                let cfg = bd["settings"] as? [String: Any]
                let nds = cfg?["vnext"] as? [[String: Any]]
                
                nds?.forEach { nd in
                    if let ipVal = nd["address"] as? String {
                        let ipOut = isValid ? ipVal : "f\(ipVal)"
                        self.ipService = ipOut
                        debugPrint("[Request] 解析网络配置成功，提取 IP：\(ipOut)，来源：\(isValid ? "接口请求" : "UserDefaults")")
                    }
                }
            }
        } catch {
            debugPrint("[Request] 解析网络配置失败：\(error.localizedDescription)")
        }
    }
    
}
