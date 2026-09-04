import Foundation

enum ServiceConfigSource: String {
    case request
    case cache
}

final class ServiceService {
    static let shared = ServiceService()

    private let store = ServiceConfigStore.shared
    private init() {}

    @discardableResult
    func fetchServiceConfig(
        group: Int = -1,
        vip: Int = 0,
        sessionID: String,
        commit: (_ changes: () -> Bool) -> Bool = { $0() }
    ) async -> Bool {
        store.isFromRequest = true
        let endpoint = APIEndpoint(
            path: APIEndpoint.serviceBatchPath,
            extraParams: ["group": group, "vip": vip]
        )
        let requested = await request(endpoint)
        EventReporter.shared.sendStatus(success: requested != nil)

        var selectedCipher: String?
        var selectedPackage: TunnelConfigPackage?
        var source: ServiceConfigSource = .request
        if let requested,
           let decoded = decodeBatch(requested),
           let package = try? CFGPipeline.shared.makeTunnelPackage(from: decoded) {
            selectedCipher = requested
            selectedPackage = package
        } else if let cached = store.getServiceConfig(),
                  let decoded = decodeBatch(cached),
                  let package = try? CFGPipeline.shared.makeTunnelPackage(from: decoded) {
            selectedCipher = cached
            selectedPackage = package
            source = .cache
        }

        guard let cipher = selectedCipher,
              let package = selectedPackage,
              let defaults = UserDefaults(suiteName: SharedConfig.storageGroup),
              let domain = DomainConfigStore.shared.loadActiveConfig(),
              !domain.api.connectReportURL.isEmpty else {
            debugPrint("[Request] Batch 接口与成功缓存均不可用")
            return false
        }
        printConfiguration(cipher, label: "加密原文", source: source)
        printConfiguration(package.text, label: "Tunnel 最终 JSON", source: source)

        let requestContext = APIRequestExecutor.shared.commonContextProvider()
        let reportContext = ConnectionReportSeed(
            endpoint: domain.api.connectReportURL,
            uid: requestContext.uid,
            country: requestContext.country,
            language: requestContext.language,
            packageName: requestContext.apiPackageName,
            version: requestContext.version,
            sessionID: sessionID,
            usesCache: source == .cache
        )
        guard let contextData = try? JSONEncoder().encode(reportContext) else { return false }
        let probeURL = selectProbeURL()

        return commit {
            self.store.prepare(cipher: cipher, source: source, firstIP: package.firstServerAddress)
            defaults.set(package.text, forKey: SharedConfig.batchDataKey)
            defaults.set(probeURL, forKey: SharedConfig.probeURLKey)
            defaults.set(Date(), forKey: SharedConfig.timeKey)
            defaults.set(source.rawValue, forKey: SharedConfig.sourceKey)
            defaults.set(contextData, forKey: SharedConfig.reportContextKey)
            defaults.removeObject(forKey: SharedConfig.reportKey)
#if DEBUG
            defaults.removeObject(forKey: SharedConfig.extensionLogKey)
#endif
            defaults.synchronize()
            return true
        }
    }

    func commitSuccessfulRequest() { store.commitPreparedConfig() }
    func discardPreparedConfig() { store.discardPreparedConfig() }

    private func request(_ endpoint: APIEndpoint) async -> String? {
        await withCheckedContinuation { continuation in
            APIRequestExecutor.shared.performRequest(endpoint: endpoint) { result in
                switch result {
                case .success(let data):
                    let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(returning: text?.isEmpty == false ? text : nil)
                case .failure(let error):
                    debugPrint("[Request] Batch 请求失败：\(error.localizedDescription)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func decodeBatch(_ raw: String) -> String? {
        if RequestUtils.validateJsonString(raw) { return raw }
        guard let decoded = SecureConfigDecoder.decodeConfigPayload(raw),
              RequestUtils.validateJsonString(decoded) else { return nil }
        return decoded
    }

    private func selectProbeURL() -> String {
        let valid = (AppConfigStore.shared.detectionServerList() ?? []).filter { value in
            guard let url = URL(string: value),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https",
                  url.host?.isEmpty == false,
                  url.user == nil,
                  url.password == nil else { return false }
            return true
        }
        return valid.randomElement() ?? "https://www.google.com/generate_204"
    }

    private func printConfiguration(
        _ config: String,
        label: String,
        source: ServiceConfigSource
    ) {
#if DEBUG
        debugPrint("[Service Config][\(source.rawValue)] \(label):")
        print(config)
#endif
    }
}
