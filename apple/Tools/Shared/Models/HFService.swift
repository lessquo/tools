import Foundation
import HuggingFace

@Observable
@MainActor
final class HFService {

    enum SortOption: String, CaseIterable {
        case downloads = "Downloads"
        case likes = "Likes"
        case recentlyCreated = "Recently Created"
        case recentlyUpdated = "Recently Updated"

        var apiValue: String {
            switch self {
            case .downloads: "downloads"
            case .likes: "likes"
            case .recentlyCreated: "createdAt"
            case .recentlyUpdated: "lastModified"
            }
        }
    }

    enum DownloadState: Sendable, Equatable {
        case notDownloaded
        case downloading(fractionCompleted: Double)
        case downloaded
    }

    enum Feature: String {
        case dictation
        case quickActions

        var pipelineTag: String {
            switch self {
            case .dictation: "automatic-speech-recognition"
            case .quickActions: "text-generation"
            }
        }
    }

    // MARK: - State

    private(set) var models: [HuggingFace.Model] = []
    private(set) var downloadedModels: [HuggingFace.Model] = []
    private(set) var pipelineTags: [PipelineTag] = []
    private(set) var isFetching = false
    var downloadStates: [String: DownloadState] = [:]
    var downloadedSizes: [String: Int64] = [:]
    var downloadError: String?
    private var resolvedPaths: [String: URL] = [:]
    private var downloadTasks: [String: Task<Void, Never>] = [:]
    private var scanFetchTask: Task<Void, Never>?

    // MARK: - Private

    private let client: HubClient
    private let cache: HubCache

    // MARK: - Init

