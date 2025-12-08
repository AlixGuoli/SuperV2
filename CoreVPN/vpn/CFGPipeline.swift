//
//  ConnectConfigHandler.swift
//  CoreVPN
//
//  连接配置处理器：处理服务配置，更新入站和路由规则，保存到 Group UserDefaults
//

import Foundation

final class CFGPipeline {
    
    static let shared = CFGPipeline()
    
    private init() {}
    
    /// 保存处理后的服务配置到 Group UserDefaults
    /// - Parameter serviceConfig: 解密后的服务配置 JSON 字符串
    func storeCfg(serviceConfig: String) async throws {
        debugPrint("[Request] start store")
        
        let processedConfig = runPipe(serviceConfig) ?? serviceConfig
        await saveGroup(processedConfig)
        
        debugPrint("[Request] store done")
        debugPrint("[Request] final config: \(processedConfig)")
    }
    
    // MARK: - 配置处理管道
    
    private func runPipe(_ jsonString: String) -> String? {
        guard let config = pJSON(jsonString) else {
            debugPrint("[Request] parse fail")
            return nil
        }
        let updatedConfig = mutInbound(config)
        let enhancedConfig = mutRoute(updatedConfig)
        return wJSON(enhancedConfig)
    }
    
    // MARK: - 配置解析和序列化
    
    private func pJSON(_ jsonString: String) -> [String: Any]? {
        guard let jsonData = jsonString.data(using: .utf8) else {
            debugPrint("[Request] toData fail")
            return nil
        }
        return (try? JSONSerialization.jsonObject(with: jsonData, options: [])) as? [String: Any]
    }
    
    private func wJSON(_ config: [String: Any]) -> String? {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: config, options: .prettyPrinted) else {
            debugPrint("[Request] toString fail")
            return nil
        }
        return String(data: jsonData, encoding: .utf8)
    }
    
    // MARK: - 入站配置更新
    
    private func mutInbound(_ config: [String: Any]) -> [String: Any] {
        var cfg = config
        guard var inbounds = cfg["inbounds"] as? [[String: Any]],
              var firstInbound = inbounds.first else {
            debugPrint("[Request] no inbound")
            return cfg
        }
        
        firstInbound["listen"] = "[::1]"
        firstInbound["port"] = "8080"
        inbounds[0] = firstInbound
        cfg["inbounds"] = inbounds
        
        debugPrint("[Request] inbound set [::1]:8080")
        return cfg
    }
    
    // MARK: - 路由配置增强
    
    private func mutRoute(_ config: [String: Any]) -> [String: Any] {
        let enhancedConfig = config
        let bypassDomains = listBypass()
        let routingRules = mkRules(bypassDomains)
        return mergeRoute(enhancedConfig, rules: routingRules)
    }
    
    private func listBypass() -> [String] {
        var ds: [String] = []
        
        // 固定域名
        ds.append(contentsOf: ["yastatic","yandex","gameanalytics","mradx.net","target.my.com","vk.ru","vk.me","vk.com","mail.ru"])
        
        // 动态域名：从域名配置中提取
        let domainConfig = DomainConfigStore.shared.loadActiveConfig()
        ds.append(contentsOf: pickDyn(from: domainConfig))
        
        return ds
    }
    
    private func pickDyn(from domainConfig: DomainConfig?) -> [String] {
        var ds: [String] = []
        
        guard let domainConfig = domainConfig else {
            return ds
        }
        
        // 获取 connReport 域名
        let connReport = domainConfig.api.connectReportURL
        if !connReport.isEmpty {
            if let connHost = URL(string: connReport)?.host {
                ds.append(connHost)
            }
        }
        
        // 获取 genReport 域名
        let genReport = domainConfig.api.generalReportURL
        if !genReport.isEmpty {
            if let genHost = URL(string: genReport)?.host {
                ds.append(genHost)
            }
        }
        
        // 获取 hostList 域名（对应 DomainConfig 的 hosts）
        let hosts = domainConfig.api.hosts
        if !hosts.isEmpty {
            let hostDomains = hosts.compactMap { URL(string: $0)?.host }
            ds.append(contentsOf: hostDomains)
        }
        
        return ds
    }
    
    private func mkRules(_ domains: [String]) -> [[String: Any]] {
        var rs: [[String: Any]] = []
        
        // 固定规则：raw.githubusercontent.com 单独处理
        rs.append([
            "type": "field",
            "domain": ["raw.githubusercontent.com"],
            "outboundTag": "direct"
        ])
        
        // 动态规则：其他域名
        if !domains.isEmpty {
            rs.append([
                "type": "field",
                "domain": domains,
                "outboundTag": "direct"
            ])
        }
        
        debugPrint("[Request] rules count: \(rs.count), rules: \(rs)")
        return rs
    }
    
    private func mergeRoute(_ config: [String: Any], rules: [[String: Any]]) -> [String: Any] {
        var cfg = config
        
        if cfg["routing"] == nil {
            cfg["routing"] = [
                "domainStrategy": "AsIs",
                "rules": rules
            ]
        } else if var routing = cfg["routing"] as? [String: Any] {
            routing["rules"] = rules
            cfg["routing"] = routing
        }
        
        return cfg
    }
    
    // MARK: - 配置持久化
    
    private func saveGroup(_ config: String) async {
        let userDefaults = UserDefaults(suiteName: SharedConfig.storageGroup)
        userDefaults?.set(Date(), forKey: SharedConfig.timeKey)
        userDefaults?.set(config, forKey: SharedConfig.dataKey)
        userDefaults?.synchronize()
        debugPrint("[Request] saved to group")
    }
}

