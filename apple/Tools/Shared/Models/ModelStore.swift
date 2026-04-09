import Foundation
import HuggingFace

@Observable
@MainActor
final class ModelStore {

    // MARK: - Types

    struct CuratedModel: Identifiable, Sendable {
        let id: String
        let name: String
        let summary: String
    }

    enum DownloadState: Sendable, Equatable {
        case notDownloaded
        case downloading(fractionCompleted: Double)
        case downloaded
    }

    // MARK: - State

    var downloadStates: [String: DownloadState] = [:]

    var selectedModelID: String {
        didSet { UserDefaults.standard.set(selectedModelID, forKey: "selectedModelID") }
    }

    // MARK: - Available Models

    static let available: [CuratedModel] = [
        CuratedModel(
            id: "mlx-community/Qwen3-4B-4bit",
            name: "Qwen 3 4B",
            summary: "4B params · 4-bit"
        ),
        CuratedModel(
            id: "mlx-community/Phi-4-mini-instruct-4bit",
            name: "Phi 4 Mini",
            summary: "3.8B params · 4-bit"
        ),
        CuratedModel(
            id: "mlx-community/Llama-3.2-3B-Instruct-4bit",
            name: "Llama 3.2 3B",
            summary: "3B params · 4-bit"
        ),
        CuratedModel(
            id: "mlx-community/gemma-2-2b-it-4bit",
            name: "Gemma 2 2B",
            summary: "2B params · 4-bit"
        ),
    ]

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
        downloadStates[model.id] = .notDownloaded
        if selectedModelID == model.id {
            selectedModelID = Self.available.first(where: {
                downloadStates[$0.id] == .downloaded
            })?.id ?? Self.available[0].id
        }
    }

    // MARK: - Internal

    func refreshDownloadStates() {
        for model in Self.available {
            let configFile = modelsDirectory
                .appending(path: model.id)
                .appending(path: "config.json")
            if FileManager.default.fileExists(atPath: configFile.path()) {
                downloadStates[model.id] = .downloaded
            } else {
                downloadStates[model.id] = .notDownloaded
            }
        }
    }
}
