//
//  APIRequestExecutor.swift
//  CoreVPN
//
//  统一封装接口请求的 4 步流程：
//  1. 获取域名配置（UD 优先，失败读 core.tun）
//  2. 按 host 数组轮询请求，超时 5 秒，状态码 200–300 才算成功
//  3. 全部 host 失败时，通过 git 源更新配置
//  4. 使用更新后的配置再重试一次
//

import Foundation
import Alamofire

final class APIRequestExecutor {

    static let shared = APIRequestExecutor()

    /// 由外部注入如何获取基础参数（uid/country/language/pk/version）
    var commonContextProvider: () -> CommonRequestContext = {
        let defaults = UserDefaults.standard
        let uidKey = "CoreVPN.Request.UID"

        let uid: String = {
            if let existing = defaults.string(forKey: uidKey), !existing.isEmpty {
                return existing
            }
            let value = UUID().uuidString
            defaults.set(value, forKey: uidKey)
            return value
        }()

        // 获取国家代码：使用 region?.identifier，然后 lowercased
        /// 测试服
        let country = "ru"
        //let country = (Locale.current.region?.identifier ?? "us").lowercased()

        // 获取语言代码：使用 language.languageCode?.identifier
        let languageCode = Locale.current.language.languageCode?.identifier ?? "en"

        /// 测试服
        let pk = "CatVPN.CatVPN"
        //let pk = bundle.bundleIdentifier ?? "com.vpn.kernel.core.hex"
        
        
        let version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0.0"

        return CommonRequestContext(
            uid: uid,
            country: country,
            language: languageCode,
            pk: pk,
            version: version
        )
    }

    private init() {}

    // MARK: - Public

    /// 通用请求入口：返回原始 Data（上层再去做 JSON 解析和存储）
    func performRequest(
        endpoint: APIEndpoint,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        guard let config = DomainConfigStore.shared.loadActiveConfig() else {
            let error = NSError(
                domain: "APIRequestExecutor",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No domain configuration available"]
            )
            completion(.failure(error))
            return
        }

        attemptRequest(with: config, endpoint: endpoint) { [weak self] result in
            switch result {
            case .success:
                completion(result)
            case .failure:
                self?.refreshConfigAndRetry(endpoint: endpoint, completion: completion)
            }
        }
    }

    // MARK: - Private

    /// 单轮：使用给定 DomainConfig 的 hosts 列表进行请求轮询
    private func attemptRequest(
        with config: DomainConfig,
        endpoint: APIEndpoint,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        var hosts = config.api.hosts
        
        // ========== 测试超时功能开关 ==========
        // 设置为 true 时，会直接替换 hosts 数组用于测试超时
        // 测试完成后记得改回 false！
        let testTimeoutEnabled = false
        if testTimeoutEnabled {
            hosts = ["https://httpbin.org/delay/10"]
        }
        // ====================================
        
        guard !hosts.isEmpty else {
            let error = NSError(
                domain: "APIRequestExecutor",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Empty host list"]
            )
            completion(.failure(error))
            return
        }

        let context = commonContextProvider()
        attemptRequest(on: hosts, index: 0, endpoint: endpoint, context: context, completion: completion)
    }

    /// 递归在 hosts 列表中轮询请求
    private func attemptRequest(
        on hosts: [String],
        index: Int,
        endpoint: APIEndpoint,
        context: CommonRequestContext,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        guard index < hosts.count else {
            let error = NSError(
                domain: "APIRequestExecutor",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: "All hosts failed"]
            )
            completion(.failure(error))
            return
        }

        let host = hosts[index]
        guard let urlString = buildURL(host: host, endpoint: endpoint, context: context),
              let url = URL(string: urlString) else {
            debugPrint("[Request] 构造 URL 失败，跳过 host[\(index)] = \(host)")
            attemptRequest(on: hosts, index: index + 1, endpoint: endpoint, context: context, completion: completion)
            return
        }

        debugPrint("[Request] 准备请求域名：\(host)  完整URL：\(urlString)")
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0

