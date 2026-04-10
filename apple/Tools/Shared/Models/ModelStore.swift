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

    // MARK: - Private

    private let client: HubClient
    private let cache: HubCache

    // MARK: - Init

    init() {
        self.client = HubClient.default
        self.cache = HubCache.default
        self.selectedModelID = UserDefaults.standard.string(forKey: "selectedModelID")
            ?? Self.available[0].id
        refreshDownloadStates()
    }

    // MARK: - Actions

    func download(_ model: CuratedModel) async throws {
        let modelID = model.id
        guard let repoID = Repo.ID(rawValue: modelID) else { return }
        downloadStates[modelID] = .downloading(fractionCompleted: 0)

        let path = try await client.downloadSnapshot(
            of: repoID,
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

    func deleteDownload(_ model: CuratedModel) throws {
        guard let repoID = Repo.ID(rawValue: model.id) else { return }
        let cacheDir = cache.repoDirectory(repo: repoID, kind: .model)
        if FileManager.default.fileExists(atPath: cacheDir.path()) {
            try FileManager.default.removeItem(at: cacheDir)
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
        resolvedPaths[modelID] ?? cache.repoDirectory(
            repo: Repo.ID(rawValue: modelID)!, kind: .model
        )
    }

    var cacheDirectory: URL { cache.cacheDirectory }

    var selectedModel: CuratedModel? {
        Self.available.first { $0.id == selectedModelID }
    }

    var isSelectedModelDownloaded: Bool {
        downloadStates[selectedModelID] == .downloaded
    }

    func refreshDownloadStates() {
        for model in Self.available {
            if let repoID = Repo.ID(rawValue: model.id),
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
