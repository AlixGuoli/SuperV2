//
//  BackgroundSplashView.swift
//  CoreVPN
//
//  后台切前台时的启动页（用于展示广告）
//

import SwiftUI

struct BackgroundSplashView: View {
    let onFinish: () -> Void
    
    var body: some View {
        ZStack {
            CoreVPNBackgroundView()
            
            VStack(spacing: 32) {
                Spacer()
                
                VStack(spacing: 12) {
                    Image("logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 88, height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: Color.black.opacity(0.6), radius: 12, x: 0, y: 8)
                    
                    Text("splash_title")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(CoreVPNTheme.textPrimary)
                    Text("splash_subtitle")
                        .font(.subheadline)
                        .foregroundColor(CoreVPNTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 32)
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: CoreVPNTheme.brandOrange))
                        .scaleEffect(1.2)
                    
                    Text("splash_loading")
                        .font(.caption2)
                        .foregroundColor(CoreVPNTheme.textSecondary)
                }
                .padding(.bottom, 40)
            }
        }
    }
}

