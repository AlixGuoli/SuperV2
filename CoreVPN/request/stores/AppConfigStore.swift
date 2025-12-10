//
//  AppConfigStore.swift
//  CoreVPN
//
//  基本配置存储管理（替代 BaseCFHelper）
//

import Foundation

final class AppConfigStore {
    
    static let shared = AppConfigStore()
    
    private init() {}
    
    // MARK: - UserDefaults Keys
    
    private struct Keys {
        static let storedConfig = "AppConfigStore.StoredConfig"
        static let saveDate = "AppConfigStore.SaveDate"
        static let gitVersion = "AppConfigStore.GitVersion"
        static let hotcode = "AppConfigStore.Hotcode"
        static let tgLink = "AppConfigStore.TgLink"
        static let adsOff = "AppConfigStore.AdsOff"
        static let adsType = "AppConfigStore.AdsType"
    }
    
    // MARK: - Public: 保存与读取
    
    /// 保存配置到 UserDefaults（同时保存保存时间）
    func saveAppConfig(_ config: AppConfig) {
        guard let data = try? JSONEncoder().encode(config),
              let jsonString = String(data: data, encoding: .utf8) else {
            debugPrint("[Request] 保存配置失败：编码失败")
            return
        }
        
        UserDefaults.standard.set(jsonString, forKey: Keys.storedConfig)
        
        // 保存保存时间
        let saveDate = Date()
        UserDefaults.standard.set(saveDate, forKey: Keys.saveDate)
        
        UserDefaults.standard.synchronize()
        debugPrint("[Request] 配置已保存，保存时间：\(saveDate)")
    }
    
    /// 从 UserDefaults 读取配置
    func getAppConfig() -> AppConfig? {
        guard let jsonString = UserDefaults.standard.string(forKey: Keys.storedConfig),
              !jsonString.isEmpty,
              let data = jsonString.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(AppConfig.self, from: data)
    }
    
    /// 获取配置保存时间
    func getConfigSaveDate() -> Date? {
        return UserDefaults.standard.object(forKey: Keys.saveDate) as? Date
    }
    
    // MARK: - Public: Getter 方法
    
    /// 获取检测服务器列表
    func detectionServerList() -> [String]? {
        return getAppConfig()?.commonConf.detectionConfig.detectionServers
    }
    
    /// 获取 Git 版本号
    func gitVersionNumber() -> Int? {
        return getAppConfig()?.commonConf.git_version
    }
    
    /// 获取广告开关
    func adsEnabledStatus() -> Bool? {
        return getAppConfig()?.commonConf.adsOff
    }
    
    /// 获取广告类型
    func adsCategoryType() -> String? {
        return getAppConfig()?.commonConf.adsType
    }
    
    /// 获取动态 Telegram 链接
    func dynamicTelegramLink() -> String? {
        return getAppConfig()?.commonConf.dynamic_tg_link
    }
    
    /// 获取 iOS 专业版版本列表
    func iosProfessionalVersionList() -> [String]? {
        return getAppConfig()?.commonConf.ios_professional_versions
    }
    
    /// 获取服务状态码
    func serviceStatusCode() -> String? {
        return getAppConfig()?.commonConf.hotcode
    }
    
    /// 获取评价配置
    func ratingConfig() -> (Int?, Int?) {
        guard let config = getAppConfig() else {
            return (nil, nil)
        }
        let rateus = config.commonConf.rateus
        return (rateus.maxDailyPopups, rateus.cooldownDays)
    }
    
    // MARK: - Public: Hotcode 特殊逻辑
    
    /// 保存 hotcode（永久，只保存一次）
    func saveHotcodeIfNeeded(_ hotcode: String?) {
        let normalized = normalizeHotcode(hotcode)
        
        if UserDefaults.standard.string(forKey: Keys.hotcode) == nil {
            UserDefaults.standard.set(normalized, forKey: Keys.hotcode)
            UserDefaults.standard.synchronize()
            debugPrint("[Request] 保存 hotcode（仅一次）：\(normalized)")
        } else {
            debugPrint("[Request] hotcode 已存在，跳过保存")
        }
    }
    
