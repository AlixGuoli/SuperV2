//
//  AdShow.swift
//  CoreVPN
//
//  广告展示管理
//

import Foundation
import UIKit
import YandexMobileAds

// 广告类型枚举
enum AdType {
    case yandexBanner
    case yandexInt
    case admobInt
}

class AdShow {
    
    static let shared = AdShow()
    
    private init() {}
    
    // MARK: - 基础展示方法
    
    func displayYandexInt(from viewController: UIViewController, onClose: (() -> Void)? = nil) {
        AdCenter.shared.yanIntCenter.onAdClosed = onClose
        AdCenter.shared.yanIntCenter.open(from: viewController, moment: nil)
    }
    
    func displayYandexBanner(from viewController: UIViewController) {
        AdCenter.shared.yanBannerCenter.open(from: viewController)
    }
    
    func displayAdmobInt(from viewController: UIViewController, moment: String?) {
        AdCenter.shared.admobCenter.open(from: viewController, moment: moment)
    }
    
    // MARK: - 便捷展示方法（合并为一个）
    
    func displayAdFromRoot(type: AdType, moment: String? = nil, onClose: (() -> Void)? = nil) {
        guard let rootVC = getRootViewController() else { return }
        
        switch type {
        case .yandexBanner:
            displayYandexBanner(from: rootVC)
        case .yandexInt:
            displayYandexInt(from: rootVC, onClose: onClose)
        case .admobInt:
            displayAdmobInt(from: rootVC, moment: moment)
        }
    }
    
    // MARK: - 辅助方法
    
    private func getRootViewController() -> UIViewController? {
        return UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController
    }
    
    func getCurrentBannerAd() -> AdView? {
        let adView = AdCenter.shared.yanBannerCenter.getCurrentAd()
        AdCenter.shared.yanBannerCenter.refresh()
        return adView
    }
}

