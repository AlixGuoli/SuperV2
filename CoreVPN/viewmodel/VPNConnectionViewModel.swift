//
//  VPNConnectionViewModel.swift
//  CoreVPN
//
//  Created by SHI QIU on 2025/11/27.
//

import Foundation
import NetworkExtension
import Combine

class VPNConnectionViewModel: ObservableObject {
    
    private let manager = VPNManager.shared()
    
    @Published var connectionStatus: VPNConnectionStatus = .disconnected
    @Published var showDisconnectConfirm: Bool = false
    @Published var connectedSince: Date?        // 开始连接时间
    @Published var elapsedDisplay: String = ""  // 展示用的连接时长文本
    @Published var fakeLatencyText: String = "-- ms"      // 底部卡片：延迟
    @Published var fakeDownloadText: String = "0 Mbps"    // 底部卡片：下载速度
    
    private var systemStatus: NEVPNStatus = .invalid {
        didSet {
            guard oldValue != systemStatus else { return }
            // 状态改变时，走统一映射
            applyStateToUI(systemStatus)
        }
    }
    
    private var connectBySelf: Bool = false  // 标记是否用户主动连接
    private var timer: Timer?
    private let connectedSinceKey = "VPNConnectedSince"
    
    // 伪统计数据内部数值
    private var currentLatency: Double = 0
    private var currentDownload: Double = 0
    private var targetDownload: Double = 0
    private var downloadTick: Int = 0
    
    init() {
        // 初始化时读取当前系统状态
        systemStatus = manager.coreMgr.connection.status
        
        // 监听系统状态变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(vpnStatusDidChange(_:)),
            name: .NEVPNStatusDidChange,
            object: nil
        )
        