        var isCompleted = false
        // 打印接口请求 5 秒倒计时，帮助确认超时逻辑
        DispatchQueue.global().async {
            for i in (1...5).reversed() {
                if isCompleted { break }
                debugPrint("[Request] 接口请求倒计时：\(i) 秒")
                Thread.sleep(forTimeInterval: 1.0)
            }
        }

        // 目前所有接口按 GET 带 query 参数处理，后续如有 POST 再扩展
        AF.request(request)
            .validate { _, response, _ in
                // 只接受 200–300 状态码
                let code = response.statusCode
                return (200...300).contains(code) ? .success(()) : .failure(AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: code)))
            }
            .responseData { [weak self] response in
                isCompleted = true
                switch response.result {
                case .success(let data):
                    debugPrint("[Request] 请求成功，域名：\(host)，完整URL：\(urlString)")
                    completion(.success(data))
                case .failure(let error):
                    // 区分不同类型的失败原因
                    var errorType = "未知错误"
                    if let afError = error.asAFError {
                        switch afError {
                        case .sessionTaskFailed(let sessionError):
                            if let urlError = sessionError as? URLError {
                                switch urlError.code {
                                case .timedOut:
                                    errorType = "超时失败"
                                case .notConnectedToInternet, .networkConnectionLost:
                                    errorType = "网络连接失败"
                                default:
                                    errorType = "网络错误: \(urlError.localizedDescription)"
                                }
                            } else {
                                errorType = "会话任务失败: \(sessionError.localizedDescription)"
                            }
                        case .responseValidationFailed(let reason):
                            if case .unacceptableStatusCode(let code) = reason {
                                errorType = "状态码错误: \(code)"
                            } else {
                                errorType = "响应验证失败: \(reason)"
                            }
                        default:
                            errorType = "请求失败: \(afError.localizedDescription)"
                        }
                    } else {
                        errorType = "请求失败: \(error.localizedDescription)"
                    }
                    debugPrint("[Request] 请求失败，域名：\(host)，失败原因：\(errorType)，尝试下一个")
                    self?.attemptRequest(on: hosts, index: index + 1, endpoint: endpoint, context: context, completion: completion)
                }
            }
    }

    /// hosts 全部失败后，通过 git 更新配置并重试一次
    private func refreshConfigAndRetry(
        endpoint: APIEndpoint,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        debugPrint("[Request] 所有域名失败，开始通过 Git 刷新配置并重试")
        DomainConfigStore.shared.refreshConfigFromGit { [weak self] result in
            switch result {
            case .failure(let error):
                debugPrint("[Request] Git 刷新配置失败：\(error.localizedDescription)")
                completion(.failure(error))
            case .success(let newConfig):
                guard let self = self else { return }
                let context = self.commonContextProvider()
                debugPrint("[Request] Git 刷新配置成功，使用新配置重新发起请求")
                self.attemptRequest(with: newConfig, endpoint: endpoint, completion: completion)
            }
        }
    }

    /// 构造完整 URL 字符串（host + path + ?query）
    private func buildURL(
        host: String,
        endpoint: APIEndpoint,
        context: CommonRequestContext
    ) -> String? {
        // 规范化 host 与 path 的拼接，避免重复或缺失 '/'
        let trimmedHost = host.hasSuffix("/") ? String(host.dropLast()) : host
        let normalizedPath = endpoint.path.hasPrefix("/") ? endpoint.path : "/" + endpoint.path
        let base = trimmedHost + normalizedPath

        var components = URLComponents(string: base)

        // 基础参数
        var params: [String: Any] = [
            "uid": context.uid,
            "country": context.country,
            "language": context.language,
            "pk": context.pk,
            "version": context.version
        ]

        // 合并业务参数，业务参数覆盖基础参数
        endpoint.extraParams.forEach { key, value in
            params[key] = value
        }

        components?.queryItems = params.map { key, value in
            URLQueryItem(name: key, value: String(describing: value))
        }

        return components?.url?.absoluteString
    }
}


