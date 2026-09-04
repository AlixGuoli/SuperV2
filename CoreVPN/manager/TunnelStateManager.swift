//
//  TunnelStateManager.swift
//  CoreVPN
//
//  Created by SHI QIU on 2025/11/27.
//

import Foundation
import NetworkExtension
import Combine

class TunnelStateManager: ObservableObject {
    
    private let tunnelService = TunnelService.shared()
    
    @Published var connectionStatus: TunnelState = .disconnected {
        didSet {
            // 同步到全局状态
            AppGlobalStatus.shared.connectStatus = connectionStatus
        }
    }
    @Published var showDisconnectConfirm: Bool = false
    
    // UI流程：连接中/结果
    @Published var showFlowConnecting: Bool = false
    @Published var flowResult: ResultType? = nil
    @Published var connectedSince: Date?        // 开始连接时间
    @Published var elapsedDisplay: String = ""  // 展示用的连接时长文本
    @Published var fakeLatencyText: String = "-- ms"      // 底部卡片：延迟
    @Published var fakeDownloadText: String = "0 Mbps"    // 底部卡片：下载速度
    
    private var systemTunnelStatus: NEVPNStatus = .invalid {
        didSet {
            guard oldValue != systemTunnelStatus else { return }
            // 状态改变时，走统一映射
            updateViewFromSystemState(systemTunnelStatus)
        }
    }
    
    private var userTriggered: Bool = false  // 标记是否用户主动连接
    private var hasEverConnected: Bool = false
    private var timer: Timer?
    private let connectionTimestampKey = "ConnectionTimestamp"
    private var connectionId: String? = nil  // 连接会话ID（用于上报）
    
    // 伪统计数据内部数值
    private var currentLatency: Double = 0
    private var currentDownload: Double = 0
    private var targetDownload: Double = 0
    private var downloadTick: Int = 0
    private var selectedGroupId: Int = -1
    private let attemptLock = NSLock()
    private var attemptEpoch: UInt64 = 0
    private var didReportFinalResult = false
    private var awaitingTunnelStart = false
    private var readingBatchReport = false
    private var lastExtensionLogSequence: UInt64 = 0
    
    init() {
        // 初始化时读取当前系统状态
        systemTunnelStatus = tunnelService.tunnelProvider.connection.status
        
        // 监听系统状态变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onTunnelStatusChanged(_:)),
            name: .NEVPNStatusDidChange,
            object: nil
        )
        
        // 恢复状态（加载配置并同步UI）
        recoverTunnelState()
        
