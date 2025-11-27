import SwiftUI

/// 应用内语言管理（支持运行时切换）
final class AppLanguage: ObservableObject {
    @Published var locale: Locale
    
    private let storageKey = "AppLanguageCode"
    
    init() {
        if let saved = UserDefaults.standard.string(forKey: storageKey) {
            locale = Locale(identifier: saved)
        } else {
            // 默认跟随系统（只在中英文间时依然能切换）
            locale = Locale.current
        }
    }
    
    func setLanguage(code: String) {
        locale = Locale(identifier: code)
        UserDefaults.standard.set(code, forKey: storageKey)
    }
}