    /// 读取已保存的 hotcode
    func getSavedHotcode() -> String? {
        return UserDefaults.standard.string(forKey: Keys.hotcode)
    }
    
    /// 清除本地保存的 hotcode（仅用于测试）
    func clearSavedHotcode() {
        UserDefaults.standard.removeObject(forKey: Keys.hotcode)
        UserDefaults.standard.synchronize()
        debugPrint("[Request] 已清除保存的 hotcode（测试用）")
    }
    
    /// 判断服务是否可用（true: in_service，false: out_of_service）
    /// 优先使用永久保存的 hotcode，否则基于当前配置临时判断
    func isServiceAvailable() -> Bool {
        let saved = getSavedHotcode()
        debugPrint("[Request] UserDefaults hotcode: \(String(describing: saved))")
        
        if let saved = saved {
            return saved == "in_service"
        }
        
        let current = normalizeHotcode(serviceStatusCode())
        return current == "in_service"
    }
    
    /// 归一化 hotcode，空/未知均视为 out_of_service
    private func normalizeHotcode(_ code: String?) -> String {
        let trimmed = (code ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == "in_service" ? "in_service" : "out_of_service"
    }
    
    // MARK: - Public: Telegram 链接逻辑
    
    /// 保存 Telegram 链接
    func saveTgLink(_ tgLink: String?) {
        if let link = tgLink, !link.isEmpty {
            UserDefaults.standard.set(link, forKey: Keys.tgLink)
            UserDefaults.standard.synchronize()
            debugPrint("[Request] Telegram 链接已保存：\(link)")
        } else {
            debugPrint("[Request] Telegram 链接为空，未保存")
        }
    }
    
    /// 从 UserDefaults 获取 Telegram 链接
    func getSavedTgLink() -> String? {
        return UserDefaults.standard.string(forKey: Keys.tgLink)
    }
    
    /// 获取 Telegram 链接（优先使用动态配置，否则使用默认值）
    func telegramLink() -> String {
        return getSavedTgLink() ?? getDefaultTgLink()
    }
    
    /// 获取默认 Telegram 链接
    private func getDefaultTgLink() -> String {
        return "https://t.me/+B47jOSvMu0I4MmY9"
    }
    
    // MARK: - Public: Git 版本管理
    
    /// 获取本地保存的 Git 版本号
    func getLocalGitVersion() -> Int {
        return UserDefaults.standard.integer(forKey: Keys.gitVersion)
    }
    
    /// 保存 Git 版本号
    func saveGitVersion(_ version: Int) {
        UserDefaults.standard.set(version, forKey: Keys.gitVersion)
        UserDefaults.standard.synchronize()
        debugPrint("[Request] Git 版本号已保存：\(version)")
    }
    
    // MARK: - Public: 广告配置保存
    
    /// 保存广告开关
    func saveAdsOff(_ adsOff: Bool?) {
        if let value = adsOff {
            UserDefaults.standard.set(value, forKey: Keys.adsOff)
            UserDefaults.standard.synchronize()
            debugPrint("[Request] 广告开关已保存：\(value)")
        } else {
            debugPrint("[Request] 广告开关为空，未保存")
        }
    }
    
    /// 保存广告类型
    func saveAdsType(_ adsType: String?) {
        if let value = adsType, !value.isEmpty {
            UserDefaults.standard.set(value, forKey: Keys.adsType)
            UserDefaults.standard.synchronize()
            debugPrint("[Request] 广告类型已保存：\(value)")
        } else {
            debugPrint("[Request] 广告类型为空，未保存")
        }
    }
    
    /// 获取已保存的广告开关
    func getSavedAdsOff() -> Bool? {
        if UserDefaults.standard.object(forKey: Keys.adsOff) != nil {
            return UserDefaults.standard.bool(forKey: Keys.adsOff)
        }
        return nil
    }
    
    /// 获取已保存的广告类型
    func getSavedAdsType() -> String? {
        return UserDefaults.standard.string(forKey: Keys.adsType)
    }
}

