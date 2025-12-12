//
//  ConnectingView.swift
//  CoreVPN
//
//  连接中页面（占位，后续可加广告）
//

import SwiftUI

struct ConnectingView: View {
    let onClose: () -> Void
    
    @State private var timeoutTask: DispatchWorkItem?
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 20)
            
            // 中部：大按钮 + 环形装饰（模仿主页）
            ZStack {
                // 环形装饰：淡淡的科技感圈
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.03), lineWidth: 1)
                        .frame(width: 200, height: 200)
                    Circle()
                        .stroke(Color.white.opacity(0.025), lineWidth: 1)
                        .frame(width: 240, height: 240)
                    Circle()
                        .stroke(Color.white.opacity(0.02), lineWidth: 1)
                        .frame(width: 280, height: 280)
                }
                .blendMode(.screen)
                
                // 按钮本体
                ZStack {
                    // 发光效果
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    CoreVPNTheme.brandOrange.opacity(0.35),
                                    .clear
                                ]),
                                center: .center,
                                startRadius: 8,
                                endRadius: 140
                            )
                        )
                        .blur(radius: 20)
                    
                    // 按钮主体
                    ZStack {
                        Circle()
                            .fill(CoreVPNTheme.cardBackground)
                        Circle()
                            .strokeBorder(
                                AngularGradient(
                                    gradient: Gradient(colors: [
                                        CoreVPNTheme.brandOrange,
                                        CoreVPNTheme.brandOrangeSoft,
                                        CoreVPNTheme.brandOrange
                                    ]),
                                    center: .center
                                ),
                                lineWidth: 3
                            )
                            .shadow(color: CoreVPNTheme.brandOrange.opacity(0.6), radius: 8)
                        
                        // 中心内容
                        VStack(spacing: 6) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: CoreVPNTheme.brandOrange))
                                .scaleEffect(1.0)
                            
                            Text("connecting_title")
                                .font(.headline)
                                .foregroundColor(CoreVPNTheme.textPrimary)
                        }
                    }
                }
                .frame(width: 180, height: 180)
            }
            
            // 状态文本
            VStack(spacing: 4) {
                Text("connecting_subtitle")
                    .font(.subheadline)
                    .foregroundColor(CoreVPNTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 32)
            }
            
            Spacer(minLength: 16)
            
            VStack(spacing: 16) {
                ReviewCard()
                // 移除关闭按钮，防止用户在连接过程中手动关闭，导致状态不一致
                // 连接成功/失败后会自动关闭，40秒超时也会自动关闭
            }
            .padding(.bottom, 20)
            
        }
        .padding(.horizontal, 24)
        .background(CoreVPNBackgroundView())
        .navigationTitle(LocalizedStringKey("connecting_nav_title"))
        .navigationBarBackButtonHidden()
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            debugPrint("[ConnectingView] onAppear - 启动40秒超时计时器")
            // 启动40秒超时计时器
            let task = DispatchWorkItem {
                debugPrint("[ConnectingView] 40秒超时，自动关闭页面")
                onClose()
            }
            timeoutTask = task
            DispatchQueue.main.asyncAfter(deadline: .now() + 40.0, execute: task)
        }
        .onDisappear {
            debugPrint("[ConnectingView] onDisappear - 页面消失，取消计时器")
            // 页面消失时取消计时器
            timeoutTask?.cancel()
            timeoutTask = nil
        }
    }
}

