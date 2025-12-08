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
    
    // MARK: - Public: 保存与读取
    
    /// 保存服务配置（加密字符串）
    func saveServiceConfig(_ config: String) {
        guard !config.isEmpty else {
            debugPrint("[Request] 服务配置为空，未保存")
            return
        }
        
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
        debugPrint("[Request] 已清除保存的服务配置（测试用）")
    }
}

