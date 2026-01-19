import SwiftUI

private enum SpeedTestStatus {
    case idle
    case running
    case finished
}

struct SpeedTestView: View {
    @EnvironmentObject private var tabSelection: TabSelection
    
    @State private var status: SpeedTestStatus = .idle
    @State private var progress: Double = 0
    @State private var latency: Int = 0
    @State private var download: Int = 0
    @State private var upload: Int = 0
    @State private var score: Int = 0
    
    @State private var timer: Timer?
    @State private var elapsed: TimeInterval = 0
    
    var body: some View {
        ZStack {
            CoreVPNBackgroundView()
            
            VStack(spacing: 0) {
                // 顶部标题区域
                VStack(spacing: 6) {
                    Text("speedtest_title")
                        .font(.title2.bold())
                        .foregroundColor(CoreVPNTheme.textPrimary)
                    Text("speedtest_subtitle")
                        .font(.subheadline)
                        .foregroundColor(CoreVPNTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 12)
                .padding(.bottom, 24)
                
                if status == .finished {
                    // 结果状态：重新设计的现代布局
                    ScrollView {
                        VStack(spacing: 20) {
                            // 评分卡片：符合app风格
                            VStack(spacing: 12) {
                                Text("speedtest_result_title")
                                    .font(.caption)
                                    .foregroundColor(CoreVPNTheme.textSecondary)
                                
                                // 分数显示
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text("\(score)")
                                        .font(.system(size: 48, weight: .bold, design: .rounded))
                                        .foregroundColor(scoreColor)
                                    Text("/ 100")
                                        .font(.title3)
                                        .foregroundColor(CoreVPNTheme.textSecondary)
                                }
                                
                                Text(resultCommentKey)
                                    .font(.subheadline)
                                    .foregroundColor(CoreVPNTheme.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            .padding(.horizontal, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                scoreColor.opacity(0.15),
                                                scoreColor.opacity(0.05)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            
                            // 三个指标：独立卡片，横向排列
                            HStack(spacing: 12) {
                                resultItem(titleKey: "speedtest_latency", value: "\(latency) ms", icon: "clock.fill")
                                resultItem(titleKey: "speedtest_download", value: "\(download) Mbps", icon: "arrow.down.circle.fill")
                                resultItem(titleKey: "speedtest_upload", value: "\(upload) Mbps", icon: "arrow.up.circle.fill")
                            }
                            
                            // 优化建议（如果有）
                            if let suggestionKey = suggestionKey {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "lightbulb.fill")
                                        .font(.subheadline)
                                        .foregroundColor(CoreVPNTheme.brandOrange)
                                        .frame(width: 20)
                                    Text(suggestionKey)
                                        .font(.subheadline)
                                        .foregroundColor(CoreVPNTheme.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(CoreVPNTheme.cardBackground.opacity(0.6))
                                )
                            }
                            
                            // 去连接按钮
                            Button {
                                tabSelection.selectedIndex = 0
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "power.circle.fill")
                                    Text("speedtest_button_connect")
                                }
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(CoreVPNTheme.successGreen)
                                )
                            }
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(CoreVPNTheme.cardBackground)
                        )
                        .padding(.horizontal, 20)
                    }
                } else {
                    // 默认/测试中状态：显示大圆环，下方小提示
                    Spacer()
                    
                    // 圆环进度（大一点，居中）
                    ZStack {
                        Circle()
                            .stroke(CoreVPNTheme.cardBackground, lineWidth: 14)
                            .frame(width: 240, height: 240)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(progress / 100))
                            .stroke(
                                AngularGradient(
                                    gradient: Gradient(colors: [
                                        CoreVPNTheme.brandOrange,
                                        CoreVPNTheme.brandOrangeSoft,
                                        CoreVPNTheme.brandOrange
                                    ]),
                                    center: .center
                                ),
                                style: StrokeStyle(lineWidth: 14, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 240, height: 240)
                            .animation(.easeInOut(duration: 0.15), value: progress)
                        
                        VStack(spacing: 6) {
                            Text("\(Int(progress))%")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(CoreVPNTheme.textPrimary)
                            Text(currentPhaseTextKey)
                                .font(.caption)
                                .foregroundColor(CoreVPNTheme.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    // 下方提示（小框）
                    Group {
                        if status == .idle {
                            // 空状态
                            VStack(spacing: 12) {
                                Image(systemName: "speedometer")
                                    .font(.system(size: 48, weight: .light))
                                    .foregroundColor(CoreVPNTheme.brandOrange.opacity(0.6))
                                
                                VStack(spacing: 4) {
                                    Text("speedtest_empty_title")
                                        .font(.subheadline.bold())
                                        .foregroundColor(CoreVPNTheme.textPrimary)
                                    Text("speedtest_empty_subtitle")
                                        .font(.caption)
                                        .foregroundColor(CoreVPNTheme.textSecondary)
                                        .multilineTextAlignment(.center)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(CoreVPNTheme.cardBackground)
                            )
                            .padding(.horizontal, 24)
                        } else {
                            // 测试中：显示提示文字
                            Text("speedtest_ready_hint")
                                .font(.footnote)
                                .foregroundColor(CoreVPNTheme.textSecondary)
                                .padding(12)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(CoreVPNTheme.cardBackground)
                                )
                                .padding(.horizontal, 24)
                        }
                    }
                    .padding(.bottom, 20)
                }
                
                // 底部按钮（固定在底部）
                Button(action: startOrReset) {
                    HStack(spacing: 8) {
                        if status == .finished {
                            Image(systemName: "arrow.clockwise")
                                .font(.subheadline.bold())
                        }
                        Text(buttonTitleKey)
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(CoreVPNTheme.brandOrange)
                    )
                }
                .disabled(status == .running)
                .opacity(status == .running ? 0.7 : 1.0)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
        .onDisappear {
            invalidateTimer()
            // 重置状态，避免切换 Tab 后仍停留在运行态导致按钮不可点击
            status = .idle
            progress = 0
            latency = 0
            download = 0
            upload = 0
            score = 0
            elapsed = 0
        }
    }
    
    private var buttonTitleKey: LocalizedStringKey {
        switch status {
        case .running:
            return "speedtest_button_running"
        case .finished:
            return "speedtest_button_retry"
        default:
            return "speedtest_button_start"
        }
    }
    
    private func resultItem(titleKey: String, value: String, icon: String) -> some View {
        VStack(spacing: 10) {
            // 图标：圆形背景
            ZStack {
                Circle()
                    .fill(iconColor(for: titleKey).opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(iconColor(for: titleKey))
            }
            
            // 数值（防止换行）
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
                .foregroundColor(CoreVPNTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            // 标题
            Text(LocalizedStringKey(titleKey))
                .font(.caption)
                .foregroundColor(CoreVPNTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(CoreVPNTheme.cardBackground.opacity(0.6))
        )
    }
    
    // 根据指标类型返回不同颜色
    private func iconColor(for titleKey: String) -> Color {
        switch titleKey {
        case "speedtest_latency":
            return Color(red: 0.3, green: 0.7, blue: 1.0) // 蓝色 - 延迟
        case "speedtest_download":
            return CoreVPNTheme.successGreen // 绿色 - 下载
        case "speedtest_upload":
            return CoreVPNTheme.brandOrange // 橙色 - 上传
        default:
            return CoreVPNTheme.brandOrange
        }
    }
    
    
    // 根据分数返回颜色
    private var scoreColor: Color {
        switch score {
        case 0..<50:
            return Color.red.opacity(0.8)
        case 50..<80:
            return CoreVPNTheme.brandOrange
        default:
            return CoreVPNTheme.successGreen
        }
    }
    
    // 优化建议
    private var suggestionKey: LocalizedStringKey? {
        if latency > 100 {
            return "speedtest_suggestion_latency"
        } else if download < 30 {
            return "speedtest_suggestion_download"
        } else if score < 60 {
            return "speedtest_suggestion_score"
        }
        return nil
    }
    
    private var currentPhaseTextKey: LocalizedStringKey {
        switch status {
        case .idle:
            return "speedtest_phase_idle"
        case .running:
            if progress < 35 {
                return "speedtest_phase_ping"
            } else if progress < 75 {
                return "speedtest_phase_download"
            } else {
                return "speedtest_phase_evaluating"
            }
        case .finished:
            return "speedtest_phase_finished"
        }
    }
    
    private var resultCommentKey: LocalizedStringKey {
        switch score {
        case 0..<50:
            return "speedtest_result_poor"
        case 50..<80:
            return "speedtest_result_ok"
        default:
            return "speedtest_result_good"
        }
    }
    
    private func startOrReset() {
        if status == .running { return }
        progress = 0
        latency = 0
        download = 0
        upload = 0
        score = 0
        elapsed = 0
        status = .running
        
        // 让整体时长在 6~9 秒之间，更接近真实测速体验
        let totalDuration = Double(Int.random(in: 6...9))
        
        invalidateTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { t in
            elapsed += 0.1
            let ratio = min(1.0, elapsed / totalDuration)
            // 进度随时间平滑增加，而不是随机跳
            progress = ratio * 100
            
            if ratio >= 1.0 {
                t.invalidate()
                finishTest()
                return
            }
            
            // 在不同阶段逐步生成看起来合理的数据
            if ratio < 0.35 {
                // 延迟：从 80ms 渐变到 30-120 区间
                if latency == 0 { latency = 80 }
                latency = clamp(latency + Int.random(in: -5...4), min: 30, max: 120)
            } else if ratio < 0.8 {
                // 下载：20-120 Mbps 间平滑波动
                if download == 0 { download = Int.random(in: 25...60) }
                download = clamp(download + Int.random(in: -4...7), min: 20, max: 130)
            } else {
                // 上传：5-45 Mbps 间平滑波动
                if upload == 0 { upload = Int.random(in: 8...18) }
                upload = clamp(upload + Int.random(in: -3...5), min: 5, max: 45)
            }
        }
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func finishTest() {
        // 根据数据简单算一个分数
        let latencyScore = max(0, 100 - latency / 2)        // 延迟越低越好
        let downloadScore = min(100, download)              // 100Mbps 视为满分
        let uploadScore = min(100, upload * 2)              // 50Mbps 视为满分
        
        score = clamp((latencyScore + downloadScore + uploadScore) / 3, min: 10, max: 99)
        status = .finished
    }
    
    private func clamp(_ value: Int, min: Int, max: Int) -> Int {
        if value < min { return min }
        if value > max { return max }
        return value
    }
    
    private func invalidateTimer() {
        timer?.invalidate()
        timer = nil
    }
}

