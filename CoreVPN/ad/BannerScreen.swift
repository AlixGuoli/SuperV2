//
//  BannerScreen.swift
//  CoreVPN
//
//  自定义 Banner 展示页（穿透逻辑）
//

import Foundation
import UIKit
import YandexMobileAds

class BannerScreen: UIViewController {
    
    private var adClicked = false
    private var delayEnabled = false
    private var penetrationEnabled = false
    private var countdownTimer = 6
    private let skipContainer = UIView()
    private let skipLabel = UILabel()
    
    var onDismiss: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureAdSystem()
        createInterface()
        registerNotifications()
        initializeCountdown()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - 广告系统配置
    
    private func configureAdSystem() {
        AdCenter.shared.isShowingAd = true
        
        let delayThreshold = Int.random(in: 1...100)
        let penetrationThreshold = Int.random(in: 1...100)
        
        penetrationEnabled = AdsConfigStore.shared.penetrationRate() >= penetrationThreshold
        delayEnabled = AdsConfigStore.shared.clickDelay() >= delayThreshold
        
        debugPrint("[Ad-BannerScreen] 穿透率: \(AdsConfigStore.shared.penetrationRate())% | 随机值: \(penetrationThreshold)")
        debugPrint("[Ad-BannerScreen] 点击延迟: \(AdsConfigStore.shared.clickDelay())% | 随机值: \(delayThreshold)")
        
        guard let bannerView = AdCenter.shared.getYanBannerAd() else {
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
        
        AdCenter.shared.yanBannerCenter.onAdClicked = { [weak self] in
            self?.adClicked = true
        }
    }
    
    // MARK: - 界面创建
    
    private func createInterface() {
        view.backgroundColor = .white
        setupSkipButton()
        configureSkipButton()
        positionSkipButton()
    }
    
    private func setupSkipButton() {
        skipContainer.translatesAutoresizingMaskIntoConstraints = false
        skipContainer.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        skipContainer.layer.cornerRadius = 10
        view.addSubview(skipContainer)
    }
    
    private func configureSkipButton() {
        skipLabel.textAlignment = .center
        skipLabel.textColor = .white
        skipLabel.font = UIFont(name: "PingFangSC-Regular", size: 14)
        skipLabel.text = String(format: NSLocalizedString("BannerWaitText", comment: ""), countdownTimer)
        
        let interactionEnabled = !penetrationEnabled
        skipLabel.isUserInteractionEnabled = interactionEnabled
        skipContainer.isUserInteractionEnabled = interactionEnabled
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(skipButtonTapped))
        skipLabel.addGestureRecognizer(tapGesture)
    }
    
    private func positionSkipButton() {
        skipContainer.addSubview(skipLabel)
        skipLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let containerConstraints = [
            skipContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            skipContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20)
        ]
        
        let labelConstraints = [
            skipLabel.topAnchor.constraint(equalTo: skipContainer.topAnchor, constant: 4),
            skipLabel.leadingAnchor.constraint(equalTo: skipContainer.leadingAnchor, constant: 10),
            skipLabel.bottomAnchor.constraint(equalTo: skipContainer.bottomAnchor, constant: -4),
            skipLabel.trailingAnchor.constraint(equalTo: skipContainer.trailingAnchor, constant: -10),
            skipLabel.heightAnchor.constraint(equalToConstant: 30)
        ]
        
        NSLayoutConstraint.activate(containerConstraints + labelConstraints)
    }
    
    // MARK: - 通知注册
    
    private func registerNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func appWillEnterForeground() {
        guard adClicked else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.dismissAd()
        }
    }
    
    // MARK: - 用户交互
    
    @objc private func skipButtonTapped() {
        let canSkip = countdownTimer <= 1
        if canSkip {
            dismissAd()
        }
    }
    
    // MARK: - 广告关闭
    
    private func dismissAd() {
        dismiss(animated: true) {
            AdCenter.shared.isShowingAd = false
            self.onDismiss?()
            debugPrint("[Ad-BannerScreen] 关闭广告")
        }
    }
    
    // MARK: - 倒计时管理
    
    private func initializeCountdown() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            self.processCountdownTick(timer)
        }
    }
    
    private func processCountdownTick(_ timer: Timer) {
        let hasTimeRemaining = countdownTimer > 0
        if hasTimeRemaining {
            countdownTimer -= 1
            refreshSkipButtonText()
        } else {
            refreshSkipButtonText()
            timer.invalidate()
        }
    }
    
    private func enableSkipButton() {
        let shouldEnable = !delayEnabled || !penetrationEnabled
        if shouldEnable {
            skipLabel.isUserInteractionEnabled = true
            skipContainer.isUserInteractionEnabled = true
        }
    }
    
    private func refreshSkipButtonText() {
        let timeExpired = countdownTimer <= 0
        if timeExpired {
            enableSkipButton()
            skipLabel.text = NSLocalizedString("BannerSkipText", comment: "")
        } else {
            skipLabel.text = String(format: NSLocalizedString("BannerWaitText", comment: ""), countdownTimer)
        }
    }
}

