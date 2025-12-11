//
//  AdsConfigStore.swift
//  CoreVPN
//
//  广告配置存储管理（替代 AdCFHelper）
//

import Foundation

final class AdsConfigStore {
    
    static let shared = AdsConfigStore()
    
    private init() {
        initializeDefaultValues()
    }
    
    // MARK: - UserDefaults Keys
    
    private struct Keys {
        static let yandexBannerKey = "AdsConfigStore.YandexBannerKey"
        static let yandexIntKey = "AdsConfigStore.YandexIntKey"
        static let admobIntKey = "AdsConfigStore.AdmobIntKey"
        static let penetrate = "AdsConfigStore.Penetrate"
        static let clickDelay = "AdsConfigStore.ClickDelay"
        static let saveDate = "AdsConfigStore.SaveDate"
        static let skipButtonConfig = "AdsConfigStore.SkipButtonConfig"
    }
    
    // MARK: - Public: Getter 方法（带默认值）
    
    /// 获取 Yandex Banner Key
    func bannerKey() -> String {
        /// 测试服
        return "demo-banner-yandex"
        return "aaa;bbb;demo-banner-yandex"
        return UserDefaults.standard.string(forKey: Keys.yandexBannerKey) ?? "R-M-17936270-1;R-M-17936270-2"
    }
    
    /// 获取 Yandex Int Key
    func intKey() -> String {
        /// 测试服
        return "demo-interstitial-yandex"
        return "cc;demo-interstitial-yandex"
        return UserDefaults.standard.string(forKey: Keys.yandexIntKey) ?? "R-M-17936270-3"
    }
    
    /// 获取 AdMob Int Key
    func admobKey() -> String {
        /// 测试服
        return "ca-app-pub-3940256099942544/4411468910"
        return "dddd;ca-app-pub-3940256099942544/4411468910"
        return UserDefaults.standard.string(forKey: Keys.admobIntKey) ?? "ca-app-pub-4769248627863594/3749236375"
    }
    
    /// 获取穿透比例
    func penetrationRate() -> Int {
        return UserDefaults.standard.integer(forKey: Keys.penetrate)
    }
    
    /// 获取点击延迟
    func clickDelay() -> Int {
        return UserDefaults.standard.integer(forKey: Keys.clickDelay)
    }
    
    /// 获取配置保存时间
    func saveTimestamp() -> Date? {
        return UserDefaults.standard.object(forKey: Keys.saveDate) as? Date
    }
    
    /// 获取跳过按钮配置（返回默认值如果不存在）
    func skipButtonConfig() -> AdsSkipConfig {
        guard let data = UserDefaults.standard.data(forKey: Keys.skipButtonConfig),
              let config = try? JSONDecoder().decode(AdsSkipConfig.self, from: data) else {
            return AdsSkipConfig.default
        }
        return config
    }
    
    // MARK: - Public: 保存方法
    
    /// 保存 Yandex Banner Key
    func saveYandexBannerKey(_ key: String?) {
        if let key = key, !key.isEmpty {
            UserDefaults.standard.set(key, forKey: Keys.yandexBannerKey)
            UserDefaults.standard.synchronize()
            debugPrint("[Request] Yandex Banner Key 已保存：\(key)")
        }
    }
    
    /// 保存 Yandex Int Key
    func saveYandexIntKey(_ key: String?) {
        if let key = key, !key.isEmpty {
            UserDefaults.standard.set(key, forKey: Keys.yandexIntKey)
            UserDefaults.standard.synchronize()
            debugPrint("[Request] Yandex Int Key 已保存：\(key)")
        }
    }
    
    /// 保存 AdMob Int Key
    func saveAdmobIntKey(_ key: String?) {
        if let key = key, !key.isEmpty {
            UserDefaults.standard.set(key, forKey: Keys.admobIntKey)
            UserDefaults.standard.synchronize()
            debugPrint("[Request] AdMob Int Key 已保存：\(key)")
        }
    }
    
    /// 保存穿透设置
    func savePenetrateSettings(penetrate: Int?, clickDelay: Int?) {
        if let penetrate = penetrate {
            UserDefaults.standard.set(penetrate, forKey: Keys.penetrate)
            debugPrint("[Request] 穿透比例已保存：\(penetrate)")
        }
        
        if let clickDelay = clickDelay {
            UserDefaults.standard.set(clickDelay, forKey: Keys.clickDelay)
            debugPrint("[Request] 点击延迟已保存：\(clickDelay)")
        }
        
        UserDefaults.standard.synchronize()
    }
    
    /// 保存配置时间
    func saveConfigDate() {
        let saveDate = Date()
        UserDefaults.standard.set(saveDate, forKey: Keys.saveDate)
        UserDefaults.standard.synchronize()
        debugPrint("[Request] 广告配置保存时间：\(saveDate)")
    }
    
    /// 保存跳过按钮配置
    func saveSkipButtonConfig(_ config: AdsSkipConfig) {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: Keys.skipButtonConfig)
            UserDefaults.standard.synchronize()
            debugPrint("[Request] 跳过按钮配置已保存：location=\(config.location), x=\(config.x), y=\(config.y)")
        }
    }
    
    // MARK: - Private: 初始化默认值
    
    /// 初始化默认值（只在第一次调用）
    private func initializeDefaultValues() {
        // 检查是否已经初始化过
        if UserDefaults.standard.object(forKey: Keys.penetrate) == nil {
            UserDefaults.standard.set(100, forKey: Keys.penetrate)
            debugPrint("[Request] 初始化默认穿透比例：100")
        }
        
        if UserDefaults.standard.object(forKey: Keys.clickDelay) == nil {
            UserDefaults.standard.set(15, forKey: Keys.clickDelay)
            debugPrint("[Request] 初始化默认点击延迟：15")
        }
        
        UserDefaults.standard.synchronize()
    }
    
    // MARK: - Public: 提取配置方法
    
    /// 从 adMixed 数组中提取 Yandex Banner 配置
    func extractYandexBannerConfig(from adMixed: [AdMixedItem]) -> (key: String?, penetrate: Int?, clickDelay: Int?)? {
        for item in adMixed {
            if item.name == "Yandex_Banner_List" {
                let key = item.key.isEmpty ? nil : item.key
                return (key, item.penetrate, item.clickDelayPenet)
            }
        }
        return nil
    }
    
    /// 从 adMixed 数组中提取 Yandex Int 配置
    func extractYandexIntConfig(from adMixed: [AdMixedItem]) -> String? {
        for item in adMixed {
            if item.name == "Yandex_Int_List" {
                return item.key.isEmpty ? nil : item.key
            }
        }
        return nil
    }
    
    /// 从 adMixed 数组中提取 AdMob Int 配置
    func extractAdmobIntConfig(from adMixed: [AdMixedItem]) -> String? {
        for item in adMixed {
            if item.name == "Admob_Int_List" {
                return item.key.isEmpty ? nil : item.key
            }
        }
        return nil
    }
}

