//
//  UserPrefs.swift
//  CoreVPN
//
//  VIP 状态存储
//

import Foundation

struct UserPrefs {
    static let premiumStatusKey = "UserPrefs.PremiumStatus"
    
    static var isPremium: Bool {
        get {
            return UserDefaults.standard.bool(forKey: premiumStatusKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: premiumStatusKey)
            UserDefaults.standard.synchronize()
        }
    }
}

