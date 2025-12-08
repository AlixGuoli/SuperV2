//
//  EventReporter.swift
//  CoreVPN
//
//  事件上报服务（连接事件、广告事件、状态上报）
//

import Foundation

final class EventReporter {
    
    static let shared = EventReporter()
    private init() {}
    
    // MARK: - 配置常量
    
    private static let timeout: TimeInterval = 15
    private static let deviceType = "iPhone"
    
    // MARK: - 事件类型常量（与后台定义一致，不能改）
    
    static let evtStart = "start_connect"
    static let evtFail = "connect_failed"
    static let evtSuccess = "connect_success"
    static let evtDisconnect = "disconnect"
    static let evtAdStart = "start_get_ad"
    static let evtAdSuccess = "get_ad_success"
    static let evtAdShow = "show_ad"
    
    // MARK: - 连接事件上报
    
    /// 上报连接事件
    /// - Parameters:
    ///   - moment: 事件类型（evtStart/evtFail/evtSuccess/evtDisconnect）
    ///   - ip: IP地址（可选）
    ///   - sid: 会话ID（可选）
    func sendConnEvent(moment: String, ip: String? = nil, sid: String? = nil) {
        let time = getTimeStamp()
        let code = "\(time)-\(sid ?? "")"
        
        let msg: String
        switch moment {
        case EventReporter.evtStart:
            msg = "\(EventReporter.evtStart),\(code),0.0.0.0"
        case EventReporter.evtFail:
            msg = "\(EventReporter.evtFail),\(code),\(ip ?? "0.0.0.0")"
        case EventReporter.evtSuccess:
            msg = "\(EventReporter.evtSuccess),0,\(code),\(ip ?? "0.0.0.0")"
        default:
            debugPrint("[Report] [连接事件] 未知类型: \(moment)")
            return
        }
        
        postLog(msg: msg, eventType: moment)
    }
    
    // MARK: - 广告事件上报
    
    /// 上报广告事件
    /// - Parameters:
    ///   - moment: 事件类型（evtAdStart/evtAdSuccess/evtAdShow）
    ///   - key: 广告Key（可选）
    ///   - adMoment: 广告时刻（可选）
    func sendAdEvent(moment: String, key: String? = nil, adMoment: String? = nil) {
        let ip = getCurrentIP()
        
        let msg: String
        switch moment {
        case EventReporter.evtAdStart:
            msg = "\(EventReporter.evtAdStart),\(adMoment ?? ""),\(ip),ad"
        case EventReporter.evtAdSuccess:
            msg = "\(EventReporter.evtAdSuccess),\(adMoment ?? ""),\(ip),ad,\(key ?? "")"
        case EventReporter.evtAdShow:
            msg = "\(EventReporter.evtAdShow),\(adMoment ?? ""),\(ip),ad,\(key ?? "empty")"
        default:
            debugPrint("[Report] [广告事件] 未知类型: \(moment)")
            return
        }
        
        postLog(msg: msg, eventType: moment)
    }
    
    // MARK: - 状态上报
    
    /// 上报服务状态
    /// - Parameter success: 是否成功（true=0, false=1）
    func sendStatus(success: Bool) {
        Task.detached {
            guard let endpoint = DomainConfigStore.shared.loadActiveConfig()?.api.generalReportURL else {
                debugPrint("[Report] [状态上报] ❌ 无上报端点")
                return
            }
            
            let statusCode = success ? "0" : "1"
            guard let url = self.makeStatusURL(endpoint: endpoint, status: statusCode) else {
                debugPrint("[Report] [状态上报] ❌ URL构建失败")
                return
            }
            
            let requestId = String(UUID().uuidString.prefix(8))
            debugPrint("[Report] [状态上报] [\(requestId)] 开始 | status: \(statusCode) | URL: \(url)")
            await self.httpRequest(urlString: url, type: "状态上报", requestId: requestId)
        }
    }
    
    // MARK: - 私有方法
    
