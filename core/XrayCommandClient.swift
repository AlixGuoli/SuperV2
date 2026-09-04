import Foundation

enum XrayCommandError: LocalizedError {
    case requestEncoding
    case emptyResponse
    case invalidResponse
    case rejected(String)

    var errorDescription: String? {
        switch self {
        case .requestEncoding:
            return "Unable to encode Xray request"
        case .emptyResponse:
            return "Xray returned no response"
        case .invalidResponse:
            return "Xray returned invalid JSON"
        case .rejected(let message):
            return message
        }
    }
}

/// New core exposes one process-wide C entry point. Serialize every call and
/// keep allocation ownership at this boundary so callers only handle Swift values.
enum XrayCommandClient {
    private static let callLock = NSLock()

    static func execute(method: String, payload: [String: Any]) throws -> [String: Any] {
        let request: [String: Any] = [
            "apiVersion": 2,
            "method": method,
            "payload": payload
        ]
        let data = try JSONSerialization.data(withJSONObject: request)
        guard let json = String(data: data, encoding: .utf8),
              let requestBuffer = strdup(json) else {
            throw XrayCommandError.requestEncoding
        }
        defer { free(requestBuffer) }

        callLock.lock()
        defer { callLock.unlock() }

        guard let responseBuffer = CGoInvoke(requestBuffer) else {
            throw XrayCommandError.emptyResponse
        }
        defer { CGoFree(responseBuffer) }

        let responseText = String(cString: responseBuffer)
        guard let responseData = responseText.data(using: .utf8),
              let response = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            throw XrayCommandError.invalidResponse
        }
        guard response["success"] as? Bool == true else {
            throw XrayCommandError.rejected(response["error"] as? String ?? "Xray command failed")
        }
        return response
    }
}
