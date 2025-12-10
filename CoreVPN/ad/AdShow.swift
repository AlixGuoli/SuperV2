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
    
    func showYanInt(from viewController: UIViewController, onClose: (() -> Void)? = nil) {
        AdHub.shared.yIntUnit.onAdClosed = onClose
        AdHub.shared.yIntUnit.open(from: viewController, moment: nil)
    }
    
    func showYanBan(from viewController: UIViewController) {
        AdHub.shared.yBanUnit.open(from: viewController)
    }
    
    func showGAd(from viewController: UIViewController, moment: String?) {
        AdHub.shared.gUnit.open(from: viewController, moment: moment)
    }
    
    // MARK: - 便捷展示方法（合并为一个）
    
    func showFromRoot(type: AdType, moment: String? = nil, onClose: (() -> Void)? = nil) {
        guard let rootVC = getRootViewController() else { return }
        
        switch type {
        case .yandexBanner:
            showYanBan(from: rootVC)
        case .yandexInt:
            showYanInt(from: rootVC, onClose: onClose)
        case .admobInt:
            showGAd(from: rootVC, moment: moment)
        }
    }
    
    // MARK: - 辅助方法
    
    private func getRootViewController() -> UIViewController? {
        return UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController
    }
    
    func fetchBan() -> AdView? {
        let adView = AdHub.shared.yBanUnit.getCurrentAd()
        AdHub.shared.yBanUnit.refresh()
        return adView
    }
}