        // 初始化时同步一次全局状态
        AppGlobalStatus.shared.connectStatus = connectionStatus
    }
    
    /// 恢复连接状态（app启动时调用）- 只读取已有配置，不创建
    private func recoverTunnelState() {
        userTriggered = false  // 恢复状态，不是主动连接
        
        // 只读取已有配置，不创建（避免首次安装时触发权限）
        tunnelService.loadExistingPreferences { [weak self] hasConfig, error in
            guard let self = self else { return }
            
            if let error = error {
                debugPrint("TunnelStateManager: 恢复状态时加载配置失败 - \(error)")
                self.connectionStatus = .disconnected
                return
            }
            
            if !hasConfig {
                // 没有配置，说明用户还没连接过，直接显示未连接状态
                debugPrint("TunnelStateManager: 没有配置，显示未连接状态")
                self.connectionStatus = .disconnected
                return
            }
            
            // 有配置，读取系统状态并同步UI
            let current = self.tunnelService.tunnelProvider.connection.status
            DispatchQueue.main.async {
                // 如果系统已连接，尝试恢复 connectedSince
                if current == .connected {
                    let ts = UserDefaults.standard.double(forKey: self.connectionTimestampKey)
                    if ts > 0 {
                        self.connectedSince = Date(timeIntervalSince1970: ts)
                    } else {
                        let now = Date()
                        self.connectedSince = now
                        UserDefaults.standard.set(
                            now.timeIntervalSince1970,
                            forKey: self.connectionTimestampKey
                        )
                    }
                    self.startTimerIfNeeded()
                }
                
                if self.systemTunnelStatus != current {
                    self.systemTunnelStatus = current
                } else {
                    // 状态没变化，主动调用 updateViewFromSystemState 来驱动UI更新
                    self.updateViewFromSystemState(current)
                }
            }
        }
    }
    
    deinit {
        stopTimer()
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func onTunnelStatusChanged(_ notification: Notification) {
        let newStatus = tunnelService.tunnelProvider.connection.status
        debugPrint("TunnelStateManager: 系统状态变化 - \(newStatus.rawValue)")
        systemTunnelStatus = newStatus
    }
    
    /// 将系统 NEVPNStatus 同步到 UI（不依赖 didSet，供首次进入/无变更时调用）
    private func updateViewFromSystemState(_ newState: NEVPNStatus) {
        switch newState {
        case .connected:
            debugPrint("TunnelStateManager: 系统已连接")
            if userTriggered {
                finishTriggeredConnection()
            } else {
                // 恢复状态，直接更新UI
                if connectedSince == nil {
                    let now = Date()
                    connectedSince = now
                    UserDefaults.standard.set(
                        now.timeIntervalSince1970,
                        forKey: connectionTimestampKey
                    )
                }
                startTimerIfNeeded()
                connectionStatus = .connected
                hasEverConnected = true
            }
            
        case .disconnected, .invalid:
            debugPrint("TunnelStateManager: 系统已断开")
            handleDisconnection()
            
        case .connecting:
            debugPrint("TunnelStateManager: 系统连接中")
            connectionStatus = .connecting
            
        case .disconnecting, .reasserting:
            debugPrint("TunnelStateManager: 系统断开中/重新连接中")
            connectionStatus = .connecting
            
        @unknown default:
            debugPrint("TunnelStateManager: 未知状态")
            connectionStatus = .failed
            userTriggered = false
        }
    }
    
    private func finishTriggeredConnection() {
        guard !readingBatchReport else { return }
        readingBatchReport = true
        let generation = currentGeneration()
        Task { [weak self] in
            guard let self else { return }
            let report = await self.loadBatchReport(preferProvider: true)
            self.printExtensionBatchLogs()
            guard self.isGenerationActive(generation), report?["success"] as? Bool == true else {
                self.readingBatchReport = false
                guard self.isGenerationActive(generation) else { return }
                self.handleConnectionFailure()
                return
            }
            let selectedIP = report?["selectedAddress"] as? String
            DispatchQueue.main.async {
                self.readingBatchReport = false
                guard self.isGenerationActive(generation) else { return }
                AppGlobalStatus.shared.connectStatus = .connected
                self.handleConnectionSuccess(selectedIP: selectedIP)
                self.userTriggered = false
            }
        }
    }
    
    /// 连接成功后的处理（确保主线程更新）
    private func handleConnectionSuccess(selectedIP: String?) {
        DispatchQueue.main.async {
            self.awaitingTunnelStart = false
            // 设置连接时间
            if self.connectedSince == nil {
                let now = Date()
                self.connectedSince = now
                UserDefaults.standard.set(
                    now.timeIntervalSince1970,
                    forKey: self.connectionTimestampKey
                )
            }
            
            self.startTimerIfNeeded()
            self.connectionStatus = .connected
            self.hasEverConnected = true
            
            let store = ServiceConfigStore.shared
            store.ipService = selectedIP
            ServiceService.shared.commitSuccessfulRequest()
            self.reportFinalResult(success: true, ip: selectedIP)
            
            // 显示结果页
            self.showFlowConnecting = false
            self.flowResult = .connectSuccess
        }
    }
    
    /// 连接失败后的处理
    private func handleConnectionFailure() {
        debugPrint("TunnelStateManager: 连接后验证失败，主动断开")
        
        DispatchQueue.main.async {
            self.awaitingTunnelStart = false
            self.tunnelService.stopConnection()
            ServiceService.shared.discardPreparedConfig()
            self.reportFinalResult(success: false, ip: nil)
            self.invalidateConnectionGeneration()
            self.connectionStatus = .failed
            self.connectedSince = nil
            self.elapsedDisplay = ""
            UserDefaults.standard.removeObject(forKey: self.connectionTimestampKey)
            self.stopTimer()
            
            // 显示结果页
            self.showFlowConnecting = false
            self.flowResult = .connectFail
        }
    }
    
    /// 断开连接后的处理
    private func handleDisconnection() {
        if userTriggered && awaitingTunnelStart && !hasEverConnected {
            ServiceService.shared.discardPreparedConfig()
            reportFinalResult(success: false, ip: nil)
            invalidateConnectionGeneration()
        }
        connectionStatus = .disconnected
        userTriggered = false
        readingBatchReport = false
        lastExtensionLogSequence = 0
        
        // 如果 hasEverConnected == false，说明已经在 shutdownConnection() 中处理过结果页了
        // 这里只处理状态清理，不再设置结果页
        if hasEverConnected {
            // 这种情况是系统自动断开（非用户主动），显示断开成功结果页
            flowResult = .disconnectSuccess
            showFlowConnecting = false
            hasEverConnected = false
        } else if showFlowConnecting {
            // 连接失败：还在连接页但从未成功连接过，关闭连接页并显示失败结果页
            showFlowConnecting = false
            flowResult = .connectFail
        }
        
        // 清理连接相关状态
        connectedSince = nil
        elapsedDisplay = ""
        UserDefaults.standard.removeObject(forKey: connectionTimestampKey)
        
        // 重置统计数据
        fakeLatencyText = "-- ms"
        fakeDownloadText = "0 Mbps"
        currentLatency = 0
        currentDownload = 0
        targetDownload = 0
        downloadTick = 0
        
        stopTimer()
    }
    
    /// 切换连接状态
    func toggleConnection() {
        guard connectionStatus != .connecting else { return }
        
        switch connectionStatus {
        case .disconnected, .failed:
            launchConnection()
        case .connected:
            showDisconnectConfirm = true
        case .connecting:
            break
        }
    }
    
    /// 更新当前选中的节点组 ID（用于服务配置）
    func setSelectedGroup(_ id: Int) {
        selectedGroupId = id
    }
    
    /// 开始连接（用户主动连接）
    private func launchConnection() {
        // 先获取VPN权限（会触发系统权限弹窗），权限成功后再继续连接流程
        tunnelService.loadFromPreferences { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                debugPrint("TunnelStateManager: 加载配置失败（可能是用户取消了权限）- \(error)")
                //self.connectionStatus = .failed
                self.userTriggered = false
                return
            }
            
            // 确认拿到VPN权限后，才设置连接状态
            debugPrint("TunnelStateManager: VPN权限已获取，开始连接流程")
            
            DispatchQueue.main.async {
                // 立即显示连接页面，给用户反馈，避免重复点击
                self.showFlowConnecting = true
                self.connectionStatus = .connecting
                self.userTriggered = true  // 标记为用户主动连接
                // 不在这里设置连接状态，等确认拿到VPN权限后再设置
                self.connectedSince = nil
                self.elapsedDisplay = ""
                self.stopTimer()
            }
            
            Task{
                let generation = self.beginConnectionGeneration()
                let sessionID = EventReporter.makeRandomId()
                self.connectionId = sessionID
                EventReporter.shared.sendConnEvent(event: EventReporter.evtStart, sid: sessionID)
                let prepared = await ServiceService.shared.fetchServiceConfig(
                    group: self.selectedGroupId,
                    vip: UserPrefs.isPremium ? 1 : 0,
                    sessionID: sessionID,
                    commit: { changes in self.commitIfActive(generation, changes) }
                )
                guard self.isGenerationActive(generation) else { return }
                guard prepared else {
                    self.handleConnectionFailure()
                    self.userTriggered = false
                    return
                }
                
                self.tunnelService.enableAndConfigure { error in
                    guard self.isGenerationActive(generation) else { return }
                    if let error = error {
                        debugPrint("TunnelStateManager: 配置失败 - \(error)")
                        self.handleConnectionFailure()
                        self.userTriggered = false
                        return
                    }
                    self.awaitingTunnelStart = true
                    self.tunnelService.startConnection { error in
                        guard self.isGenerationActive(generation) else { return }
                        if let error = error {
                            self.awaitingTunnelStart = false
                            debugPrint("TunnelStateManager: 启动连接失败 - \(error)")
                            self.handleConnectionFailure()
                            self.userTriggered = false
                        }
                        // 成功启动后，等待系统状态变化通知（会触发 updateViewFromSystemState）
                    }
                }
            }
        }
    }
    
    /// 确认断开
    func shutdownConnection() {
        showDisconnectConfirm = false
        userTriggered = false
        awaitingTunnelStart = false
        readingBatchReport = false
        invalidateConnectionGeneration()
        ServiceService.shared.discardPreparedConfig()
        
        // 如果之前连接过，先显示结果页
        if hasEverConnected {
            flowResult = .disconnectSuccess
            showFlowConnecting = false
            hasEverConnected = false  // 清除标志，避免 handleDisconnection() 重复设置
            
            // 检查是否有广告可用
            if AdHub.shared.hasAnyReady() {
                debugPrint("[Request] 断开连接：有广告可用，延迟3秒后断开")
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self.connectionStatus = .connecting
                    self.tunnelService.stopConnection()
                }
            } else {
                debugPrint("[Request] 断开连接：无广告可用，立即断开")
                connectionStatus = .connecting
                tunnelService.stopConnection()
            }
        } else {
            // 没有连接过，直接断开
            connectionStatus = .connecting
            tunnelService.stopConnection()
        }
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

    // MARK: - Batch 连接代次与报告

    private func beginConnectionGeneration() -> UInt64 {
        attemptLock.lock()
        attemptEpoch &+= 1
        didReportFinalResult = false
        awaitingTunnelStart = false
        readingBatchReport = false
        lastExtensionLogSequence = 0
        let value = attemptEpoch
        attemptLock.unlock()
        return value
    }

    private func invalidateConnectionGeneration() {
        attemptLock.lock()
        attemptEpoch &+= 1
        attemptLock.unlock()
    }

    private func currentGeneration() -> UInt64 {
        attemptLock.lock()
        defer { attemptLock.unlock() }
        return attemptEpoch
    }

    private func isGenerationActive(_ value: UInt64) -> Bool {
        attemptLock.lock()
        defer { attemptLock.unlock() }
        return attemptEpoch == value
    }

    private func commitIfActive(_ value: UInt64, _ changes: () -> Bool) -> Bool {
        attemptLock.lock()
        defer { attemptLock.unlock() }
        guard attemptEpoch == value else { return false }
        return changes()
    }

    private func reportFinalResult(success: Bool, ip: String?) {
        printExtensionBatchLogs()
        attemptLock.lock()
        guard !didReportFinalResult else {
            attemptLock.unlock()
            return
        }
        didReportFinalResult = true
        let sid = connectionId
        let usesCache = !ServiceConfigStore.shared.isFromRequest
        attemptLock.unlock()

        EventReporter.shared.sendAppResult(
            success: success,
            ip: success ? ip : nil,
            usesCache: usesCache,
            sid: sid
        )
    }

    private func loadBatchReport(preferProvider: Bool) async -> [String: Any]? {
        if preferProvider,
           let session = tunnelService.tunnelProvider.connection as? NETunnelProviderSession,
           let request = try? JSONSerialization.data(withJSONObject: ["action": "batchReport"]) {
            let response: Data? = await withCheckedContinuation { (continuation: CheckedContinuation<Data?, Never>) in
                do {
                    try session.sendProviderMessage(request) { data in
                        continuation.resume(returning: data)
                    }
                } catch {
                    continuation.resume(returning: nil)
                }
            }
            if let response,
               let report = try? JSONSerialization.jsonObject(with: response) as? [String: Any] {
                return report
            }
        }
        return UserDefaults(suiteName: SharedConfig.storageGroup)?
            .dictionary(forKey: SharedConfig.reportKey)
    }

    private func printExtensionBatchLogs() {
#if DEBUG
        let entries = UserDefaults(suiteName: SharedConfig.storageGroup)?
            .array(forKey: SharedConfig.extensionLogKey) as? [[String: Any]] ?? []
        for entry in entries.sorted(by: {
            (($0["sequence"] as? NSNumber)?.uint64Value ?? 0)
                < (($1["sequence"] as? NSNumber)?.uint64Value ?? 0)
        }) {
            let sequence = (entry["sequence"] as? NSNumber)?.uint64Value ?? 0
            guard sequence > lastExtensionLogSequence else { continue }
            lastExtensionLogSequence = sequence
            if let message = entry["message"] as? String {
                debugPrint("[Tunnel Extension] \(message)")
            }
        }
#endif
    }
}
