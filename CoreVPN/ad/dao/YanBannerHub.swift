//
//  YanBannerCenter.swift
//  CoreVPN
//
//  Yandex Banner 广告管理
//

import Foundation
import UIKit
import YandexMobileAds

class YanBannerHub: NSObject {
    
    private var cachedBanner: AdView?
    private var adUnitList: [String] = []
    private var isLoading = false
    private var isReady = false
    private var adUnitIndex = 0
    private var loadStartAt: Date?
    
    var onAdReady: (() -> Void)?
    var onAdFailed: (() -> Void)?
    var onAdClicked: (() -> Void)?
    
    // MARK: - 广告配置和展示
    
    func initKeys() {
        adUnitList = YanBannerEnv.adUnits()
        if !adUnitList.isEmpty {
            debugPrint("[Ad-YanBanner] 获取到 keys: \(adUnitList.count) 个 | \(adUnitList)")
        } else {
            debugPrint("[Ad-YanBanner] 未找到 keys")
        }
    }
    
    func open(from viewController: UIViewController) {
        if available() {
            let adScreen = BannerBoard()
            adScreen.modalPresentationStyle = .fullScreen
            viewController.present(adScreen, animated: true)
        }
    }
    
    func available() -> Bool {
        return isReady && cachedBanner != nil
    }
    
    func getCurrentAd() -> AdView? {
        return available() ? cachedBanner : nil
    }
    
    func clearAd() {
        isReady = false
        cachedBanner = nil
        debugPrint("[Ad-YanBanner] 清空广告")
    }
    
    // MARK: - 广告加载管理
    
    func fetch() {
        debugPrint("[Ad-YanBanner] 开始加载")
        
        if canStartFetch() {
            initKeys()
            if !adUnitList.isEmpty {
                adUnitIndex = 0
                isLoading = true
                loadStartAt = Date()
                loadNext(index: adUnitIndex)
            } else {
                debugPrint("[Ad-YanBanner] ❌ 无可用 keys")
                onAdFailed?()
            }
        }
    }
    
    func refresh() {
        clearAd()
        fetch()
    }
    
    // MARK: - 私有方法
    
    private func loadNext(index: Int) {
        guard index < adUnitList.count else {
            debugPrint("[Ad-YanBanner] ❌ 所有 keys 加载失败")
            isLoading = false
            onAdFailed?()
            return
        }
        
        if let startTime = loadStartAt, Date().timeIntervalSince(startTime) > YanBannerEnv.timeout {
            debugPrint("[Ad-YanBanner] 加载超时 (100s)")
            isLoading = false
            onAdFailed?()
            return
        }
        
        let adKey = adUnitList[index]
        debugPrint("[Ad-YanBanner] 尝试加载 key[\(index)]: \(adKey)")
        
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        var safeAreaInsets = UIEdgeInsets.zero
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            safeAreaInsets = window.safeAreaInsets
        } else {
            debugPrint("[Ad-YanBanner] ⚠️ 获取 safe area 失败")
        }
        
        let adjustedHeight = screenHeight - safeAreaInsets.top - safeAreaInsets.bottom
        let bannerSize = BannerAdSize.inlineSize(withWidth: screenWidth, maxHeight: adjustedHeight)
        
        cachedBanner = AdView(adUnitID: adKey, adSize: bannerSize)
        cachedBanner?.delegate = self
        cachedBanner?.translatesAutoresizingMaskIntoConstraints = false
        cachedBanner?.loadAd()
    }
    
    private func canStartFetch() -> Bool {
        if isReady { return false }
        if isLoading {
            guard let startTime = loadStartAt,
                  Date().timeIntervalSince(startTime) > YanBannerEnv.timeout else {
                return false
            }
            return true
        }
        return true
    }
    
    private func loadNextAd() {
        adUnitIndex += 1
        if adUnitIndex < adUnitList.count {
            loadNext(index: adUnitIndex)
        } else {
            debugPrint("[Ad-YanBanner] ❌ 所有 keys 加载失败")
            isLoading = false
            onAdFailed?()
        }
    }
}

// MARK: - 外部依赖封装
private enum YanBannerEnv {
    static func adUnits() -> [String] {
        AdsConfigStore.shared.bannerKey()
            .components(separatedBy: ";")
            .filter { !$0.isEmpty }
    }
    
    static var timeout: TimeInterval { 100 }
}

// MARK: - Yandex Banner Delegate

extension YanBannerHub: AdViewDelegate {
    
    func adViewDidLoad(_ adView: AdView) {
        debugPrint("[Ad-YanBanner] ✅ 加载成功 | key: \(adView.adUnitID)")
        isLoading = false
        isReady = true
        onAdReady?()
    }
    
    func adViewDidFailLoading(_ adView: AdView, error: Error) {
        debugPrint("[Ad-YanBanner] ❌ 加载失败 | key: \(adView.adUnitID) | error: \(error.localizedDescription)")
        loadNextAd()
    }
    
    func adViewDidClick(_ adView: AdView) {
        debugPrint("[Ad-YanBanner] 用户点击广告")
        onAdClicked?()
    }
}

