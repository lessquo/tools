import Foundation
import Security

@Observable
@MainActor
final class APIKeyStore {

    enum Provider: String, CaseIterable, Identifiable {
        case anthropic
        case google
        case openai

        var id: String { rawValue }

        var label: String {
            switch self {
            case .anthropic: "Anthropic"
            case .google: "Google"
            case .openai: "OpenAI"
            }
        }

        var apiKeyName: String {
            switch self {
            case .anthropic: "ANTHROPIC_API_KEY"
            case .google: "GOOGLE_API_KEY"
            case .openai: "OPENAI_API_KEY"
            }
        }
    }

    enum FetchState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    var apiKeys: [Provider: String] = [:]
    var fetchStates: [Provider: FetchState] = [:]

    init() {
        for provider in Provider.allCases {
            apiKeys[provider] = Keychain.read(provider.apiKeyName) ?? ""
            fetchStates[provider] = .idle
        }
    }

    func setAPIKey(_ key: String, for provider: Provider) {
        apiKeys[provider] = key
    }

    func saveAPIKey(for provider: Provider) {
        let key = apiKeys[provider] ?? ""
        if key.isEmpty {
            Keychain.delete(provider.apiKeyName)
        } else {
            Keychain.write(key, for: provider.apiKeyName)
        }
    }

    func fetchModels(for provider: Provider) async {
        let key = apiKeys[provider] ?? ""
        guard !key.isEmpty else {
            fetchStates[provider] = .idle
            return
        }
        fetchStates[provider] = .loading
        do {
            _ = try await performFetch(provider: provider, key: key)
            fetchStates[provider] = .loaded
        } catch {
            fetchStates[provider] = .failed(error.localizedDescription)
        }
    }

    private func performFetch(provider: Provider, key: String) async throws -> [String] {
        switch provider {
        case .anthropic:
            var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/models")!)
            req.setValue(key, forHTTPHeaderField: "x-api-key")
            req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            struct Response: Decodable { let data: [Item]; struct Item: Decodable { let id: String } }
            return try await decode(Response.self, request: req).data.map(\.id)
        case .google:
            let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?key=\(key)")!
            struct Response: Decodable { let models: [Item]; struct Item: Decodable { let name: String } }
            return try await decode(Response.self, request: URLRequest(url: url))
                .models.map { $0.name.replacingOccurrences(of: "models/", with: "") }
        case .openai:
            var req = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
            req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            struct Response: Decodable { let data: [Item]; struct Item: Decodable { let id: String } }
            return try await decode(Response.self, request: req).data.map(\.id)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            throw NSError(
                domain: "APIKeyStore", code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"]
            )
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

enum Keychain {
    private static let service = Bundle.main.bundleIdentifier!

    private static func baseQuery(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true,
            kSecAttrSynchronizable as String: kCFBooleanTrue!,
        ]
    }

    static func read(_ account: String) -> String? {
        var query = baseQuery(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(_ value: String, for account: String) {
        let data = Data(value.utf8)
        let query = baseQuery(account)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            for (k, v) in attributes { addQuery[k] = v }
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    static func delete(_ account: String) {
        SecItemDelete(baseQuery(account) as CFDictionary)
    }
}
