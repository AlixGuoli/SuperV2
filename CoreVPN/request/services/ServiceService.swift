//
//  ServiceService.swift
//  CoreVPN
//
//  服务配置接口请求服务（/poplar/service/timber）
//

import Foundation

final class ServiceService {
    
    static let shared = ServiceService()
    
    private init() {}
    
    /// 请求服务配置接口并处理
    /// - Parameters:
    ///   - group: 节点ID，当前统一传 -1，后续会换成真实节点ID
    ///   - vip: 是否是VIP客户，0或1
    func fetchServiceConfig(group: Int = -1, vip: Int = 0) async {
        let endpoint = APIEndpoint(
            path: "/poplar/service/timber",
            extraParams: [
                "group": group,
                "vip": vip
            ]
        )
        
        debugPrint("[Request] 开始请求服务配置，group: \(group), vip: \(vip)")
        
        // 尝试请求接口
        var serviceConfig: String? = nil
        
        // 使用 continuation 将 completion 转为 async
        serviceConfig = await withCheckedContinuation { continuation in
            APIRequestExecutor.shared.performRequest(endpoint: endpoint) { result in
                switch result {
                case .success(let data):
                    if let configString = String(data: data, encoding: .utf8), !configString.isEmpty {
                        debugPrint("[Request] 服务配置（加密内容）：\(configString)")
                        continuation.resume(returning: configString)
                    } else {
                        debugPrint("[Request] 服务配置响应转换失败")
                        continuation.resume(returning: nil)
                    }
                case .failure(let error):
                    debugPrint("[Request] 服务配置请求失败：\(error.localizedDescription)")
                    continuation.resume(returning: nil)
                }
            }
        }
        
        let store = ServiceConfigStore.shared
        
        // 如果接口有返回，尝试解密
        if let configString = serviceConfig {
            // 解密服务配置
            if let decryptedConfig = SecureConfigDecoder.decodeConfigPayload(configString),
               RequestUtils.validateJsonString(decryptedConfig) {
                // 接口成功且解密成功
                debugPrint("[Request] Use ServiceCF @@ request")
                store.nowServiceCF = configString
                store.isFromRequest = true
                // 上报状态：接口成功
                EventReporter.shared.sendStatus(success: true)
                processServiceConfig(decryptedConfig, isValid: true)
                return
            } else {
                // 解密失败，回退到 UserDefaults
                debugPrint("[Request] 服务配置解密失败，回退到 UserDefaults")
            }
        }
        
        // 接口失败或解密失败，从 UserDefaults 读取
        debugPrint("[Request] Request Service config is nil, Get service config from UserDefaults")
        store.isFromRequest = false
        // 上报状态：接口失败（回退到 UserDefaults 或本地文件）
        EventReporter.shared.sendStatus(success: false)
        
        if let udConfig = store.getServiceConfig(), !udConfig.isEmpty {
            debugPrint("[Request] Use ServiceCF @@ UserDefaults")
            
            // 解密
            if let decryptedConfig = SecureConfigDecoder.decodeConfigPayload(udConfig),
               RequestUtils.validateJsonString(decryptedConfig) {
                debugPrint("[Request] Decryption Service Config")
                processServiceConfig(decryptedConfig, isValid: false)
            } else {
                debugPrint("[Request] UserDefaults Service config 解密失败")
            }
        } else {
            debugPrint("[Request] UserDefaults Service config is nil")
        }
    }
    
    /// 处理服务配置：解析 IP 并写入 Group
    private func processServiceConfig(_ decryptedConfig: String, isValid: Bool) {
        let store = ServiceConfigStore.shared
        
        // 解析 IP
        store.scanCfg(input: decryptedConfig, isValid: isValid)
        
        // 写入 Group UserDefaults
        Task {
            do {
                try await CFGPipeline.shared.storeCfg(serviceConfig: decryptedConfig)
            } catch {
                debugPrint("[Request] 保存服务配置到 Group 失败：\(error.localizedDescription)")
            }
        }
    }
}
