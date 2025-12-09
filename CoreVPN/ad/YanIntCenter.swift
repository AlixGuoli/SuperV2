//
//  YanIntCenter.swift
//  CoreVPN
//
//  Yandex 插屏广告管理
//

import Foundation
import UIKit
import YandexMobileAds

class YanIntCenter: NSObject {
    
    private var activeAd: InterstitialAd?
    private var displayingAd: InterstitialAd?
    private var keyPool: [String] = []
    private var fetching = false
    private var loadStartTime: Date?
    private var keyPos = 0
    
    var onAdReady: (() -> Void)?
    var onAdFailed: (() -> Void)?
    var onAdClicked: (() -> Void)?
    var onAdClosed: (() -> Void)?
    
    private lazy var adLoader: InterstitialAdLoader = {
        let loader = InterstitialAdLoader()
        loader.delegate = self
        return loader
    }()
    
    // MARK: - 广告配置和展示
    
    func initKeys() {
        let yandexIntKey = AdsConfigStore.shared.intKey()
        if !yandexIntKey.isEmpty {
            self.keyPool = yandexIntKey.components(separatedBy: ";").filter { !$0.isEmpty }
            debugPrint("[Ad-YanInt] 获取到 keys: \(keyPool.count) 个 | \(keyPool)")
        } else {
            self.keyPool = []
            debugPrint("[Ad-YanInt] 未找到 keys")
        }
    }
    
    func open(from viewController: UIViewController, moment: String?) {
        guard let activeAd = activeAd else {
            onAdClosed?()
            return
        }
        
        let adKeyId = activeAd.adInfo?.adUnitId ?? ""
        activeAd.show(from: viewController)
    }
    
    func available() -> Bool {
        return activeAd != nil
    }
    
    func getCurrentAd() -> InterstitialAd? {
        return available() ? activeAd : nil
    }
    
    func clearAd() {
        activeAd = nil
        debugPrint("[Ad-YanInt] 清空广告")
    }
    
    // MARK: - 广告加载管理
    
    func fetch(moment: String? = nil) {
        debugPrint("[Ad-YanInt] 开始加载 | 连接状态: \(AppGlobalStatus.shared.connectStatus)")
        
        if canStartFetch() {
            initKeys()
            keyPos = 0
            guard keyPool.count > keyPos else { return }
            
            debugPrint("[Ad-YanInt] 启动加载流程")
            fetching = true
            loadStartTime = Date()
            
            Task {
                await loadNext(index: 0, moment: moment)
            }
        }
    }
    
    func reload(moment: String? = nil) {
        clearAd()
        fetch(moment: moment)
    }
    
    // MARK: - 私有方法
    
    private func loadNext(index: Int, moment: String? = nil) async {
        guard index < keyPool.count else {
            handleLoadFailure()
            return
        }
        
        if let startTime = loadStartTime, Date().timeIntervalSince(startTime) > 100 {
            debugPrint("[Ad-YanInt] 加载超时 (100s)")
            fetching = false
            handleLoadFailure()
            return
        }
        
        let adKey = keyPool[index]
        debugPrint("[Ad-YanInt] 尝试加载 key[\(index)]: \(adKey)")
        
        let config = AdRequestConfiguration(adUnitID: adKey)
        adLoader.loadAd(with: config)
    }
    
    private func canStartFetch() -> Bool {
        if available() { return false }
        if fetching {
            guard let startTime = loadStartTime else { return false }
            let elapsedTime = Date().timeIntervalSince(startTime)
            return elapsedTime > 100
        }
        return true
    }
    
    private func handleLoadFailure() {
        fetching = false
        onAdFailed?()
    }
    
    private func loadNextAd() {
        keyPos += 1
        if keyPos < keyPool.count {
            Task {
                await loadNext(index: keyPos)
            }
        } else {
            handleLoadFailure()
        }
    }
}

// MARK: - Yandex Delegate

extension YanIntCenter: InterstitialAdLoaderDelegate, InterstitialAdDelegate {
    
    func interstitialAdLoader(_ adLoader: InterstitialAdLoader, didLoad interstitialAd: InterstitialAd) {
        debugPrint("[Ad-YanInt] ✅ 加载成功 | key: \(interstitialAd.adInfo?.adUnitId ?? "")")
        fetching = false
        activeAd = interstitialAd
        activeAd?.delegate = self
        onAdReady?()
    }
    
    func interstitialAdLoader(_ adLoader: InterstitialAdLoader, didFailToLoadWithError error: AdRequestError) {
        debugPrint("[Ad-YanInt] ❌ 加载失败 | key: \(error.adUnitId ?? "") | error: \(error.error.localizedDescription)")
        loadNextAd()
    }
    
    func interstitialAd(_ interstitialAd: InterstitialAd, didFailToShowWithError error: Error) {
        debugPrint("[Ad-YanInt] ❌ 展示失败 | error: \(error.localizedDescription)")
        reload()
    }
    
    func interstitialAdDidShow(_ interstitialAd: InterstitialAd) {
        AdCenter.shared.isShowingAd = true
        debugPrint("[Ad-YanInt] 广告已展示 | key: \(interstitialAd.adInfo?.adUnitId ?? "")")
    }
    
    func interstitialAdDidDismiss(_ interstitialAd: InterstitialAd) {
        onAdClosed?()
        reload()
        AdCenter.shared.isShowingAd = false
    }
    
    func interstitialAdDidClick(_ interstitialAd: InterstitialAd) {
        onAdClicked?()
    }
    
    func interstitialAd(_ interstitialAd: InterstitialAd, didTrackImpressionWith impressionData: ImpressionData?) {
        // Handle impression tracking if needed
    }
}

