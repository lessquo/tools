import Foundation
import HuggingFace

@Observable
@MainActor
final class ModelStore {

    // MARK: - Types

    enum ModelKind: Sendable {
        case llm, vlm, stt
    }

    enum DownloadState: Sendable, Equatable {
        case notDownloaded
        case downloading(fractionCompleted: Double)
        case downloaded
    }

    // MARK: - State

    private(set) var models: [HuggingFace.Model] = []
    private(set) var isFetchingCatalog = false
    var downloadStates: [String: DownloadState] = [:]
    private var resolvedPaths: [String: URL] = [:]

    var selectedModelID: String {
        didSet { UserDefaults.standard.set(selectedModelID, forKey: "selectedModelID") }
    }

    // MARK: - Private

    private let client: HubClient
    private let cache: HubCache

    // MARK: - Init

    init() {
        self.client = HubClient.default
        self.cache = HubCache.default
        self.selectedModelID = UserDefaults.standard.string(forKey: "selectedModelID") ?? ""
        Task { await fetchCatalog() }
    }

    // MARK: - Catalog

    func fetchCatalog() async {
        isFetchingCatalog = true
        defer { isFetchingCatalog = false }

        do {
            let response = try await client.listModels(
                author: "mlx-community",
                sort: "downloads",
                direction: .descending,
                limit: 500,
                config: true
            )

            let compatible = response.items.filter { Self.isCompatible($0) }
            guard !compatible.isEmpty else { return }
            models = compatible
            refreshDownloadStates()
        } catch {
            // Keep current list
        }
    }

    // MARK: - Actions

    func download(_ model: HuggingFace.Model) async throws {
        let modelID = model.id.rawValue
        downloadStates[modelID] = .downloading(fractionCompleted: 0)

        let path = try await client.downloadSnapshot(
            of: model.id,
            matching: ["*.safetensors", "*.json", "tokenizer.model"]
        ) { [weak self] progress in
            self?.downloadStates[modelID] = .downloading(
                fractionCompleted: progress.fractionCompleted
            )
        }

        resolvedPaths[modelID] = path
        downloadStates[modelID] = .downloaded

        if !isSelectedModelDownloaded {
            selectedModelID = modelID
        }
    }

    func deleteDownload(_ model: HuggingFace.Model) throws {
        let modelID = model.id.rawValue
        let cacheDir = cache.repoDirectory(repo: model.id, kind: .model)
        if FileManager.default.fileExists(atPath: cacheDir.path()) {
            try FileManager.default.removeItem(at: cacheDir)
        }
        resolvedPaths[modelID] = nil
        downloadStates[modelID] = .notDownloaded
        if selectedModelID == modelID {
            selectedModelID = models.first(where: {
                downloadStates[$0.id.rawValue] == .downloaded
            })?.id.rawValue ?? ""
        }
    }

    // MARK: - Internal

    func modelDirectory(for modelID: String) -> URL {
        resolvedPaths[modelID] ?? cache.repoDirectory(
            repo: Repo.ID(rawValue: modelID)!, kind: .model
        )
    }

    var cacheDirectory: URL { cache.cacheDirectory }

    var selectedModel: HuggingFace.Model? {
        models.first { $0.id.rawValue == selectedModelID }
    }

    var isSelectedModelDownloaded: Bool {
        downloadStates[selectedModelID] == .downloaded
    }

    func refreshDownloadStates() {
        for model in models {
            let modelID = model.id.rawValue
            if let cached = cache.cachedFilePath(
                repo: model.id, kind: .model, revision: "main",
                filename: "config.json"
            ) {
                downloadStates[modelID] = .downloaded
                resolvedPaths[modelID] = cached.deletingLastPathComponent()
            } else {
                downloadStates[modelID] = .notDownloaded
                resolvedPaths[modelID] = nil
            }
        }
    }

    // MARK: - Compatibility

    static let supportedLLMTypes: Set<String> = [
        "mistral", "llama", "phi", "phi3", "phi3small", "phimoe",
        "gemma", "gemma2", "gemma3_text", "gemma3n",
        "qwen2", "qwen3", "qwen3_moe",
        "cohere", "cohere2", "starcoder2", "internlm2", "openelm",
    ]

    static let supportedVLMTypes: Set<String> = [
        "paligemma", "qwen2_vl", "qwen2_5_vl", "qwen3_vl",
        "gemma3", "smolvlm", "pixtral", "mistral3",
    ]

    private static func isCompatible(_ model: HuggingFace.Model) -> Bool {
        let name = model.id.name.lowercased()
        let isWhisper = name.contains("whisper")

        if !isWhisper {
            guard name.contains("4bit") || name.contains("4-bit") else { return false }
            guard !name.contains("8bit"), !name.contains("bf16"),
                  !name.contains("fp16") else { return false }
        }

        let modelType = model.config?["model_type"]?.stringValue
        if isWhisper {
            return true
        } else if let mt = modelType {
            return supportedLLMTypes.contains(mt) || supportedVLMTypes.contains(mt)
        }
        return false
    }
}

// MARK: - HuggingFace.Model Helpers

extension HuggingFace.Model {
    var kind: ModelStore.ModelKind {
        let name = id.name.lowercased()
        if name.contains("whisper") { return .stt }
        if let mt = config?["model_type"]?.stringValue,
           ModelStore.supportedVLMTypes.contains(mt) { return .vlm }
        return .llm
    }

    private static let avatarKeywords: [(keyword: String, asset: String)] = [
        ("qwen", "qwen"),
        ("llama", "meta-llama"),
        ("gemma", "google"),
        ("mistral", "mistralai"),
        ("phi", "microsoft"),
        ("whisper", "openai"),
    ]

    var avatar: String {
        let lower = id.name.lowercased()
        return Self.avatarKeywords.first { lower.contains($0.keyword) }?.asset ?? ""
    }
}

extension Int {
    var compactFormatted: String {
        if self >= 1_000_000 {
            return String(format: "%.1fM", Double(self) / 1_000_000)
        } else if self >= 1_000 {
            return String(format: "%.1fk", Double(self) / 1_000)
        }
        return "\(self)"
    }
}