    /// 发送日志上报
    private func postLog(msg: String, eventType: String) {
        Task.detached {
            guard let endpoint = DomainConfigStore.shared.loadActiveConfig()?.api.connectReportURL,
                  !endpoint.isEmpty else {
                debugPrint("[Report] [日志上报] ❌ 无上报端点")
                return
            }
            
            guard let url = self.makeLogURL(endpoint: endpoint, message: msg) else {
                debugPrint("[Report] [日志上报] ❌ URL构建失败")
                return
            }
            
            let requestId = String(UUID().uuidString.prefix(8))
            debugPrint("[Report] [日志上报] [\(requestId)] 开始 | 事件: \(eventType) | URL: \(url)")
            await self.httpRequest(urlString: url, type: "日志上报", requestId: requestId)
        }
    }
    
    /// 构建状态上报URL
    private func makeStatusURL(endpoint: String, status: String) -> String? {
        let baseURL = endpoint + "/report_total"
        guard var components = URLComponents(string: baseURL) else { return nil }
        
        let ctx = APIRequestExecutor.shared.commonContextProvider()
        components.queryItems = [
            URLQueryItem(name: "name", value: "getService"),
            URLQueryItem(name: "cty", value: ctx.country),
            URLQueryItem(name: "pk", value: ctx.pk),
            URLQueryItem(name: "v", value: ctx.version),
            URLQueryItem(name: "asn", value: "0"),
            URLQueryItem(name: "isf", value: status),
            URLQueryItem(name: "cnt", value: "1")
        ]
        
        return components.url?.absoluteString
    }
    
    /// 构建日志上报URL
    private func makeLogURL(endpoint: String, message: String) -> String? {
        guard var components = URLComponents(string: endpoint) else { return nil }
        
        let ctx = APIRequestExecutor.shared.commonContextProvider()
        components.queryItems = [
            URLQueryItem(name: "imei", value: ctx.uid),
            URLQueryItem(name: "country", value: ctx.country),
            URLQueryItem(name: "lang", value: ctx.language),
            URLQueryItem(name: "mobile", value: EventReporter.deviceType),
            URLQueryItem(name: "pk", value: ctx.pk),
            URLQueryItem(name: "version", value: ctx.version),
            URLQueryItem(name: "info", value: message)
        ]
        
        return components.url?.absoluteString
    }
    
    /// 发送HTTP请求
    private func httpRequest(urlString: String, type: String, requestId: String) async {
        guard let url = URL(string: urlString) else {
            debugPrint("[Report] [\(type)] [\(requestId)] ❌ URL无效")
            return
        }
        
        // 原代码中 timeoutInterval 被注释，但保留了 TIMEOUT 常量定义
        // 为了保持完全一致，这里也注释掉超时设置
        // let request = URLRequest(url: url, timeoutInterval: EventReporter.timeout)
        let request = URLRequest(url: url)
        let startTime = Date()
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            let duration = Date().timeIntervalSince(startTime)
            let httpResponse = response as! HTTPURLResponse
            
            if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                debugPrint("[Report] [\(type)] [\(requestId)] ✅ 成功 | status: \(httpResponse.statusCode) | 耗时: \(String(format: "%.2f", duration))s | URL: \(url)")
            } else {
                debugPrint("[Report] [\(type)] [\(requestId)] ❌ 失败 | status: \(httpResponse.statusCode) | 耗时: \(String(format: "%.2f", duration))s | URL: \(url)")
            }
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            debugPrint("[Report] [\(type)] [\(requestId)] ❌ 异常 | error: \(error.localizedDescription) | 耗时: \(String(format: "%.2f", duration))s | URL: \(url)")
        }
    }
    
    /// 获取当前连接的IP
    private func getCurrentIP() -> String {
        // 检查连接状态：通过 TunnelService 检查系统连接状态
        let isConnected = TunnelService.shared().tunnelProvider.connection.status == .connected
        
        if isConnected {
            let ip = ServiceConfigStore.shared.ipService
            return (ip?.isEmpty == false) ? ip! : "0.0.0.0"
        } else {
            return "local"
        }
    }
    
    /// 生成时间戳（格式：MMddHHmmss）
    private func getTimeStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMddHHmmss"
        return formatter.string(from: Date())
    }
    
    /// 生成随机ID（8位UUID前缀）
    static func makeRandomId() -> String {
        return String(UUID().uuidString.prefix(8))
    }
}

