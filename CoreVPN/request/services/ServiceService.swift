import Foundation

/// 单节点服务配置：当前用于验证新核心库，Batch 链路后续再接入。
final class ServiceService {

    static let shared = ServiceService()

    private init() {}

    @discardableResult
    func fetchServiceConfig(group: Int = -1, vip: Int = 0) async -> Bool {
        let endpoint = APIEndpoint(
            path: "/poplar/service/timber",
            extraParams: ["group": group, "vip": vip]
        )

        if let raw = await request(endpoint),
           let json = decodeServiceConfig(raw),
           await storeForTunnel(json) {
            let store = ServiceConfigStore.shared
            store.nowServiceCF = raw
            store.isFromRequest = true
            store.scanCfg(input: json, isValid: true)
            EventReporter.shared.sendStatus(success: true)
            return true
        }

        let store = ServiceConfigStore.shared
        store.isFromRequest = false
        EventReporter.shared.sendStatus(success: false)

        guard let cached = store.getServiceConfig(),
              let json = decodeServiceConfig(cached),
              await storeForTunnel(json) else {
            clearTunnelConfig()
            debugPrint("[Request] 单节点服务配置与缓存均不可用")
            return false
        }

        store.nowServiceCF = cached
        store.scanCfg(input: json, isValid: false)
        return true
    }

    private func request(_ endpoint: APIEndpoint) async -> String? {
        await withCheckedContinuation { continuation in
            APIRequestExecutor.shared.performRequest(endpoint: endpoint) { result in
                switch result {
                case .success(let data):
                    let text = String(data: data, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(returning: text?.isEmpty == false ? text : nil)
                case .failure(let error):
                    debugPrint("[Request] 服务配置请求失败：\(error.localizedDescription)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// 当前 timber 接口返回加密配置；同时容忍直接 JSON，方便联调。
    private func decodeServiceConfig(_ raw: String) -> String? {
        if RequestUtils.validateJsonString(raw) {
            return raw
        }
        guard let decoded = SecureConfigDecoder.decodeConfigPayload(raw),
              RequestUtils.validateJsonString(decoded) else {
            return nil
        }
        return decoded
    }

    private func storeForTunnel(_ json: String) async -> Bool {
        do {
            try await CFGPipeline.shared.storeCfg(serviceConfig: json)
            return true
        } catch {
            debugPrint("[Request] 服务配置写入 App Group 失败：\(error.localizedDescription)")
            return false
        }
    }

    private func clearTunnelConfig() {
        guard let defaults = UserDefaults(suiteName: SharedConfig.storageGroup) else { return }
        defaults.removeObject(forKey: SharedConfig.dataKey)
        defaults.removeObject(forKey: SharedConfig.timeKey)
        defaults.synchronize()
    }
}