    private static let appCache: HubCache = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleID = Bundle.main.bundleIdentifier!
        let modelsDir = appSupport.appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
        try? FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)
        return HubCache(cacheDirectory: modelsDir)
    }()

    var isAppleSpeechInstalled: Bool = false

    init() {
        self.cache = Self.appCache
        self.client = HubClient(cache: cache)
        scanDownloadedModels()
        Task {
            async let models: Void = fetchModels()
            async let tags: Void = fetchPipelineTags()
            async let apple: Void = refreshAppleSpeechStatus()
            _ = await (models, tags, apple)
        }
    }

    func refreshAppleSpeechStatus() async {
        let installed = await AppleSpeechService.isLocaleInstalled()
        self.isAppleSpeechInstalled = installed
    }

    // MARK: - Fetch

    func fetchModels(search: String? = nil, sort: SortOption = .downloads, pipelineTag: String? = nil) async {
        isFetching = true
        defer { isFetching = false }

        let query = search.flatMap { $0.isEmpty ? nil : $0 }
        let tag = pipelineTag.flatMap { $0.isEmpty ? nil : $0 }
        guard let response = try? await client.listModels(
            search: query,
            author: "mlx-community",
            sort: sort.apiValue,
            direction: .descending,
            limit: 500,
            config: true,
            pipelineTag: tag
        ) else { return }

        guard !response.items.isEmpty else { return }
        models = response.items
        refreshDownloadStates()
        scanDownloadedModels()
    }

    func fetchPipelineTags() async {
        guard let url = URL(string: "https://huggingface.co/api/models-tags-by-type?type=pipeline_tag"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let result = try? JSONDecoder().decode([String: [PipelineTag]].self, from: data),
              let entries = result["pipeline_tag"]
        else { return }
        pipelineTags = entries.sorted { $0.label < $1.label }
    }

    // MARK: - Actions

    func startDownload(_ model: HuggingFace.Model) {
        let modelID = model.id.rawValue
        downloadTasks[modelID] = Task {
            do {
                try await download(model)
            } catch {
                if !Task.isCancelled {
                    downloadStates[modelID] = .notDownloaded
                    downloadError = error.localizedDescription
                }
            }
            downloadTasks[modelID] = nil
        }
    }

    func cancelDownload(_ model: HuggingFace.Model) {
        let modelID = model.id.rawValue
        downloadTasks[modelID]?.cancel()
        downloadTasks[modelID] = nil
        downloadStates[modelID] = .notDownloaded
    }

    private func download(_ model: HuggingFace.Model) async throws {
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
        refreshDownloadSize(for: model.id)
        scanDownloadedModels()
    }

    func deleteDownload(_ model: HuggingFace.Model) throws {
        let modelID = model.id.rawValue
        let fm = FileManager.default
        let repoName = modelID.replacingOccurrences(of: "/", with: "--")
        let dirName = "models--\(repoName)"
        let root = cache.cacheDirectory
        let targets: [URL] = [
            root.appendingPathComponent(dirName),
            root.appendingPathComponent(".metadata").appendingPathComponent(dirName),
            root.appendingPathComponent(".locks").appendingPathComponent(dirName),
        ]

        var firstError: Error?
        for url in targets where fm.fileExists(atPath: url.path) {
            do {
                try fm.removeItem(at: url)
            } catch {
                if firstError == nil { firstError = error }
            }
        }

        if let error = firstError,
           fm.fileExists(atPath: targets[0].path) {
            throw error
        }

        resolvedPaths[modelID] = nil
        downloadStates[modelID] = .notDownloaded
        downloadedSizes[modelID] = nil
        scanDownloadedModels()
    }

    // MARK: - Internal

    func modelDirectory(for modelID: String) -> URL {
        resolvedPaths[modelID] ?? cache.repoDirectory(
            repo: Repo.ID(rawValue: modelID)!, kind: .model
        )
    }

    var cacheDirectory: URL { cache.cacheDirectory }

    func model(id: String) -> HuggingFace.Model? {
        guard !id.isEmpty, id != STTService.appleSpeechID else { return nil }
        return downloadedModels.first { $0.id.rawValue == id }
            ?? models.first { $0.id.rawValue == id }
    }

    func isModelReady(id: String) -> Bool {
        if id == STTService.appleSpeechID { return isAppleSpeechInstalled }
        return !id.isEmpty && downloadStates[id] == .downloaded
    }

    func displayName(id: String) -> String {
        if id == STTService.appleSpeechID { return "Apple Speech" }
        return model(id: id)?.id.name ?? "Select model"
    }

    func downloadedModels(for feature: Feature) -> [HuggingFace.Model] {
        downloadedModels.filter {
            guard $0.pipelineTag == feature.pipelineTag else { return false }
            if feature == .dictation { return $0.id.name.lowercased().contains("parakeet") }
            return true
        }
    }

    func scanDownloadedModels() {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: cache.cacheDirectory,
            includingPropertiesForKeys: nil
        ) else { return }

        var found: [HuggingFace.Model] = []
        var idsToFetch: [Repo.ID] = []

        for dir in contents {
            let parts = dir.lastPathComponent.components(separatedBy: "--")
            guard parts.count >= 3, parts[0] == "models" else { continue }

            let repoString = parts[1] + "/" + parts.dropFirst(2).joined(separator: "--")
            guard let repoID = Repo.ID(rawValue: repoString) else { continue }

            guard let cached = cache.cachedFilePath(
                repo: repoID, kind: .model, revision: "main",
                filename: "config.json"
            ) else { continue }

            resolvedPaths[repoString] = cached.deletingLastPathComponent()
            downloadStates[repoString] = .downloaded
            if downloadedSizes[repoString] == nil {
                refreshDownloadSize(for: repoID)
            }

            if let apiModel = models.first(where: { $0.id.rawValue == repoString }) {
                found.append(apiModel)
            } else {
                idsToFetch.append(repoID)
            }
        }

        downloadedModels = found

        scanFetchTask?.cancel()
        guard !idsToFetch.isEmpty else {
            scanFetchTask = nil
            return
        }
        scanFetchTask = Task { [weak self] in
            for repoID in idsToFetch {
                if Task.isCancelled { return }
                guard let client = self?.client,
                      let model = try? await client.getModel(repoID)
                else { continue }
                if Task.isCancelled { return }
                guard let self,
                      self.downloadStates[repoID.rawValue] == .downloaded,
                      !self.downloadedModels.contains(where: { $0.id == model.id })
                else { continue }
                self.downloadedModels.append(model)
            }
        }
    }

    func refreshDownloadSize(for repoID: Repo.ID) {
        let modelID = repoID.rawValue
        let dir = cache.repoDirectory(repo: repoID, kind: .model)
        Task.detached(priority: .utility) { [weak self] in
            let size = Self.directorySize(at: dir)
            await MainActor.run { [weak self] in
                self?.downloadedSizes[modelID] = size
            }
        }
    }

    private nonisolated static func directorySize(at url: URL) -> Int64 {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return 0 }
        guard let enumerator = fm.enumerator(atPath: url.path) else { return 0 }
        var total: Int64 = 0
        while let relative = enumerator.nextObject() as? String {
            let path = url.appendingPathComponent(relative).path
            guard let attrs = try? fm.attributesOfItem(atPath: path),
                  let type = attrs[.type] as? FileAttributeType,
                  type == .typeRegular,
                  let size = attrs[.size] as? NSNumber
            else { continue }
            total += size.int64Value
        }
        return total
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
                if downloadedSizes[modelID] == nil {
                    refreshDownloadSize(for: model.id)
                }
            } else {
                downloadStates[modelID] = .notDownloaded
                resolvedPaths[modelID] = nil
                downloadedSizes[modelID] = nil
            }
        }
    }
}

