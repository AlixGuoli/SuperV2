import SwiftUI

// 主题色配置
struct CoreVPNTheme {
    static let background = Color(red: 5/255, green: 5/255, blue: 9/255)          // #050509
    static let cardBackground = Color(red: 18/255, green: 18/255, blue: 25/255)   // 深灰卡片
    static let brandOrange = Color(red: 1.0, green: 0.48, blue: 0.10)             // 主橙
    static let brandOrangeSoft = Color(red: 1.0, green: 0.62, blue: 0.18)         // 渐变尾端
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 0.63, green: 0.63, blue: 0.70)
    static let successGreen = Color(red: 0.24, green: 0.86, blue: 0.59)
}

/// 主场景背景（主页 / 体检）：渐变 + 中心光晕 + 暗角
struct CoreVPNBackgroundView: View {
    var body: some View {
        ZStack {
            // 深色渐变基底
            LinearGradient(
                colors: [
                    Color(red: 6/255, green: 7/255, blue: 14/255),
                    Color(red: 8/255, green: 5/255, blue: 12/255)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // 中心轻微光晕
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0.10),
                    Color.clear
                ]),
                center: .center,
                startRadius: 0,
                endRadius: 260
            )
            .blendMode(.screen)
            
            // 暗角
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.65)
                ]),
                center: .center,
                startRadius: 320,
                endRadius: 800
            )
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }
}

/// 次要页面背景（节点 / 设置 / 语言）：只有渐变 + 轻微暗角，更克制
struct CoreVPNPlainBackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 6/255, green: 7/255, blue: 14/255),
                    Color(red: 8/255, green: 5/255, blue: 12/255)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.55)
                ]),
                center: .center,
                startRadius: 340,
                endRadius: 900
            )
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }
}


