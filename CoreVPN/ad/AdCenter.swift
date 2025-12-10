//
//  AdCenter.swift
//  CoreVPN
//
//  广告中心（统一入口 + 配置管理）
//

import Foundation
import UIKit
import YandexMobileAds

class AdCenter {
    
    static var shared = AdCenter()
    
    let admobCenter = AdmobCenter()
    let yanIntCenter = YanIntCenter()
    let yanBannerCenter = YanBannerCenter()
    
    var isShowingAd = false
    var isVip = false
    
    private var isAdsOpen: Bool {
        /// 测试服 关闭广告
        //return false
        
        if isVip {
            debugPrint("[Ad-Center] 广告关闭 | 原因: VIP用户")
            return false
        }
        
        let isAdsOff = AppConfigStore.shared.getSavedAdsOff() ?? false
        let adType = AppConfigStore.shared.getSavedAdsType()?.components(separatedBy: ";") ?? []
        
//        debugPrint("[Ad-Center] 广告开关: \(isAdsOff ? "关闭" : "开启")")
//        debugPrint("[Ad-Center] 广告类型: \(adType)")
        
        return !isAdsOff
    }
    
    private var isYandexOpen: Bool {
        let adType = AppConfigStore.shared.getSavedAdsType()?.components(separatedBy: ";") ?? []
        if adType.contains("y") {
            return true
        }
        debugPrint("[Ad-Center] Yandex 关闭")
        return false
    }
    
    private var isAdmobOpen: Bool {
        let adType = AppConfigStore.shared.getSavedAdsType()?.components(separatedBy: ";") ?? []
        if adType.contains("a") {
            if AppGlobalStatus.shared.connectStatus == .connected {
                return true
            }
        }
        debugPrint("[Ad-Center] Admob 关闭 | 原因: 未连接或类型不匹配")
        return false
    }
    
    private init() {
        isVip = UserPrefs.isPremium
    }
    
    // MARK: - 状态检查方法
    
    func checkBannerStatus() -> Bool {
        return yanBannerCenter.available()
    }
    
    func checkIntStatus() -> Bool {
        return yanIntCenter.available()
    }
    
    func checkAdmobStatus() -> Bool {
        if AppGlobalStatus.shared.connectStatus == .connected {
            return admobCenter.available()
        } else {
            admobCenter.clearAd()
            return false
        }
    }
    
    func checkYandexAvailability() -> Bool {
        guard isAdsOpen else { return false }
        return checkBannerStatus() || checkIntStatus()
    }
    
    func checkOverallAvailability() -> Bool {
        guard isAdsOpen else { return false }
        return checkYandexAvailability() || checkAdmobStatus()
    }
    
    // MARK: - 广告加载管理
    
    func loadAllAdvertisements(moment: String? = nil) {
        debugPrint("[Ad-Center] 加载所有广告 | moment: \(moment ?? "nil")")
        
        guard isAdsOpen else {
            debugPrint("[Ad-Center] 广告已禁用，跳过加载")
            return
        }
        
        if isYandexOpen {
            yanBannerCenter.fetch()
            yanIntCenter.fetch()
        }
        
        if isAdmobOpen {
            admobCenter.fetch(moment: moment)
        }
    }
    
    func loadBannerAd(onAdReady: (() -> Void)? = nil, onAdFailed: (() -> Void)? = nil) {
        debugPrint("[Ad-Center] 加载 Yandex Banner")
        
        if isAdsOpen && isYandexOpen {
            if checkBannerStatus() {
                onAdReady?()
            } else {
                yanBannerCenter.onAdReady = onAdReady
                yanBannerCenter.onAdFailed = onAdFailed
                yanBannerCenter.fetch()
            }
        } else {
            onAdReady?()
        }
    }
    
    func loadIntAd(onAdReady: (() -> Void)? = nil, onAdFailed: (() -> Void)? = nil) {
        debugPrint("[Ad-Center] 加载 Yandex Int")
        
        if isAdsOpen && isYandexOpen {
            if checkIntStatus() {
                onAdReady?()
            } else {
                yanIntCenter.onAdReady = onAdReady
                yanIntCenter.onAdFailed = onAdFailed
                yanIntCenter.fetch()
            }
        } else {
            onAdReady?()
        }
    }
    
    func loadAdmobAd(moment: String? = nil, onAdReady: (() -> Void)? = nil, onAdFailed: (() -> Void)? = nil) {
        debugPrint("[Ad-Center] 加载 Admob Int")
        
        if isAdsOpen && isAdmobOpen {
            admobCenter.onAdReady = onAdReady
            admobCenter.onAdFailed = onAdFailed
            admobCenter.fetch(moment: moment)
        } else {
            onAdReady?()
        }
    }
    
    // MARK: - 展示方法（委托给 AdShow）
    
    func showYanInt(from viewController: UIViewController, onClose: (() -> Void)? = nil) {
        AdShow.shared.displayYandexInt(from: viewController, onClose: onClose)
    }
    
    func showYanBanner(from viewController: UIViewController) {
        AdShow.shared.displayYandexBanner(from: viewController)
    }
    
    func showAdmobInt(from viewController: UIViewController, moment: String?) {
        AdShow.shared.displayAdmobInt(from: viewController, moment: moment)
    }
    
    // MARK: - 便捷展示方法
    
    func showYanBannerFromRoot() {
        AdShow.shared.displayAdFromRoot(type: .yandexBanner)
    }
    
    func showYanIntFromRoot(onClose: (() -> Void)? = nil) {
        AdShow.shared.displayAdFromRoot(type: .yandexInt, onClose: onClose)
    }
    
    func showAdmobIntFromRoot(moment: String?) {
        AdShow.shared.displayAdFromRoot(type: .admobInt, moment: moment)
    }
    
    // MARK: - 获取方法
    
    func getYanBannerAd() -> AdView? {
        return AdShow.shared.getCurrentBannerAd()
    }
}

