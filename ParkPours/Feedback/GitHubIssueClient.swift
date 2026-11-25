import Foundation
import Security

/// Where in-app bug reports go.
enum FeedbackConfig {
    static let owner = "dustinanglin"
    static let repo = "parkpours"
    /// Screenshots are committed to this branch and linked from the issue,
    /// because GitHub's API has no way to attach an image to an issue.
    static let screenshotBranch = "feedback-screenshots"
    static let label = "in-app-feedback"
}

/// The GitHub token lives in the Keychain on the device, never in the repo.
enum TokenStore {
    private static let base: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "parkpours.feedback",
        kSecAttrAccount as String: "github-token"
    ]

    static func load() -> String? {
        var query = base
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8),
              !token.isEmpty else { return nil }
        return token
    }

    @discardableResult
    static func save(_ token: String) -> Bool {
        clear()
        var attributes = base
        attributes[kSecValueData as String] = Data(token.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    static func clear() {
        SecItemDelete(base as CFDictionary)
    }
}

struct FiledIssue {
    let number: Int
    let url: URL?
}

enum FeedbackError: LocalizedError {
    case badResponse
    case http(status: Int, message: String, step: String)

    var errorDescription: String? {
        switch self {
        case .badResponse:
            return "GitHub sent a response the app could not read."
        case .http(let status, let message, let step):
            var text = "\(step) failed (HTTP \(status))."
            if !message.isEmpty {
                text += " \(message)"
            }
            if status == 401 {
                text += " The token is invalid or expired."
            } else if status == 403 || status == 404 {
                text += " Check that the token covers this repo with Issues and Contents set to read and write."
            }
            return text
        }
    }
}

struct GitHubIssueClient {
    let token: String

    /// Uploads the screenshot (if any), then files the issue.
    func fileIssue(title: String, details: String, screenshotJPEG: Data?, context: [String]) async throws -> FiledIssue {
        var body = details
        if let screenshotJPEG {
            let imageURL = try await uploadScreenshot(screenshotJPEG)
            body += "\n\n![Screenshot](\(imageURL))"
        }
        body += "\n\n---\n" + context.map { "- \($0)" }.joined(separator: "\n")
        body += "\n\n_Filed from the app._"

        let payload: [String: Any] = [
            "title": title,
            "body": body,
            "labels": [FeedbackConfig.label]
        ]
        let result = try await send("POST", "issues", payload, step: "Filing the issue")
        guard let number = result["number"] as? Int else {
            throw FeedbackError.badResponse
        }
        let link = (result["html_url"] as? String).flatMap { URL(string: $0) }
        return FiledIssue(number: number, url: link)
    }

    private func uploadScreenshot(_ jpeg: Data) async throws -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let suffix = UUID().uuidString.prefix(8).lowercased()
        let path = "screenshots/\(formatter.string(from: Date()))-\(suffix).jpg"

        let payload: [String: Any] = [
            "message": "Add in-app feedback screenshot",
            "content": jpeg.base64EncodedString(),
            "branch": FeedbackConfig.screenshotBranch
        ]
        let result = try await send("PUT", "contents/\(path)", payload, step: "Uploading the screenshot")
        if let content = result["content"] as? [String: Any],
           let download = content["download_url"] as? String {
            return download
        }
        return "https://raw.githubusercontent.com/\(FeedbackConfig.owner)/\(FeedbackConfig.repo)/\(FeedbackConfig.screenshotBranch)/\(path)"
    }

    func send(_ method: String, _ path: String, _ payload: [String: Any]?, step: String) async throws -> [String: Any] {
        let base = "https://api.github.com/repos/\(FeedbackConfig.owner)/\(FeedbackConfig.repo)/"
        guard let url = URL(string: base + path) else {
            throw FeedbackError.badResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 60
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if let payload {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw FeedbackError.badResponse
        }
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard (200..<300).contains(http.statusCode) else {
            throw FeedbackError.http(
                status: http.statusCode,
                message: object["message"] as? String ?? "",
                step: step
            )
        }
        return object
    }
}