        // 恢复状态（加载配置并同步UI）
        restoreConnectionState()
    }
    
    /// 恢复连接状态（app启动时调用）- 只读取已有配置，不创建
    private func restoreConnectionState() {
        connectBySelf = false  // 恢复状态，不是主动连接
        
        // 只读取已有配置，不创建（避免首次安装时触发权限）
        manager.loadExistingPreferences { [weak self] hasConfig, error in
            guard let self = self else { return }
            
            if let error = error {
                debugPrint("VPNConnectionViewModel: 恢复状态时加载配置失败 - \(error)")
                self.connectionStatus = .disconnected
                return
            }
            
            if !hasConfig {
                // 没有配置，说明用户还没连接过，直接显示未连接状态
                debugPrint("VPNConnectionViewModel: 没有配置，显示未连接状态")
                self.connectionStatus = .disconnected
                return
            }
            
            // 有配置，读取系统状态并同步UI
            let current = self.manager.coreMgr.connection.status
            DispatchQueue.main.async {
                // 如果系统已连接，尝试恢复 connectedSince
                if current == .connected {
                    let ts = UserDefaults.standard.double(forKey: self.connectedSinceKey)
                    if ts > 0 {
                        self.connectedSince = Date(timeIntervalSince1970: ts)
                    } else {
                        let now = Date()
                        self.connectedSince = now
                        UserDefaults.standard.set(
                            now.timeIntervalSince1970,
                            forKey: self.connectedSinceKey
                        )
                    }
                    self.startTimerIfNeeded()
                }
                
                if self.systemStatus != current {
                    self.systemStatus = current
                } else {
                    // 状态没变化，主动调用 applyStateToUI 来驱动UI更新
                    self.applyStateToUI(current)
                }
            }
        }
    }
    
    deinit {
        stopTimer()
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func vpnStatusDidChange(_ notification: Notification) {
        let newStatus = manager.coreMgr.connection.status
        debugPrint("VPNConnectionViewModel: 系统状态变化 - \(newStatus.rawValue)")
        systemStatus = newStatus
    }
    
    /// 将系统 NEVPNStatus 同步到 UI（不依赖 didSet，供首次进入/无变更时调用）
    private func applyStateToUI(_ newState: NEVPNStatus) {
        switch newState {
        case .connected:
            debugPrint("VPNConnectionViewModel: 系统已连接")
            if connectBySelf {
                // 仅用户主动流程触发验证操作
                // 计时起点放在验证成功后（performPostConnectionTasks）
                performPostConnectionTasks()
            } else {
                // 恢复状态，直接更新UI
                if connectedSince == nil {
                    let now = Date()
                    connectedSince = now
                    UserDefaults.standard.set(
                        now.timeIntervalSince1970,
                        forKey: connectedSinceKey
                    )
                }
                startTimerIfNeeded()
                connectionStatus = .connected
            }
            
        case .disconnected, .invalid:
            debugPrint("VPNConnectionViewModel: 系统已断开")
            connectionStatus = .disconnected
            connectBySelf = false
            connectedSince = nil
            elapsedDisplay = ""
            UserDefaults.standard.removeObject(forKey: connectedSinceKey)
            fakeLatencyText = "-- ms"
            fakeDownloadText = "0 Mbps"
            currentLatency = 0
            currentDownload = 0
            targetDownload = 0
            downloadTick = 0
            stopTimer()
            
        case .connecting:
            debugPrint("VPNConnectionViewModel: 系统连接中")
            connectionStatus = .connecting
            
        case .disconnecting, .reasserting:
            debugPrint("VPNConnectionViewModel: 系统断开中/重新连接中")
            connectionStatus = .connecting
            
        @unknown default:
            debugPrint("VPNConnectionViewModel: 未知状态")
            connectionStatus = .failed
            connectBySelf = false
        }
    }
    
    /// 执行连接后的任务（接口调用、验证等）- 仅用户主动连接时调用
    private func performPostConnectionTasks() {
        // TODO: 在这里实现你的业务逻辑
        // 例如：调用接口验证、测试网络连接等
        
        // 示例：模拟异步操作
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self = self else { return }
            let isSuccess = true  // 暂时返回成功，后续替换为真实逻辑
            
            if isSuccess {
                if self.connectedSince == nil {
                    let now = Date()
                    self.connectedSince = now
                    UserDefaults.standard.set(
                        now.timeIntervalSince1970,
                        forKey: self.connectedSinceKey
                    )
                }
                self.startTimerIfNeeded()
                self.connectionStatus = .connected
            } else {
                // 验证失败，主动断开
                debugPrint("VPNConnectionViewModel: 连接后验证失败，主动断开")
                self.manager.stopConnection()
                self.connectionStatus = .failed
                self.connectedSince = nil
                self.elapsedDisplay = ""
                UserDefaults.standard.removeObject(forKey: self.connectedSinceKey)
                self.stopTimer()
            }
            self.connectBySelf = false
        }
    }
    
    /// 切换连接状态
    func toggleConnection() {
        guard connectionStatus != .connecting else { return }
        
        switch connectionStatus {
        case .disconnected, .failed:
            startConnection()
        case .connected:
            showDisconnectConfirm = true
        case .connecting:
            break
        }
    }
    
    /// 开始连接（用户主动连接）
    private func startConnection() {
        connectBySelf = true  // 标记为用户主动连接
        connectionStatus = .connecting  // 先更新UI状态
        connectedSince = nil
        elapsedDisplay = ""
        stopTimer()
        
        manager.loadFromPreferences { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                debugPrint("VPNConnectionViewModel: 加载配置失败 - \(error)")
                self.connectionStatus = .failed
                self.connectBySelf = false
                return
            }
            
            self.manager.enableAndConfigure { error in
                if let error = error {
                    debugPrint("VPNConnectionViewModel: 配置失败 - \(error)")
                    self.connectionStatus = .failed
                    self.connectBySelf = false
                    return
                }
                
                self.manager.startConnection { error in
                    if let error = error {
                        debugPrint("VPNConnectionViewModel: 启动连接失败 - \(error)")
                        self.connectionStatus = .failed
                        self.connectBySelf = false
                    }
                    // 成功启动后，等待系统状态变化通知（会触发 applyStateToUI）
                }
            }
        }
    }
    
    /// 确认断开
    func confirmDisconnect() {
        showDisconnectConfirm = false
        connectBySelf = false
        connectionStatus = .connecting
        
        manager.stopConnection()
        // 等待系统状态变化通知来更新UI（会触发 applyStateToUI）
    }
    
    /// 取消断开
    func cancelDisconnect() {
        showDisconnectConfirm = false
    }
    
    /// 判断是否可以交互（按钮是否可用）
    var canInteract: Bool {
        return connectionStatus != .connecting
    }
    
    // MARK: - 连接时长计时
    
    private func startTimerIfNeeded() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateElapsedDisplay()
        }
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateElapsedDisplay() {
        guard let start = connectedSince else {
            elapsedDisplay = ""
            // 未连接时也顺便刷新一下伪统计（例如衰减下载速度等）
            updateFakeStats()
            return
        }
        let interval = Int(Date().timeIntervalSince(start))
        if interval < 0 {
            elapsedDisplay = ""
            updateFakeStats()
            return
        }
        let hours = interval / 3600
        let minutes = (interval % 3600) / 60
        let seconds = interval % 60
        
        if hours > 0 {
            elapsedDisplay = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            elapsedDisplay = String(format: "%02d:%02d", minutes, seconds)
        }
        
        // 每次计时刷新时同步更新伪统计数据
        updateFakeStats()
    }
    
    /// 更新伪延迟与伪下载速度，使其看起来接近真实行为
    private func updateFakeStats() {
        // 延迟
        if connectionStatus == .connected {
            if currentLatency <= 0 {
                // 初始基准延迟，模拟比较常见的公网延迟
                currentLatency = 60   // 中位偏上的默认值
            }
            let delta = Double(Int.random(in: -5...5))
            // 大多数用户日常使用下，延迟集中在 30~150ms 之间
            currentLatency = min(max(currentLatency + delta, 30), 150)
            fakeLatencyText = "\(Int(currentLatency)) ms"
        } else {
            // 未连接时显示占位
            fakeLatencyText = "-- ms"
            currentLatency = 0
        }
        
        // 下载速度
        if connectionStatus == .connected {
            downloadTick += 1
            // 每隔几秒更换一次目标速度，模拟“呼吸”效果
            if currentDownload <= 0 || downloadTick % 5 == 0 {
                // 模拟普通~优质宽带：15~80 Mbps
                targetDownload = Double.random(in: 15...80)
            }
            // 逐步向目标靠拢，带一点惯性
            currentDownload += (targetDownload - currentDownload) * 0.2
            // 小抖动
            currentDownload += Double.random(in: -2...2)
            // 普通用户环境下，下载速度多在 5~120 Mbps 之间
            currentDownload = min(max(currentDownload, 5), 120)
            
            fakeDownloadText = "\(Int(currentDownload)) Mbps"
        } else {
            // 未连接时逐渐衰减到 0，看起来更自然
            if currentDownload > 1 {
                currentDownload *= 0.6
                fakeDownloadText = "\(Int(currentDownload)) Mbps"
            } else {
                currentDownload = 0
                fakeDownloadText = "0 Mbps"
                targetDownload = 0
                downloadTick = 0
            }
        }
    }
}

