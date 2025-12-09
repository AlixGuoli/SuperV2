//
//  YanBannerCenter.swift
//  CoreVPN
//
//  Yandex Banner 广告管理
//

import Foundation
import UIKit
import YandexMobileAds

class YanBannerCenter: NSObject {
    
    private var bannerView: AdView?
    private var keyPool: [String] = []
    private var fetching = false
    private var isAdReady = false
    private var keyPos = 0
    private var loadStartTime: Date?
    
    var onAdReady: (() -> Void)?
    var onAdFailed: (() -> Void)?
    var onAdClicked: (() -> Void)?
    
    // MARK: - 广告配置和展示
    
    func initKeys() {
        let yandexBannerKey = AdsConfigStore.shared.bannerKey()
        if !yandexBannerKey.isEmpty {
            self.keyPool = yandexBannerKey.components(separatedBy: ";").filter { !$0.isEmpty }
            debugPrint("[Ad-YanBanner] 获取到 keys: \(keyPool.count) 个 | \(keyPool)")
        } else {
            self.keyPool = []
            debugPrint("[Ad-YanBanner] 未找到 keys")
        }
    }
    
    func open(from viewController: UIViewController) {
        if available() {
            let adScreen = BannerScreen()
            adScreen.modalPresentationStyle = .fullScreen
            viewController.present(adScreen, animated: true)
        }
    }
    
    func available() -> Bool {
        return isAdReady && bannerView != nil
    }
    
    func getCurrentAd() -> AdView? {
        return available() ? bannerView : nil
    }
    
    func clearAd() {
        isAdReady = false
        bannerView = nil
        debugPrint("[Ad-YanBanner] 清空广告")
    }
    
    // MARK: - 广告加载管理
    
    func fetch() {
        debugPrint("[Ad-YanBanner] 开始加载")
        
        if canStartFetch() {
            initKeys()
            if !keyPool.isEmpty {
                keyPos = 0
                fetching = true
                loadStartTime = Date()
                loadNext(index: keyPos)
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
        guard index < keyPool.count else {
            debugPrint("[Ad-YanBanner] ❌ 所有 keys 加载失败")
            fetching = false
            onAdFailed?()
            return
        }
        
        if let startTime = loadStartTime, Date().timeIntervalSince(startTime) > 100 {
            debugPrint("[Ad-YanBanner] 加载超时 (100s)")
            fetching = false
            onAdFailed?()
            return
        }
        
        let adKey = keyPool[index]
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
        
        bannerView = AdView(adUnitID: adKey, adSize: bannerSize)
        bannerView?.delegate = self
        bannerView?.translatesAutoresizingMaskIntoConstraints = false
        bannerView?.loadAd()
    }
    
    private func canStartFetch() -> Bool {
        if isAdReady { return false }
        if fetching {
            guard let startTime = loadStartTime,
                  Date().timeIntervalSince(startTime) > 100 else {
                return false
            }
            return true
        }
        return true
    }
    
    private func loadNextAd() {
        keyPos += 1
        if keyPos < keyPool.count {
            loadNext(index: keyPos)
        } else {
            debugPrint("[Ad-YanBanner] ❌ 所有 keys 加载失败")
            fetching = false
            onAdFailed?()
        }
    }
}

// MARK: - Yandex Banner Delegate

extension YanBannerCenter: AdViewDelegate {
    
    func adViewDidLoad(_ adView: AdView) {
        debugPrint("[Ad-YanBanner] ✅ 加载成功 | key: \(adView.adUnitID)")
        fetching = false
        isAdReady = true
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

