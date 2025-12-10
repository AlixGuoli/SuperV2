//
//  BannerScreen.swift
//  CoreVPN
//
//  自定义 Banner 展示页（穿透逻辑）
//

import Foundation
import UIKit
import YandexMobileAds

class BannerBoard: UIViewController {
    
    private var didClickAd = false
    private var delayFlag = false
    private var penetrateFlag = false
    private var remainSeconds = 6
    private let skipBox = UIView()
    private let skipText = UILabel()
    
    var onDismiss: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupAdLogic()
        setupUI()
        setupObservers()
        startCountdown()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - 广告系统配置
    
    private func setupAdLogic() {
        BannerEnv.isShowing = true
        
        let delayThreshold = Int.random(in: 1...100)
        let penetrationThreshold = Int.random(in: 1...100)
        
        penetrateFlag = BannerEnv.penetrationRate() >= penetrationThreshold
        delayFlag = BannerEnv.clickDelay() >= delayThreshold
        
        debugPrint("[Ad-BannerScreen] 穿透率: \(BannerEnv.penetrationRate())% | 随机值: \(penetrationThreshold)")
        debugPrint("[Ad-BannerScreen] 点击延迟: \(BannerEnv.clickDelay())% | 随机值: \(delayThreshold)")
        
        guard let bannerView = BannerEnv.bannerAd() else {
            dismissAd()
            return
        }
        
        attachBanner(bannerView)
    }
    
    private func attachBanner(_ bannerView: UIView) {
        view.addSubview(bannerView)
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        
        let constraints = [
            bannerView.topAnchor.constraint(equalTo: view.topAnchor),
            bannerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bannerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bannerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ]
        NSLayoutConstraint.activate(constraints)
        
        BannerEnv.onBannerClicked { [weak self] in
            self?.didClickAd = true
        }
    }
    
    // MARK: - 界面创建
    
    private func setupUI() {
        view.backgroundColor = .white
        setupSkipBox()
        setupSkipText()
        layoutSkipBox()
    }
    
    private func setupSkipBox() {
        skipBox.translatesAutoresizingMaskIntoConstraints = false
        skipBox.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        skipBox.layer.cornerRadius = 10
        view.addSubview(skipBox)
    }
    
    private func setupSkipText() {
        skipText.textAlignment = .center
        skipText.textColor = .white
        skipText.font = UIFont(name: "PingFangSC-Regular", size: 14)
        skipText.text = String(format: NSLocalizedString("BannerWaitText", comment: ""), remainSeconds)
        
        let interactionEnabled = !penetrateFlag
        skipText.isUserInteractionEnabled = interactionEnabled
        skipBox.isUserInteractionEnabled = interactionEnabled
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(skipButtonTapped))
        skipText.addGestureRecognizer(tapGesture)
    }
    
    private func layoutSkipBox() {
        skipBox.addSubview(skipText)
        skipText.translatesAutoresizingMaskIntoConstraints = false
        
        let containerConstraints = [
            skipBox.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            skipBox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20)
        ]
        
        let labelConstraints = [
            skipText.topAnchor.constraint(equalTo: skipBox.topAnchor, constant: 4),
            skipText.leadingAnchor.constraint(equalTo: skipBox.leadingAnchor, constant: 10),
            skipText.bottomAnchor.constraint(equalTo: skipBox.bottomAnchor, constant: -4),
            skipText.trailingAnchor.constraint(equalTo: skipBox.trailingAnchor, constant: -10),
            skipText.heightAnchor.constraint(equalToConstant: 30)
        ]
        
        NSLayoutConstraint.activate(containerConstraints + labelConstraints)
    }
    
    // MARK: - 通知注册
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func appWillEnterForeground() {
        guard didClickAd else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.dismissAd()
        }
    }
    
    // MARK: - 用户交互
    
    @objc private func skipButtonTapped() {
        let canSkip = remainSeconds <= 1
        if canSkip {
            dismissAd()
        }
    }
    
    // MARK: - 广告关闭
    
    private func dismissAd() {
        dismiss(animated: true) {
            BannerEnv.isShowing = false
            self.onDismiss?()
            debugPrint("[Ad-BannerScreen] 关闭广告")
        }
    }
    
    // MARK: - 倒计时管理
    
    private func startCountdown() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            self.processCountdownTick(timer)
        }
    }
    
    private func processCountdownTick(_ timer: Timer) {
        let hasTimeRemaining = remainSeconds > 0
        if hasTimeRemaining {
            remainSeconds -= 1
            refreshSkipButtonText()
        } else {
            skipText.isUserInteractionEnabled = true
            skipBox.isUserInteractionEnabled = true
            refreshSkipButtonText()
            timer.invalidate()
        }
    }
    
    private func enableSkipButton() {
        let shouldEnable = !delayFlag || !penetrateFlag
        if shouldEnable {
            skipText.isUserInteractionEnabled = true
            skipBox.isUserInteractionEnabled = true
        }
    }
    
    private func refreshSkipButtonText() {
        let timeExpired = remainSeconds <= 0
        if timeExpired {
            enableSkipButton()
            skipText.text = NSLocalizedString("BannerSkipText", comment: "")
        } else {
            skipText.text = String(format: NSLocalizedString("BannerWaitText", comment: ""), remainSeconds)
        }
    }
}

// MARK: - 外部依赖封装
private enum BannerEnv {
    static func penetrationRate() -> Int { AdsConfigStore.shared.penetrationRate() }
    static func clickDelay() -> Int { AdsConfigStore.shared.clickDelay() }
    static func bannerAd() -> UIView? { AdCenter.shared.getYanBannerAd() }
    static func onBannerClicked(_ cb: @escaping () -> Void) {
        AdCenter.shared.yanBannerCenter.onAdClicked = cb
    }
    static var isShowing: Bool {
        get { AdCenter.shared.isShowingAd }
        set { AdCenter.shared.isShowingAd = newValue }
    }
}

