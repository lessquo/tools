import Foundation
import HuggingFace

@Observable
@MainActor
final class ModelStore {

    // MARK: - Types

    enum ModelKind: Sendable {
        case llm
        case vlm
        case stt
    }

    struct CuratedModel: Identifiable, Sendable {
        let id: String
        let name: String
        let summary: String
        let size: String
        let sizeGB: Double
        let avatar: String
        let kind: ModelKind
    }

    enum DownloadState: Sendable, Equatable {
        case notDownloaded
        case downloading(fractionCompleted: Double)
        case downloaded
    }

    // MARK: - State

    var downloadStates: [String: DownloadState] = [:]
    private var resolvedPaths: [String: URL] = [:]

    var selectedModelID: String {
        didSet { UserDefaults.standard.set(selectedModelID, forKey: "selectedModelID") }
    }

    // MARK: - Available Models

    private static let allModels: [CuratedModel] = [
        // LLMs
        CuratedModel(
            id: "mlx-community/Qwen3-30B-A3B-4bit",
            name: "Qwen 3 30B-A3B",
            summary: "30B MoE (3B active) · 4-bit",
            size: "17.2 GB", sizeGB: 17.2,
            avatar: "qwen",
            kind: .llm
        ),
        CuratedModel(
            id: "mlx-community/Mistral-Small-24B-Instruct-2501-4bit",
            name: "Mistral Small 24B",
            summary: "24B params · 4-bit",
            size: "13.3 GB", sizeGB: 13.3,
            avatar: "mistralai",
            kind: .llm
        ),
        CuratedModel(
            id: "mlx-community/Qwen3-14B-4bit",
            name: "Qwen 3 14B",
            summary: "14B params · 4-bit",
            size: "8.32 GB", sizeGB: 8.32,
            avatar: "qwen",
            kind: .llm
        ),
        CuratedModel(
            id: "mlx-community/Mistral-Nemo-Instruct-2407-4bit",
            name: "Mistral Nemo",
            summary: "12B params · 4-bit",
            size: "6.91 GB", sizeGB: 6.91,
            avatar: "mistralai",
            kind: .llm
        ),
        CuratedModel(
            id: "mlx-community/gemma-2-9b-it-4bit",
            name: "Gemma 2 9B",
            summary: "9B params · 4-bit",
            size: "5.22 GB", sizeGB: 5.22,
            avatar: "google",
            kind: .llm
        ),
        CuratedModel(
            id: "mlx-community/Qwen3-8B-4bit",
            name: "Qwen 3 8B",
            summary: "8B params · 4-bit",
            size: "4.62 GB", sizeGB: 4.62,
            avatar: "qwen",
            kind: .llm
        ),
        CuratedModel(
            id: "mlx-community/Meta-Llama-3.1-8B-Instruct-4bit",
            name: "Llama 3.1 8B",
            summary: "8B params · 4-bit",
            size: "4.52 GB", sizeGB: 4.52,
            avatar: "meta-llama",
            kind: .llm
        ),
        CuratedModel(
            id: "mlx-community/Qwen3-4B-4bit",
            name: "Qwen 3 4B",
            summary: "4B params · 4-bit",
            size: "2.28 GB", sizeGB: 2.28,
            avatar: "qwen",
            kind: .llm
        ),
        CuratedModel(
            id: "mlx-community/Phi-4-mini-instruct-4bit",
            name: "Phi 4 Mini",
            summary: "3.8B params · 4-bit",
            size: "2.18 GB", sizeGB: 2.18,
            avatar: "microsoft",
            kind: .llm
        ),
        CuratedModel(
            id: "mlx-community/Llama-3.2-3B-Instruct-4bit",
            name: "Llama 3.2 3B",
            summary: "3B params · 4-bit",
            size: "1.82 GB", sizeGB: 1.82,
            avatar: "meta-llama",
            kind: .llm
        ),
        CuratedModel(
            id: "mlx-community/gemma-2-2b-it-4bit",
            name: "Gemma 2 2B",
            summary: "2B params · 4-bit",
            size: "1.49 GB", sizeGB: 1.49,
            avatar: "google",
            kind: .llm
        ),
        CuratedModel(
            id: "mlx-community/Qwen3-1.7B-4bit",
            name: "Qwen 3 1.7B",
            summary: "1.7B params · 4-bit",
            size: "984 MB", sizeGB: 0.96,
            avatar: "qwen",
            kind: .llm
        ),

        // VLMs
        CuratedModel(
            id: "mlx-community/gemma-4-26b-a4b-it-4bit",
            name: "Gemma 4 26B-A4B",
            summary: "26B MoE (4B active) · 4-bit · Vision",
            size: "15.6 GB", sizeGB: 15.6,
            avatar: "google",
            kind: .vlm
        ),
        CuratedModel(
            id: "mlx-community/gemma-3-12b-it-qat-4bit",
            name: "Gemma 3 12B",
            summary: "12B params · 4-bit · Vision",
            size: "8.07 GB", sizeGB: 8.07,
            avatar: "google",
            kind: .vlm
        ),
        CuratedModel(
            id: "mlx-community/gemma-4-e4b-it-4bit",
            name: "Gemma 4 E4B",
            summary: "4B params · 4-bit · Vision",
            size: "5.25 GB", sizeGB: 5.25,
            avatar: "google",
            kind: .vlm
        ),
        CuratedModel(
            id: "mlx-community/Qwen2.5-VL-7B-Instruct-4bit",
            name: "Qwen 2.5 VL 7B",
            summary: "7B params · 4-bit · Vision",
            size: "5.65 GB", sizeGB: 5.65,
            avatar: "qwen",
            kind: .vlm
        ),
        CuratedModel(
            id: "mlx-community/Qwen2.5-VL-3B-Instruct-4bit",
            name: "Qwen 2.5 VL 3B",
            summary: "3B params · 4-bit · Vision",
            size: "3.09 GB", sizeGB: 3.09,
            avatar: "qwen",
            kind: .vlm
        ),
        CuratedModel(
            id: "mlx-community/gemma-3-4b-it-qat-4bit",
            name: "Gemma 3 4B",
            summary: "4B params · 4-bit · Vision",
            size: "3.03 GB", sizeGB: 3.03,
            avatar: "google",
            kind: .vlm
        ),

        // STT (Speech-to-Text)
        CuratedModel(
            id: "mlx-community/whisper-large-v3-mlx",
            name: "Whisper Large V3",
            summary: "1.5B params · Speech-to-Text",
            size: "3.08 GB", sizeGB: 3.08,
            avatar: "openai",
            kind: .stt
        ),
        CuratedModel(
            id: "mlx-community/whisper-large-v3-turbo",
            name: "Whisper Large V3 Turbo",
            summary: "809M params · Speech-to-Text",
            size: "1.61 GB", sizeGB: 1.61,
            avatar: "openai",
            kind: .stt
        ),
        CuratedModel(
            id: "mlx-community/whisper-small-mlx",
            name: "Whisper Small",
            summary: "244M params · Speech-to-Text",
            size: "481 MB", sizeGB: 0.47,
            avatar: "openai",
            kind: .stt
        ),
        CuratedModel(
            id: "mlx-community/whisper-tiny-mlx",
            name: "Whisper Tiny",
            summary: "39M params · Speech-to-Text",
            size: "74.4 MB", sizeGB: 0.07,
            avatar: "openai",
            kind: .stt
        ),
    ]

