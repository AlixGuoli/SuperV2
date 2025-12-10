//
//  ResultView.swift
//  CoreVPN
//
//  结果页（连接成功 / 失败 / 断开成功，占位）
//

import SwiftUI

struct ResultView: View {
    let type: ResultType
    let onClose: () -> Void
    
    private var titleKey: LocalizedStringKey {
        switch type {
        case .connectSuccess: return "result_connect_success"
        case .connectFail: return "result_connect_fail"
        case .disconnectSuccess: return "result_disconnect_success"
        }
    }
    
    private var iconName: String {
        switch type {
        case .connectSuccess: return "checkmark.circle.fill"
        case .connectFail: return "xmark.octagon.fill"
        case .disconnectSuccess: return "power"
        }
    }
    
    private var iconColor: Color {
        switch type {
        case .connectSuccess: return CoreVPNTheme.successGreen
        case .connectFail: return .red
        case .disconnectSuccess: return CoreVPNTheme.brandOrange
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: iconName)
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(iconColor)
            Text(titleKey)
                .foregroundColor(CoreVPNTheme.textPrimary)
                .font(.title2.bold())
            
            Spacer(minLength: 16)
            
            VStack(spacing: 12) {
                TelegramCard()
                ShareAppCard()
            }
            
            ReviewCard()
            
            Button(action: {
                onClose()
            }) {
                Text("connecting_close")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(CoreVPNTheme.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(CoreVPNTheme.brandOrange.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .foregroundColor(CoreVPNTheme.textPrimary)
            }
            .padding(.bottom, 20)
            
        }
        .padding(.horizontal, 24)
        .background(CoreVPNBackgroundView())
        .navigationTitle(LocalizedStringKey("result_nav_title"))
        .navigationBarBackButtonHidden()
        .navigationBarTitleDisplayMode(.inline)
    }
}

