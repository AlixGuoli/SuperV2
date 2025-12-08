//
//  AppDelegate.swift
//  CoreVPN
//
//  Created by SHI QIU on 2025/11/26.
//

import UIKit
import GoogleMobileAds
import YandexMobileAds

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        // 初始化语言
        _ = AppLanguage()
        
        initAdmob()
        initYandex()
        
        return true
    }
    
    func initAdmob() {
        MobileAds.shared.start { status in
            let adapterStatuses = status.adapterStatusesByClassName
            let success = adapterStatuses.values.contains { $0.state == .ready }
            
            if success {
                debugPrint("[Init] Admob 初始化成功")
            } else {
                debugPrint("[Init] Admob 初始化失败")
            }
        }
    }
    
    func initYandex() {
        MobileAds.initializeSDK {
            debugPrint("[Init] Yandex 初始化成功")
        }
    }
}