    #if os(iOS)
    static let available = allModels.filter { $0.sizeGB <= 4.0 }
    #else
    static let available = allModels
    #endif

    // MARK: - Private

    private let client: HubClient
    private let modelsDirectory: URL

    // MARK: - Init

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        self.modelsDirectory = appSupport.appending(
            path: "Tools/Models", directoryHint: .isDirectory
        )
        self.client = HubClient.default
        self.selectedModelID = UserDefaults.standard.string(forKey: "selectedModelID")
            ?? Self.available[0].id
        refreshDownloadStates()
    }

    // MARK: - Actions

    func download(_ model: CuratedModel) async throws {
        let modelID = model.id
        guard let repoID = Repo.ID(rawValue: modelID) else { return }
        let destination = modelsDirectory.appending(path: modelID)
        downloadStates[modelID] = .downloading(fractionCompleted: 0)

        _ = try await client.downloadSnapshot(
            of: repoID,
            to: destination,
            matching: ["*.safetensors", "*.json", "tokenizer.model"]
        ) { [weak self] progress in
            self?.downloadStates[modelID] = .downloading(
                fractionCompleted: progress.fractionCompleted
            )
        }

        downloadStates[modelID] = .downloaded
    }

    func deleteDownload(_ model: CuratedModel) throws {
        let modelDir = modelsDirectory.appending(path: model.id)
        if FileManager.default.fileExists(atPath: modelDir.path()) {
            try FileManager.default.removeItem(at: modelDir)
        }
        if let repoID = Repo.ID(rawValue: model.id) {
            let cacheDir = HubCache.default.repoDirectory(repo: repoID, kind: .model)
            if FileManager.default.fileExists(atPath: cacheDir.path()) {
                try FileManager.default.removeItem(at: cacheDir)
            }
        }
        resolvedPaths[model.id] = nil
        downloadStates[model.id] = .notDownloaded
        if selectedModelID == model.id {
            selectedModelID = Self.available.first(where: {
                downloadStates[$0.id] == .downloaded
            })?.id ?? Self.available[0].id
        }
    }

    // MARK: - Internal

    func modelDirectory(for modelID: String) -> URL {
        resolvedPaths[modelID] ?? modelsDirectory.appending(path: modelID)
    }

    var selectedModel: CuratedModel? {
        Self.available.first { $0.id == selectedModelID }
    }

    var isSelectedModelDownloaded: Bool {
        downloadStates[selectedModelID] == .downloaded
    }

    func refreshDownloadStates() {
        let cache = HubCache.default
        for model in Self.available {
            let appDir = modelsDirectory.appending(path: model.id)
            let configInApp = appDir.appending(path: "config.json")

            if FileManager.default.fileExists(atPath: configInApp.path()) {
                downloadStates[model.id] = .downloaded
                resolvedPaths[model.id] = appDir
            } else if let repoID = Repo.ID(rawValue: model.id),
                      let cached = cache.cachedFilePath(
                          repo: repoID, kind: .model, revision: "main",
                          filename: "config.json"
                      )
            {
                downloadStates[model.id] = .downloaded
                resolvedPaths[model.id] = cached.deletingLastPathComponent()
            } else {
                downloadStates[model.id] = .notDownloaded
                resolvedPaths[model.id] = nil
            }
        }
    }
}
