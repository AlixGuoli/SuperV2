//
//  ServiceService.swift
//  CoreVPN
//
//  服务配置接口请求服务（/graphql/query/services）
//

import Foundation

final class ServiceService {
    
    static let shared = ServiceService()
    
    private init() {}
    
    /// 请求服务配置接口
    /// - Parameters:
    ///   - group: 节点ID，当前统一传 -1，后续会换成真实节点ID
    ///   - vip: 是否是VIP客户，0或1
    ///   - completion: 回调，返回加密的配置字符串
    func fetchServiceConfig(
        group: Int = -1,
        vip: Int = 0,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let endpoint = APIEndpoint(
            path: "/graphql/query/services",
            extraParams: [
                "group": group,
                "vip": vip
            ]
        )
        
        debugPrint("[Request] 开始请求服务配置，group: \(group), vip: \(vip)")
        
        APIRequestExecutor.shared.performRequest(endpoint: endpoint) { [weak self] result in
            switch result {
            case .success(let data):
                // 转换为字符串（返回的是加密字符串，不是 JSON）
                guard let configString = String(data: data, encoding: .utf8),
                      !configString.isEmpty else {
                    let error = NSError(
                        domain: "ServiceService",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to convert response to string"]
                    )
                    debugPrint("[Request] 服务配置响应转换失败")
                    completion(.failure(error))
                    return
                }
                
                // 打印加密内容（用于调试）
                debugPrint("[Request] 服务配置（加密内容）：\(configString)")
                
                // 解密服务配置
                guard let decryptedConfig = SecureConfigDecoder.decodeConfigPayload(configString) else {
                    let error = NSError(
                        domain: "ServiceService",
                        code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to decrypt service config"]
                    )
                    debugPrint("[Request] 服务配置解密失败")
                    completion(.failure(error))
                    return
                }
                
                // 验证解密后是否是有效的 JSON
                guard RequestUtils.validateJsonString(decryptedConfig) else {
                    let error = NSError(
                        domain: "ServiceService",
                        code: -3,
                        userInfo: [NSLocalizedDescriptionKey: "Decrypted config is not valid JSON"]
                    )
                    debugPrint("[Request] 服务配置解密后不是有效的 JSON")
                    completion(.failure(error))
                    return
                }
                
                debugPrint("[Request] 服务配置解密成功，JSON 长度：\(decryptedConfig.count)")
                
                // 保存原始加密配置
                ServiceConfigStore.shared.saveServiceConfig(configString)
                debugPrint("[Request] 服务配置已保存（加密状态）")
                
                completion(.success(configString))
                
            case .failure(let error):
                debugPrint("[Request] 服务配置请求失败：\(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
}

