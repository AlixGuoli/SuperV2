//
//  YanEMSlotHub.swift
//  CoreVPN
//
//  Yandex EM 插屏广告管理
//

import Foundation
import UIKit
import YandexMobileAds

class YanEMSlotHub: NSObject {
    
    private var cachedAd: InterstitialAd?
    private var showingAd: InterstitialAd?
    private var adUnitList: [String] = []
    private var isLoading = false
    private var loadStartAt: Date?
    private var adUnitIndex = 0
    
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
        adUnitList = YanEMEnv.adUnits()
        if !adUnitList.isEmpty {
            debugPrint("[Ad-YanEMInt] 获取到 keys: \(adUnitList.count) 个 | \(adUnitList)")
        } else {
            debugPrint("[Ad-YanEMInt] 未找到 keys")
        }
    }
    
    func open(from viewController: UIViewController, moment: String?) {
        guard let activeAd = cachedAd else {
            onAdClosed?()
            return
        }
        
        let adKeyId = activeAd.adInfo?.adUnitId ?? ""
        activeAd.show(from: viewController)
    }
    
    func available() -> Bool {
        return cachedAd != nil
    }
    
    func getCurrentAd() -> InterstitialAd? {
        return available() ? cachedAd : nil
    }
    
    func clearAd() {
        cachedAd = nil
        debugPrint("[Ad-YanEMInt] 清空广告")
    }
    
    // MARK: - 广告加载管理
    
    func fetch(moment: String? = nil) {
        debugPrint("[Ad-YanEMInt] 开始加载 | 连接状态: \(YanEMEnv.connState())")
        
        if canStartFetch() {
            initKeys()
            adUnitIndex = 0
            guard adUnitList.count > adUnitIndex else { return }
            
            debugPrint("[Ad-YanEMInt] 启动加载流程")
            isLoading = true
            loadStartAt = Date()
            
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
        guard index < adUnitList.count else {
            handleLoadFailure()
            return
        }
        
        if let startTime = loadStartAt, Date().timeIntervalSince(startTime) > YanEMEnv.timeout {
            debugPrint("[Ad-YanEMInt] 加载超时 (100s)")
            isLoading = false
            handleLoadFailure()
            return
        }
        
        let adKey = adUnitList[index]
        debugPrint("[Ad-YanEMInt] 尝试加载 key[\(index)]: \(adKey)")
        
        let config = AdRequestConfiguration(adUnitID: adKey)
        adLoader.loadAd(with: config)
    }
    
    private func canStartFetch() -> Bool {
        if available() { return false }
        if isLoading {
            guard let startTime = loadStartAt else { return false }
            let elapsedTime = Date().timeIntervalSince(startTime)
            return elapsedTime > YanEMEnv.timeout
        }
        return true
    }
    
    private func handleLoadFailure() {
        isLoading = false
        onAdFailed?()
    }
    
    private func loadNextAd() {
        adUnitIndex += 1
        if adUnitIndex < adUnitList.count {
            Task {
                await loadNext(index: adUnitIndex)
            }
        } else {
            handleLoadFailure()
        }
    }
}

// MARK: - 外部依赖封装
private enum YanEMEnv {
    static func adUnits() -> [String] {
        AdsConfigStore.shared.emIntKey()
            .components(separatedBy: ";")
            .filter { !$0.isEmpty }
    }
    
    static func connState() -> TunnelState {
        AppGlobalStatus.shared.connectStatus
    }
    
    static var isShowing: Bool {
        get { AdHub.shared.showFlag }
        set { AdHub.shared.showFlag = newValue }
    }
    
    static var timeout: TimeInterval { 100 }
}

// MARK: - Yandex Delegate

extension YanEMSlotHub: InterstitialAdLoaderDelegate, InterstitialAdDelegate {
    
    func interstitialAdLoader(_ adLoader: InterstitialAdLoader, didLoad interstitialAd: InterstitialAd) {
        debugPrint("[Ad-YanEMInt] ✅ 加载成功 | key: \(interstitialAd.adInfo?.adUnitId ?? "")")
        isLoading = false
        cachedAd = interstitialAd
        cachedAd?.delegate = self
        onAdReady?()
    }
    
    func interstitialAdLoader(_ adLoader: InterstitialAdLoader, didFailToLoadWithError error: AdRequestError) {
        debugPrint("[Ad-YanEMInt] ❌ 加载失败 | key: \(error.adUnitId ?? "") | error: \(error.error.localizedDescription)")
        loadNextAd()
    }
    
    func interstitialAd(_ interstitialAd: InterstitialAd, didFailToShowWithError error: Error) {
        debugPrint("[Ad-YanEMInt] ❌ 展示失败 | error: \(error.localizedDescription)")
        reload()
    }
    
    func interstitialAdDidShow(_ interstitialAd: InterstitialAd) {
        YanEMEnv.isShowing = true
        debugPrint("[Ad-YanEMInt] 广告已展示 | key: \(interstitialAd.adInfo?.adUnitId ?? "")")
    }
    
    func interstitialAdDidDismiss(_ interstitialAd: InterstitialAd) {
        onAdClosed?()
        reload()
        YanEMEnv.isShowing = false
    }
    
    func interstitialAdDidClick(_ interstitialAd: InterstitialAd) {
        onAdClicked?()
    }
    
    func interstitialAd(_ interstitialAd: InterstitialAd, didTrackImpressionWith impressionData: ImpressionData?) {
        // Handle impression tracking if needed
    }
}
