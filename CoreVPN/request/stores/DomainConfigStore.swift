//
//  DomainConfigStore.swift
//  CoreVPN
//
//  负责从 UserDefaults / 本地 core.tun / git 源维护域名与上报配置
//

import Foundation

final class DomainConfigStore {

    static let shared = DomainConfigStore()

    private init() {}

    private struct Keys {
        static let storedConfig = "DomainConfigStore.StoredConfig.v73"
    }

    // MARK: - Public

    /// 返回当前可用的配置：
    /// 1. 优先读取 UserDefaults 中已保存的配置
    /// 2. 若没有或解析失败，则从 bundle 中的 core.tun 解密，并保存到 UserDefaults
    func loadActiveConfig() -> DomainConfig? {
        if let fromUD = loadConfigFromUserDefaults() {
            debugPrint("[Request] 域名配置来源：UserDefaults")
            return fromUD
        }
        // 回落到 bundle 默认配置
        if let fromBundle = loadConfigFromBundle() {
            saveConfigToUserDefaults(fromBundle)
            debugPrint("[Request] 域名配置来源：bundle/core.tun（已写入 UserDefaults）")
            return fromBundle
        }
        debugPrint("[Request] 域名配置加载失败：UD 和 bundle 均无有效配置")
        return nil
    }

    /// 使用当前配置中的 git 源尝试拉取新配置：
    /// 1. 先从 UserDefaults 中读取配置，使用其 git 列表
    /// 2. 若 UD 没有配置或 git 列表为空，再从 bundle 默认配置中读取 git 列表
    /// 3. 成功时更新 UserDefaults 中保存的域名配置
    func refreshConfigFromGit(completion: @escaping (Result<DomainConfig, Error>) -> Void) {
        debugPrint("[Request] 开始通过 Git 更新域名配置")
        
        // 先从 UD 读取配置
        var gitSources: [String] = []
        if let udConfig = loadConfigFromUserDefaults() {
            gitSources = udConfig.api.gitSources
            debugPrint("[Request] Git 源来源：UserDefaults，数量：\(gitSources.count)")
        }
        
        // 如果 UD 没有或 git 列表为空，再从 bundle 读取
        if gitSources.isEmpty {
            if let bundleConfig = loadConfigFromBundle() {
                gitSources = bundleConfig.api.gitSources
                debugPrint("[Request] Git 源来源：bundle/core.tun，数量：\(gitSources.count)")
            }
        }
        
        guard !gitSources.isEmpty else {
            debugPrint("[Request] Git 更新失败：没有任何 git 源可用")
            completion(.failure(NSError(domain: "DomainConfigStore",
                                        code: -2,
                                        userInfo: [NSLocalizedDescriptionKey: "No git sources"])))
            return
        }

        attemptUpdateFromGit(sources: gitSources, index: 0, completion: completion)
    }

    // MARK: - Private helpers

    private func loadConfigFromUserDefaults() -> DomainConfig? {
        guard let json = UserDefaults.standard.string(forKey: Keys.storedConfig),
              !json.isEmpty,
              let data = json.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(DomainConfig.self, from: data)
    }

    private func saveConfigToUserDefaults(_ config: DomainConfig) {
        guard let data = try? JSONEncoder().encode(config),
              let json = String(data: data, encoding: .utf8) else {
            return
        }
        UserDefaults.standard.set(json, forKey: Keys.storedConfig)
    }

    /// 解密并解析 bundle 里的 core.tun 默认配置
    private func loadConfigFromBundle() -> DomainConfig? {
        guard let url = Bundle.main.url(forResource: "core", withExtension: "tun") else {
            return nil
        }
        guard let raw = try? String(contentsOf: url, encoding: .utf8),
              !raw.isEmpty else {
            return nil
        }
        // 目前 core.tun 假定只有一行
        let line = raw.split(whereSeparator: \.isNewline).first.map(String.init) ?? raw
        debugPrint("[Request] 从 bundle 读取 core.tun 原始加密内容：\(line)")
        guard let jsonString = SecureConfigDecoder.decodeConfigPayload(line),
              let data = jsonString.data(using: .utf8) else {
            return nil
        }
        debugPrint("[Request] core.tun 解密后 JSON：\(jsonString)")
        let config = try? JSONDecoder().decode(DomainConfig.self, from: data)
        if config != nil {
            debugPrint("[Request] 域名配置已写入 UserDefaults")
        }
        return config
    }

    /// 按顺序尝试多个 git 源，直到成功或全部失败
    private func attemptUpdateFromGit(
        sources: [String],
        index: Int,
        completion: @escaping (Result<DomainConfig, Error>) -> Void
    ) {
        guard index < sources.count else {
            let error = NSError(
                domain: "DomainConfigStore",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: "All git sources failed"]
            )
            debugPrint("[Request] Git 更新失败：所有 git 源均无法获取配置")
            completion(.failure(error))
            return
        }

        let gitURLString = sources[index]
        fetchConfigFromGit(urlString: gitURLString) { [weak self] config in
            guard let self = self else { return }
            if let config = config {
                self.saveConfigToUserDefaults(config)
                debugPrint("[Request] Git 更新成功，来源：\(gitURLString)，域名配置已写入 UserDefaults")
                completion(.success(config))
            } else {
                self.attemptUpdateFromGit(sources: sources, index: index + 1, completion: completion)
            }
        }
    }

    /// 从单个 git URL 拉取加密配置并解密为 DomainConfig
    private func fetchConfigFromGit(
        urlString: String,
        completion: @escaping (DomainConfig?) -> Void
    ) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }

        debugPrint("[Request] 准备从 Git 拉取配置：\(urlString)")
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0

        var isCompleted = false
        // 打印 5 秒倒计时，帮助确认超时逻辑
        DispatchQueue.global().async {
            for i in (1...5).reversed() {
                if isCompleted { break }
                debugPrint("[Request] Git 请求倒计时：\(i) 秒")
                Thread.sleep(forTimeInterval: 1.0)
            }
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            isCompleted = true
            guard error == nil,
                  let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode),
                  let data = data,
                  let encryptedString = String(data: data, encoding: .utf8),
                  !encryptedString.isEmpty,
                  let jsonString = SecureConfigDecoder.decodeConfigPayload(encryptedString),
                  let jsonData = jsonString.data(using: .utf8),
                  let config = try? JSONDecoder().decode(DomainConfig.self, from: jsonData) else {
                debugPrint("[Request] 从 Git 拉取配置失败：\(urlString)")
                completion(nil)
                return
            }
            debugPrint("[Request] 从 Git 拉取配置成功：\(urlString)")
            debugPrint("[Request] Git 返回加密内容：\(String(data: data, encoding: .utf8) ?? "<非 UTF8 数据>")")
            debugPrint("[Request] Git 解密后 JSON：\(jsonString)")
            completion(config)
        }
        task.resume()
    }
}

