import SwiftUI

struct HomeConnectView: View {
    @EnvironmentObject private var viewModel: TunnelStateManager
    @EnvironmentObject private var nodeStore: NodeSelectionStore
    @EnvironmentObject private var flowRouter: FlowRouter
    
    @State private var wasConnected = false
    @State private var showNodeSwitchAlert = false
    
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
            HomeBackgroundView()
            
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
                    // 如果已连接，显示提示；否则跳转到节点列表页面
                    if isConnected {
                        showNodeSwitchAlert = true
                    } else {
                        flowRouter.showNodeList()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                
                Spacer()
                
                // 中部：大按钮 + 本地环形装饰（跟随按钮位置）
                ZStack {
                    // 环形装饰：淡淡的科技感圈，只围绕按钮
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.03), lineWidth: 1)
                            .frame(width: 260, height: 260)
                        Circle()
                            .stroke(Color.white.opacity(0.025), lineWidth: 1)
                            .frame(width: 310, height: 310)
                        Circle()
                            .stroke(Color.white.opacity(0.02), lineWidth: 1)
                            .frame(width: 360, height: 360)
                    }
                    .blendMode(.screen)
                    
                    // 原有按钮本体
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
                        // 将当前节点 ID 传入连接流程（服务配置使用）
                        viewModel.setSelectedGroup(nodeStore.serviceGroupId)
                        // 仅在发起连接时展示“连接中”页，断开不展示
                        if viewModel.connectionStatus != .connected {
                            viewModel.showFlowConnecting = true  // 由 VM 决定
                        }
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
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 32)
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
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 16)
            }
            
            // 断开确认弹窗
            if viewModel.showDisconnectConfirm {
                DisconnectConfirmView(
                    onConfirm: {
                        viewModel.shutdownConnection()
                    },
                    onCancel: {
                        viewModel.cancelDisconnect()
                    }
                )
                .zIndex(1000)
            }
        }
        .alert("node_switch_alert_title", isPresented: $showNodeSwitchAlert) {
            Button("node_switch_alert_ok", role: .cancel) { }
        } message: {
            Text("node_switch_alert_message")
        }
        .onChange(of: viewModel.connectionStatus) { newStatus in
            handleStatusChange(newStatus)
        }
        .onChange(of: viewModel.showFlowConnecting) { show in
            if show {
                flowRouter.showConnecting()
            }
        }
        .onChange(of: viewModel.flowResult) { result in
            guard let result = result else { return }
            flowRouter.showResult(result)
            
            // 根据结果类型展示广告
            switch result {
            case .connectSuccess:
                showAd(moment: EventAd.connect)
            case .disconnectSuccess:
                showAd(moment: EventAd.disconnect)
            case .connectFail:
                // 连接失败不出广告
                break
            }
            
            viewModel.flowResult = nil
            viewModel.showFlowConnecting = false
        }
    }
    
    // 监听连接状态变化，驱动结果页
    private func handleStatusChange(_ newStatus: TunnelState) {
        switch newStatus {
        case .connected:
            wasConnected = true
        case .failed:
            break
        case .disconnected:
            if wasConnected {
                wasConnected = false
            }
        case .connecting:
            break
        }
    }
    
    /// 展示广告（根据结果类型）
    private func showAd(moment: String) {
        let adHub = AdHub.shared
        
        // 检查是否有广告可以展示
        guard adHub.hasAnyReady() else {
            return
        }
        
        // 按优先级展示广告：Admob > Yandex Banner > Yandex Int
        if adHub.pingG() {
            adHub.pushG(moment: moment)
        } else if adHub.pingBan() {
            adHub.pushBan()
        } else if adHub.pingInt() {
            adHub.pushInt()
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

// MARK: - 背景：深色渐变 + 暗角 + 环形线条

private struct HomeBackgroundView: View {
    var body: some View {
        ZStack {
            // 基础深色渐变
            LinearGradient(
                colors: [
                    Color(red: 6/255, green: 7/255, blue: 14/255),   // 顶部略冷
                    Color(red: 8/255, green: 5/255, blue: 12/255)    // 底部略暖
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // 中心柔和光晕，让按钮区域稍微亮一点
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
            
            // 暗角 vignette：四周略暗，中心更聚焦
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
    }
}


