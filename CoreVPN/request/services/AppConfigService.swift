//
//  AppConfigService.swift
//  CoreVPN
//
//  基本配置服务（请求、解析、保存、Git 更新）
//

import Foundation

final class AppConfigService {
    
    static let shared = AppConfigService()
    
    private init() {}
    
    /// 请求基本配置接口
    func fetchBaseConfig(completion: @escaping (Result<AppConfig, Error>) -> Void) {
        let endpoint = APIEndpoint(path: "/graphql/query/config")
        
        debugPrint("[Request] 开始请求基本配置")
        
        APIRequestExecutor.shared.performRequest(endpoint: endpoint) { [weak self] result in
            switch result {
            case .success(let data):
                // 打印原始响应内容
                let text = String(data: data, encoding: .utf8) ?? "<non-utf8 data>"
                debugPrint("[Request] 基本配置请求成功，响应内容：\(text)")
                
                // 验证是否是有效的 JSON
                guard RequestUtils.validateJsonString(text) else {
                    let error = NSError(
                        domain: "AppConfigService",
                        code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "Response is not valid JSON"]
                    )
                    debugPrint("[Request] 基本配置响应不是有效的 JSON")
                    completion(.failure(error))
                    return
                }
                
                // 解码为 AppConfig
                guard let config = try? JSONDecoder().decode(AppConfig.self, from: data) else {
                    let error = NSError(
                        domain: "AppConfigService",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to decode AppConfig"]
                    )
                    debugPrint("[Request] 配置解析失败")
                    completion(.failure(error))
                    return
                }
                
                // 保存配置
                AppConfigStore.shared.saveAppConfig(config)
                debugPrint("[Request] 配置已保存")
                
                // 检查 Git 版本并更新
                self?.checkAndUpdateGitVersion(newConfig: config)
                
                // 提取并保存各种配置
                self?.extractAndSaveConfigs(from: config)
                
                completion(.success(config))
                
            case .failure(let error):
                debugPrint("[Request] 请求失败：\(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Private
    
    /// 检查 Git 版本并更新（如果需要）
    private func checkAndUpdateGitVersion(newConfig: AppConfig) {
        let newGitVersion = newConfig.commonConf.git_version
        
        let localGitVersion = AppConfigStore.shared.getLocalGitVersion()
        debugPrint("[Request] 本地 Git 版本：\(localGitVersion)，新版本：\(newGitVersion)")
        
        if newGitVersion > localGitVersion {
            debugPrint("[Request] 本地版本较旧，开始更新 Git 配置")
            
            DomainConfigStore.shared.refreshConfigFromGit { result in
                switch result {
                case .success:
                    // Git 更新成功，更新本地版本号
                    AppConfigStore.shared.saveGitVersion(newGitVersion)
                    debugPrint("[Request] Git 更新成功，已更新版本号：\(newGitVersion)")
                case .failure(let error):
                    debugPrint("[Request] Git 更新失败：\(error.localizedDescription)，版本号未更新")
                }
            }
        } else {
            debugPrint("[Request] 本地版本已是最新，无需更新")
        }
    }
    
    /// 提取并保存各种配置
    private func extractAndSaveConfigs(from config: AppConfig) {
        let store = AppConfigStore.shared
        
        // 保存 Telegram 链接
        if let tgLink = store.dynamicTelegramLink() {
            store.saveTgLink(tgLink)
        }
        
        // 保存 hotcode（只保存一次）
        if let hotcode = store.serviceStatusCode() {
            store.saveHotcodeIfNeeded(hotcode)
        }
        
        // 保存广告配置
        store.saveAdsOff(store.adsEnabledStatus())
        store.saveAdsType(store.adsCategoryType())
        
        debugPrint("[Request] 配置提取完成")
        debugPrint("[Request] adsOff: \(String(describing: store.adsEnabledStatus()))")
        debugPrint("[Request] adsType: \(String(describing: store.adsCategoryType()))")
        debugPrint("[Request] tgLink: \(String(describing: store.telegramLink()))")
        debugPrint("[Request] hotcode: \(String(describing: store.serviceStatusCode()))")
    }
}

