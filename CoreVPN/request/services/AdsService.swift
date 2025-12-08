//
//  AdsService.swift
//  CoreVPN
//
//  广告配置接口请求服务
//

import Foundation

final class AdsService {
    
    static let shared = AdsService()
    
    private init() {}
    
    /// 请求广告配置接口
    func fetchAdsConfig(completion: @escaping (Result<AdsConfig, Error>) -> Void) {
        let endpoint = APIEndpoint(path: "/graphql/query/ads")
        
        debugPrint("[Request] 开始请求广告配置")
        
        APIRequestExecutor.shared.performRequest(endpoint: endpoint) { [weak self] result in
            switch result {
            case .success(let data):
                // 打印原始响应内容
                let text = String(data: data, encoding: .utf8) ?? "<non-utf8 data>"
                debugPrint("[Request] 广告配置请求成功，响应内容：\(text)")
                
                // 验证是否是有效的 JSON
                guard RequestUtils.validateJsonString(text) else {
                    let error = NSError(
                        domain: "AdsService",
                        code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "Response is not valid JSON"]
                    )
                    debugPrint("[Request] 广告配置响应不是有效的 JSON")
                    completion(.failure(error))
                    return
                }
                
                // 解码为 AdsConfig
                guard let config = try? JSONDecoder().decode(AdsConfig.self, from: data) else {
                    let error = NSError(
                        domain: "AdsService",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to decode AdsConfig"]
                    )
                    debugPrint("[Request] 广告配置解析失败")
                    completion(.failure(error))
                    return
                }
                
                // 提取并保存各种配置
                self?.extractAndSaveConfigs(from: config)
                
                completion(.success(config))
                
            case .failure(let error):
                debugPrint("[Request] 广告配置请求失败：\(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Private
    
    /// 提取并保存各种广告配置
    private func extractAndSaveConfigs(from config: AdsConfig) {
        let store = AdsConfigStore.shared
        let adMixed = config.adConfig.adMixed
        
        // 提取并保存 Yandex Banner 配置
        if let bannerConfig = store.extractYandexBannerConfig(from: adMixed) {
            store.saveYandexBannerKey(bannerConfig.key)
            store.savePenetrateSettings(penetrate: bannerConfig.penetrate, clickDelay: bannerConfig.clickDelay)
        }
        
        // 提取并保存 Yandex Int 配置
        if let intKey = store.extractYandexIntConfig(from: adMixed) {
            store.saveYandexIntKey(intKey)
        }
        
        // 提取并保存 AdMob Int 配置
        if let admobKey = store.extractAdmobIntConfig(from: adMixed) {
            store.saveAdmobIntKey(admobKey)
        }
        
        // 保存配置时间
        store.saveConfigDate()
        
        debugPrint("[Request] 广告配置提取完成")
    }
}

