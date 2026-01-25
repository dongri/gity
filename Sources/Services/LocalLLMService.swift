import Foundation
import LLM
import Combine

struct AIModel: Identifiable, Equatable {
    let id: String
    let name: String
    let sizeDescription: String
    let url: URL
    let filename: String
    let template: Template
    
    static func == (lhs: AIModel, rhs: AIModel) -> Bool {
        return lhs.id == rhs.id
    }
}

class ModelDownloader: NSObject, URLSessionDownloadDelegate {
    private var progressHandler: ((Double) -> Void)?
    private var completionHandler: ((Result<URL, Error>) -> Void)?
    private let targetURL: URL
    
    init(targetURL: URL) {
        self.targetURL = targetURL
    }
    
    func startDownload(url: URL, onProgress: @escaping (Double) -> Void, onCompletion: @escaping (Result<URL, Error>) -> Void) {
        self.progressHandler = onProgress
        self.completionHandler = onCompletion
        
        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        let task = session.downloadTask(with: url)
        task.resume()
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            if FileManager.default.fileExists(atPath: targetURL.path) {
                try FileManager.default.removeItem(at: targetURL)
            }
            
            let directory = targetURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            
            try FileManager.default.moveItem(at: location, to: targetURL)
            
            completionHandler?(.success(targetURL))
        } catch {
            completionHandler?(.failure(error))
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        progressHandler?(progress)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            completionHandler?(.failure(error))
        }
    }
}

@MainActor
class LocalLLMService: ObservableObject {
    // Singleton instance
    static let shared = LocalLLMService()
    
    @Published var isDownloading = false
    @Published var downloadingModelId: String?
    @Published var downloadProgress: Double = 0.0
    @Published var isGenerating = false
    @Published var generatedMessage: String = ""
    @Published var errorMessage: String?
    
    // Model Management
    @Published var selectedModelId: String {
        didSet {
            UserDefaults.standard.set(selectedModelId, forKey: "selectedAIModelId")
            Task { await loadModel() }
        }
    }
        
    let models: [AIModel] = [
        AIModel(
            id: "qwen2.5-coder-0.5b",
            name: "Qwen2.5-Coder-0.5B-Instruct",
            sizeDescription: "≈0.49 GB · Q4_K_M",
            url: URL(string:
                "https://huggingface.co/Qwen/Qwen2.5-Coder-0.5B-Instruct-GGUF/resolve/main/qwen2.5-coder-0.5b-instruct-q4_k_m.gguf"
            )!,
            filename: "qwen2.5-coder-0.5b-instruct-q4_k_m.gguf",
            template: .chatML()
        ),
        AIModel(
            id: "smollm2-360m",
            name: "SmolLM2-360M-Instruct",
            sizeDescription: "≈0.38 GB · Q8_0",
            url: URL(string:
                "https://huggingface.co/HuggingFaceTB/SmolLM2-360M-Instruct-GGUF/resolve/main/smollm2-360m-instruct-q8_0.gguf"
            )!,
            filename: "smollm2-360m-instruct-q8_0.gguf",
            template: .chatML()
        ),
        AIModel(
            id: "llama3.2-1b-instruct",
            name: "Llama-3.2-1B-Instruct",
            sizeDescription: "≈0.80 GB · Q4_K_M",
            url: URL(string:
                "https://huggingface.co/hieupt/Llama-3.2-1B-Instruct-Q4_K_M-GGUF/resolve/main/llama-3.2-1b-instruct-q4_k_m.gguf"
            )!,
            filename: "llama-3.2-1b-instruct-q4_k_m.gguf",
            template: .chatML()
        )
    ]

    var currentModel: AIModel? {
        models.first { $0.id == selectedModelId }
    }
    
    private var bot: LLM?
    private var downloader: ModelDownloader?
    private var outputSubscription: AnyCancellable?
    
    private init() {
        self.selectedModelId = UserDefaults.standard.string(forKey: "selectedAIModelId") ?? "qwen2.5-0.5b"
        
        // Initial load if model exists
        if isModelDownloaded(id: selectedModelId) {
            Task {
                await loadModel()
            }
        }
    }
    
    private func getModelPath(filename: String) -> URL {
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("GitY/models")
        try? FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true, attributes: nil)
        return appSupportDir.appendingPathComponent(filename)
    }
    
    func isModelDownloaded(id: String) -> Bool {
        guard let model = models.first(where: { $0.id == id }) else { return false }
        return FileManager.default.fileExists(atPath: getModelPath(filename: model.filename).path)
    }
    
    func deleteModel(id: String) {
        guard let model = models.first(where: { $0.id == id }) else { return }
        let path = getModelPath(filename: model.filename)
        try? FileManager.default.removeItem(at: path)
        
        // If deleting current model, unload bot
        if id == selectedModelId {
            bot = nil
        }
        objectWillChange.send() // Force UI update
    }
    
    func downloadModel(id: String) {
        guard let model = models.first(where: { $0.id == id }) else { return }
        if isModelDownloaded(id: id) { return }
        
        isDownloading = true
        downloadingModelId = id
        downloadProgress = 0.0
        errorMessage = nil
        
        let path = getModelPath(filename: model.filename)
        downloader = ModelDownloader(targetURL: path)
        downloader?.startDownload(
            url: model.url,
            onProgress: { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.downloadProgress = progress
                }
            },
            onCompletion: { [weak self] result in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.isDownloading = false
                    self.downloadingModelId = nil
                    
                    switch result {
                    case .success:
                        self.objectWillChange.send() // Trigger UI update for "Downloaded" status
                        if self.selectedModelId == id {
                            await self.loadModel()
                        }
                    case .failure(let error):
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        )
    }
    
    // Convenience for current model
    func downloadCurrentModel() {
        downloadModel(id: selectedModelId)
    }
    
    private func loadModel() async {
        guard let model = currentModel else { return }
        let path = getModelPath(filename: model.filename)
        
        guard FileManager.default.fileExists(atPath: path.path) else {
            bot = nil
            return
        }
        
        bot = LLM(from: path, template: model.template)
    }
    
    func generateCommitMessage(diff: String) async {
        guard let model = currentModel else { return }

        guard isModelDownloaded(id: model.id) else {
            errorMessage = "Model not downloaded"
            return
        }

        if bot == nil {
            await loadModel()
        }

        guard let bot = bot else {
            errorMessage = "Failed to load model"
            return
        }

        isGenerating = true
        generatedMessage = ""
        errorMessage = nil

        // Diff truncation
        let maxDiffLength = 6000
        let trimmedDiff: String
        if diff.count > maxDiffLength {
            trimmedDiff = diff.prefix(maxDiffLength) + "\n\n[Diff truncated]"
        } else {
            trimmedDiff = diff
        }

        // Simple prompt for all models
        let systemPrompt = """
        Generate a git commit message based on the diff.
        
        Rules:
        - Use Conventional Commits format: "type: subject"
        - If multiple distinct changes are present, use a bullet list format:
          type: summary
          - detail 1
          - detail 2
        - Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert.
        - Output ONLY the commit message, no conversational text.
        """
        let prompt = "Diff:\n\(trimmedDiff)\n\nCommit message:"

        // Use chatML template for all models
        bot.template = .chatML(systemPrompt)

        // Simple output handling
        outputSubscription = bot.$output
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                guard let self = self else { return }
                if !text.isEmpty {
                    self.generatedMessage = text
                }
            }

        await bot.respond(to: prompt)

        if !bot.output.isEmpty {
            generatedMessage = bot.output
        }

        outputSubscription?.cancel()
        outputSubscription = nil

        isGenerating = false
    }

}
