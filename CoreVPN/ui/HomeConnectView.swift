import SwiftUI

struct HomeConnectView: View {
    @StateObject private var viewModel = VPNConnectionViewModel()
    @EnvironmentObject private var nodeStore: NodeSelectionStore
    @EnvironmentObject private var tabSelection: TabSelection
    
    private var isConnected: Bool {
        viewModel.connectionStatus == .connected
    }
    
    private var isConnecting: Bool {
        viewModel.connectionStatus == .connecting
    }
    
    private var currentNodeCountry: String {
        guard let node = nodeStore.selectedNode else {
            return "Auto"
        }
        return node.name
    }
    
    var body: some View {
        ZStack {
            CoreVPNTheme.background
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // 顶部：当前节点
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("home_current_node_title")
                            .font(.caption)
                            .foregroundColor(CoreVPNTheme.textSecondary)
                        HStack(spacing: 6) {
                            Circle()
                                .fill(CoreVPNTheme.brandOrange)
                                .frame(width: 6, height: 6)
                            Text(currentNodeCountry)
                                .foregroundColor(CoreVPNTheme.textPrimary)
                                .font(.headline)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(CoreVPNTheme.textSecondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    // 跳转到节点 Tab
                    tabSelection.selectedIndex = 1
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                
                Spacer()
                
                // 中部：大按钮
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    CoreVPNTheme.brandOrange.opacity(0.35),
                                    .clear
                                ]),
                                center: .center,
                                startRadius: 10,
                                endRadius: 180
                            )
                        )
                        .blur(radius: 20)
                    
                    Button(action: {
                        viewModel.toggleConnection()
                    }) {
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
                                .shadow(color: CoreVPNTheme.brandOrange.opacity(0.6),
                                        radius: isConnected ? 18 : 8)
                            
                            VStack(spacing: 6) {
                                Image(systemName: isConnected ? "lock.shield.fill" : "power")
                                    .font(.system(size: 32, weight: .semibold))
                                    .foregroundColor(isConnected ? CoreVPNTheme.successGreen : CoreVPNTheme.brandOrange)
                                
                                let buttonTitleKey: LocalizedStringKey = isConnected
                                ? "home_button_connected"
                                : (isConnecting ? "home_button_connecting" : "home_button_connect")
                                
                                Text(buttonTitleKey)
                                    .font(.headline)
                                    .foregroundColor(CoreVPNTheme.textPrimary)
                                
                                // 连接时长：始终占位，避免布局跳动；仅在已连接且有值时可见
                                let showDuration = isConnected && !viewModel.elapsedDisplay.isEmpty
                                let durationText = showDuration ? viewModel.elapsedDisplay : "00:00"
                                
                                Text(durationText)
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundColor(CoreVPNTheme.brandOrange)
                                    .opacity(showDuration ? 1 : 0)
                            }
                        }
                    }
                    .frame(width: 220, height: 220)
                    .disabled(!viewModel.canInteract)
                    .opacity(viewModel.canInteract ? 1.0 : 0.6)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isConnected)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isConnecting)
                }
                
                // 状态文本
                VStack(spacing: 4) {
                    let statusKey: LocalizedStringKey = {
                        switch viewModel.connectionStatus {
                        case .connected:
                            return "home_status_connected_desc"
                        case .connecting:
                            return "home_button_connecting"
                        case .failed:
                            return "home_status_disconnected_desc"
                        case .disconnected:
                            return "home_status_disconnected_desc"
                        }
                    }()
                    
                    Text(statusKey)
                    .font(.subheadline)
                    .foregroundColor(CoreVPNTheme.textSecondary)
                }
                .padding(.top, 8)
                
                Spacer()
                
                // 底部卡片：延迟 / 速度（示意数据）
                HStack(spacing: 14) {
                    StatCardView(
                        titleKey: "home_stat_latency",
                        value: viewModel.fakeLatencyText,
                        accent: CoreVPNTheme.brandOrange
                    )
                    StatCardView(
                        titleKey: "home_stat_download",
                        value: viewModel.fakeDownloadText,
                        accent: CoreVPNTheme.brandOrangeSoft
                    )
                }
                .padding(.horizontal, 20)
                
                // 底部提示
                Text("home_footer_tip")
                    .font(.caption2)
                    .foregroundColor(CoreVPNTheme.textSecondary)
                    .padding(.bottom, 16)
            }
            
            // 断开确认弹窗
            if viewModel.showDisconnectConfirm {
                DisconnectConfirmView(
                    onConfirm: {
                        viewModel.confirmDisconnect()
                    },
                    onCancel: {
                        viewModel.cancelDisconnect()
                    }
                )
                .zIndex(1000)
            }
        }
    }
}

// 底部统计卡片
struct StatCardView: View {
    let titleKey: String
    let value: String
    let accent: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(LocalizedStringKey(titleKey))
                .font(.caption)
                .foregroundColor(CoreVPNTheme.textSecondary)
            Text(value)
                .font(.headline)
                .foregroundColor(CoreVPNTheme.textPrimary)
            Rectangle()
                .fill(accent.opacity(0.8))
                .frame(height: 2.5)
                .cornerRadius(999)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(CoreVPNTheme.cardBackground)
        )
    }
}


