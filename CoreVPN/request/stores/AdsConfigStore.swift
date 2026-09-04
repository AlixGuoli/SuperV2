//
//  AdsConfigStore.swift
//  CoreVPN
//
//  广告配置存储管理（替代 AdCFHelper）
//

import Foundation

final class AdsConfigStore {
    
    static let shared = AdsConfigStore()
    
    private init() {}
    
    // MARK: - UserDefaults Keys
    
    private struct Keys {
        static let yandexIntKey = "AdsConfigStore.YandexIntKey"
        static let yandexEMIntKey = "AdsConfigStore.YandexEMIntKey"
        static let saveDate = "AdsConfigStore.SaveDate"
    }
    
    // MARK: - Public: Getter 方法（带默认值）
    
    /// 获取 Yandex Int Key
    func intKey() -> String {
        /// 测试服
        //return "demo-interstitial-yandex"
        //return "cc;demo-interstitial-yandex"
        return UserDefaults.standard.string(forKey: Keys.yandexIntKey) ?? ""
    }
    
    /// 获取 Yandex EM Int Key
    func emIntKey() -> String {
        /// 测试服
        //return "R-M-18478236-1"
        return UserDefaults.standard.string(forKey: Keys.yandexEMIntKey) ?? "R-M-18478236-1"
    }
    
    /// 获取配置保存时间
    func saveTimestamp() -> Date? {
        return UserDefaults.standard.object(forKey: Keys.saveDate) as? Date
    }
    
    // MARK: - Public: 保存方法
    
    /// 保存 Yandex Int Key
    func saveYandexIntKey(_ key: String?) {
        if let key = key, !key.isEmpty {
            UserDefaults.standard.set(key, forKey: Keys.yandexIntKey)
            UserDefaults.standard.synchronize()
            debugPrint("[Request] Yandex Int Key 已保存：\(key)")
        }
    }
    
    /// 保存 Yandex EM Int Key
    func saveYandexEMIntKey(_ key: String?) {
        if let key = key, !key.isEmpty {
            UserDefaults.standard.set(key, forKey: Keys.yandexEMIntKey)
            UserDefaults.standard.synchronize()
            debugPrint("[Request] Yandex EM Int Key 已保存：\(key)")
        }
    }
    
    /// 保存配置时间
    func saveConfigDate() {
        let saveDate = Date()
        UserDefaults.standard.set(saveDate, forKey: Keys.saveDate)
        UserDefaults.standard.synchronize()
        debugPrint("[Request] 广告配置保存时间：\(saveDate)")
    }
    
    // MARK: - Public: 提取配置方法
    
    /// 从 adMixed 数组中提取 Yandex Int 配置
    func extractYandexIntConfig(from adMixed: [AdMixedItem]) -> String? {
        for item in adMixed {
            if item.name == "Yandex_Int_List" {
                return item.key.isEmpty ? nil : item.key
            }
        }
        return nil
    }
    
    /// 从 adMixed 数组中提取 Yandex EM Int 配置
    func extractYandexEMIntConfig(from adMixed: [AdMixedItem]) -> String? {
        for item in adMixed {
            if item.name == "Yandex_EMInt_List" {
                return item.key.isEmpty ? nil : item.key
            }
        }
        return nil
    }
}
