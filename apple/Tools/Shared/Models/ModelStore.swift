import Foundation
import HuggingFace

@Observable
@MainActor
final class ModelStore {

    enum DownloadState: Sendable, Equatable {
        case notDownloaded
        case downloading(fractionCompleted: Double)
        case downloaded
    }

    // MARK: - State

    private(set) var models: [HuggingFace.Model] = []
    private(set) var isFetching = false
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
        Task { await fetchModels() }
    }

    // MARK: - Fetch

    func fetchModels() async {
        isFetching = true
        defer { isFetching = false }

        guard let response = try? await client.listModels(
            author: "mlx-community",
            sort: "downloads",
            direction: .descending,
            limit: 500,
            config: true
        ) else { return }

        guard !response.items.isEmpty else { return }
        models = response.items
        refreshDownloadStates()
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
}

// MARK: - HuggingFace.Model Helpers

extension HuggingFace.Model {
    private static let avatarKeywords: [(keyword: String, asset: String)] = [
        ("bitnet", "microsoft"),
        ("codestral", "mistralai"),
        ("deepseek", "deepseek-ai"),
        ("devstral", "mistralai"),
        ("fastvlm", "apple"),
        ("fish-audio", "fishaudio"),
        ("gemma", "google"),
        ("glm", "zai-org"),
        ("gpt", "openai"),
        ("granite", "ibm-granite"),
        ("kimi", "moonshotai"),
        ("kokoro", "hexgrad"),
        ("lfm", "LiquidAI"),
        ("llama", "meta-llama"),
        ("mimo", "XiaomiMiMo"),
        ("minimax", "MiniMaxAI"),
        ("ministral", "mistralai"),
        ("mistral", "mistralai"),
        ("mixtral", "mistralai"),
        ("nemotron", "nvidia"),
        ("openelm", "apple"),
        ("orpheus", "canopylabs"),
        ("parakeet", "nvidia"),
        ("phi", "microsoft"),
        ("qwen", "Qwen"),
        ("siglip", "google"),
        ("smollm", "HuggingFaceTB"),
        ("smolvlm", "HuggingFaceTB"),
        ("soprano", "ekwek"),
        ("step", "stepfun-ai"),
        ("vibevoice", "microsoft"),
        ("voxtral", "mistralai"),
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
