//
//  AdShow.swift
//  CoreVPN
//
//  广告展示管理
//

import Foundation
import UIKit

// 广告类型枚举
enum AdType {
    case yandexInt
}

class AdShow {
    
    static let shared = AdShow()
    
    private init() {}
    
    // MARK: - 基础展示方法
    
    func showYanInt(from viewController: UIViewController, onClose: (() -> Void)? = nil) {
        let adsType = AppConfigStore.shared.getSavedAdsType()?.components(separatedBy: ";") ?? []
        let isEMMode = adsType.contains("e")
        
        if isEMMode {
            AdHub.shared.yEMIntUnit.onAdClosed = onClose
            AdHub.shared.yEMIntUnit.open(from: viewController, moment: nil)
        } else {
            AdHub.shared.yIntUnit.onAdClosed = onClose
            AdHub.shared.yIntUnit.open(from: viewController, moment: nil)
        }
    }
    
    // MARK: - 便捷展示方法（合并为一个）
    
    func showFromRoot(type: AdType, moment: String? = nil, onClose: (() -> Void)? = nil) {
        guard let rootVC = getRootViewController() else { return }
        
        switch type {
        case .yandexInt:
            showYanInt(from: rootVC, onClose: onClose)
        }
    }
    
    // MARK: - 辅助方法
    
    private func getRootViewController() -> UIViewController? {
        return UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController
    }
    
}
