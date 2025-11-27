//
//  DisconnectConfirmView.swift
//  CoreVPN
//
//  Created by SHI QIU on 2025/11/27.
//

import SwiftUI

struct DisconnectConfirmView: View {
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }
            
            // 确认卡片
            VStack(spacing: 20) {
                Text("disconnect_confirm_title")
                    .font(.headline)
                    .foregroundColor(CoreVPNTheme.textPrimary)
                
                Text("disconnect_confirm_message")
                    .font(.subheadline)
                    .foregroundColor(CoreVPNTheme.textSecondary)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 16) {
                    // 取消按钮
                    Button(action: onCancel) {
                        Text("disconnect_confirm_cancel")
                            .font(.headline)
                            .foregroundColor(CoreVPNTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(CoreVPNTheme.cardBackground)
                            )
                    }
                    
                    // 确认按钮
                    Button(action: onConfirm) {
                        Text("disconnect_confirm_confirm")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(CoreVPNTheme.brandOrange)
                            )
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(CoreVPNTheme.cardBackground)
            )
            .padding(.horizontal, 40)
        }
        .transition(.opacity)
    }
}