struct PipelineTag: Decodable, Identifiable {
    let id: String
    let label: String
}

// MARK: - HuggingFace.Model Helpers

extension HuggingFace.Model {
    private static let avatarKeywords: [(keyword: String, asset: String)] = [
        ("bitnet", "microsoft"),
        ("chatterbox", "ResembleAI"),
        ("codestral", "mistralai"),
        ("deepseek", "deepseek-ai"),
        ("devstral", "mistralai"),
        ("fastvlm", "apple"),
        ("fish-audio", "fishaudio"),
        ("flux", "black-forest-labs"),
        ("fun-asr", "FunAudioLLM"),
        ("gemma", "google"),
        ("glm", "zai-org"),
        ("gpt", "openai"),
        ("granite", "ibm-granite"),
        ("kimi", "moonshotai"),
        ("kitten", "KittenML"),
        ("kokoro", "hexgrad"),
        ("lfm", "LiquidAI"),
        ("llama", "meta-llama"),
        ("mimo", "XiaomiMiMo"),
        ("minimax", "MiniMaxAI"),
        ("ministral", "mistralai"),
        ("mistral", "mistralai"),
        ("mixtral", "mistralai"),
        ("molmo", "allenai"),
        ("nemotron", "nvidia"),
        ("openelm", "apple"),
        ("orpheus", "canopylabs"),
        ("parakeet", "nvidia"),
        ("phi", "microsoft"),
        ("qwen", "Qwen"),
        ("sam-audio", "facebook"),
        ("sarvam", "sarvamai"),
        ("shuttle", "shuttleai"),
        ("siglip", "google"),
        ("smollm", "HuggingFaceTB"),
        ("smolvlm", "HuggingFaceTB"),
        ("soprano", "ekwek"),
        ("sortformer", "nvidia"),
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

extension [HuggingFace.Model] {
    func sorted(by option: HFService.SortOption) -> [HuggingFace.Model] {
        switch option {
        case .downloads:
            sorted { ($0.downloads ?? 0) > ($1.downloads ?? 0) }
        case .likes:
            sorted { ($0.likes ?? 0) > ($1.likes ?? 0) }
        case .recentlyCreated:
            sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        case .recentlyUpdated:
            sorted { ($0.lastModified ?? .distantPast) > ($1.lastModified ?? .distantPast) }
        }
    }
}

extension Int {
    var compactFormatted: String {
        let sig = FloatingPointFormatStyle<Double>.number.precision(.significantDigits(1...3))
        if self >= 1_000_000 {
            return (Double(self) / 1_000_000).formatted(sig) + "M"
        } else if self >= 1_000 {
            return (Double(self) / 1_000).formatted(sig) + "k"
        }
        return "\(self)"
    }
}
