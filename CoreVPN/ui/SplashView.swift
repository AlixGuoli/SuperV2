import SwiftUI
import Alamofire

struct SplashView: View {
    let onFinish: () -> Void
    let onFinishWithAd: (() -> Void)?
    
    @State private var progress: Double = 0
    @State private var hasAdReady = false
    @State private var isDone = false
    
    init(onFinish: @escaping () -> Void, onFinishWithAd: (() -> Void)? = nil) {
        self.onFinish = onFinish
        self.onFinishWithAd = onFinishWithAd
    }
    
    private let privacyKey = "CoreVPNPrivacyAccepted_v1"
    private let maxWaitTime: TimeInterval = 20.0
    
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
                
                VStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 999)
                                .fill(CoreVPNTheme.cardBackground.opacity(0.9))
                            RoundedRectangle(cornerRadius: 999)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            CoreVPNTheme.brandOrange,
                                            CoreVPNTheme.brandOrangeSoft
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * progress)
                        }
                    }
                    .frame(height: 6)
                    
                    Text("splash_loading")
                        .font(.caption2)
                        .foregroundColor(CoreVPNTheme.textSecondary)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            beginSetup()
        }
        .onChange(of: isDone) { done in
            if done {
                completeSplash()
            }
        }
    }
    
    // MARK: - 初始化流程
    
    private func beginSetup() {
        // 启动20秒进度条动画
        withAnimation(.linear(duration: maxWaitTime)) {
            progress = 1.0
        }
        
        // 检查网络并初始化
        checkNetwork()
        
        // 20秒超时
        DispatchQueue.main.asyncAfter(deadline: .now() + maxWaitTime) {
            if !isDone {
                debugPrint("[Ad-Splash] ⏱️ 20秒超时，进入主页")
                isDone = true
            }
        }
    }
    
    private func checkNetwork() {
        let netMgr = NetworkReachabilityManager()
        netMgr?.startListening(onUpdatePerforming: { status in
            switch status {
            case .reachable(.ethernetOrWiFi), .reachable(.cellular):
                debugPrint("[Ad-Splash] 🌐 网络可用，开始初始化")
                Task {
                    let adReady = await setupConfig()
                    DispatchQueue.main.async {
                        if !isDone {
                            hasAdReady = adReady
                            isDone = true
                        }
                    }
                }
                netMgr?.stopListening()
            case .notReachable:
                break
            case .unknown:
                break
            }
        })
    }
    
    private func setupConfig() async -> Bool {
        // 1. 先获取基础配置（必须等待完成）
        debugPrint("[Splash] 开始请求基础配置")
        await withCheckedContinuation { continuation in
            AppConfigService.shared.fetchBaseConfig { result in
                switch result {
                case .success:
                    debugPrint("[Splash] 基础配置请求成功")
                case .failure(let error):
                    debugPrint("[Splash] 基础配置请求失败: \(error.localizedDescription)")
                }
                continuation.resume()
            }
        }
        debugPrint("[Splash] 基础配置请求完成")
        
        // 2. 同时进行：加载广告 + 请求广告接口（不等待广告配置完成）
        Task {
            AdsService.shared.fetchAdsConfig { _ in }
        }
        
        // 3. 优化广告加载逻辑：优先等待 Banner，如果 Banner 成功则直接返回
        debugPrint("[Ad-Splash] 🚀 开始加载广告")
        let result = await waitForAds()
        debugPrint("[Ad-Splash] 广告加载完成 | 结果: \(result ? "成功" : "失败")")
        
        return result
    }
    
    private func waitForAds() async -> Bool {
        // 同时开始加载两个广告
        async let bannerResult = fetchBanner()
        async let intResult = fetchInt()
        
        // 先等待 Banner 的结果
        let bannerOk = await bannerResult
        if bannerOk {
            debugPrint("[Ad-Splash] ✅ Banner 加载成功，直接返回")
            return true
        } else {
            debugPrint("[Ad-Splash] ⏳ Banner 失败，等待 Int 结果")
            let intOk = await intResult
            return intOk
        }
    }
    
    private func fetchBanner() async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                var resumed = false
                
                AdHub.shared.warmBan(onAdReady: {
                    if !resumed {
                        resumed = true
                        debugPrint("[Ad-Splash] ✅ Banner 加载成功")
                        continuation.resume(returning: true)
                    }
                }, onAdFailed: {
                    if !resumed {
                        resumed = true
                        debugPrint("[Ad-Splash] ❌ Banner 加载失败")
                        continuation.resume(returning: false)
                    }
                })
            }
        }
    }
    
    private func fetchInt() async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                var resumed = false
                
                AdHub.shared.warmInt(onAdReady: {
                    if !resumed {
                        resumed = true
                        debugPrint("[Ad-Splash] ✅ Int 加载成功")
                        continuation.resume(returning: true)
                    }
                }, onAdFailed: {
                    if !resumed {
                        resumed = true
                        debugPrint("[Ad-Splash] ❌ Int 加载失败")
                        continuation.resume(returning: false)
                    }
                })
            }
        }
    }
    
    // MARK: - 完成启动页
    
    private func completeSplash() {
        // 如果提前完成，进度条跳到100%
        if progress < 1.0 {
            withAnimation(.easeOut(duration: 0.3)) {
                progress = 1.0
            }
        }
        
        // 延迟一点再进入主页，确保进度条动画完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if hasAdReady {
                onFinishWithAd?()
            } else {
                onFinish()
            }
        }
    }
}


