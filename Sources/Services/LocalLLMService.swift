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
            id: "qwen2.5-coder-1.5b",
            name: "Qwen2.5-Coder-1.5B-Instruct",
            sizeDescription: "≈0.98 GB · Q4_K_M",
            url: URL(string:
                "https://huggingface.co/Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF/resolve/main/qwen2.5-coder-1.5b-instruct-q4_k_m.gguf"
            )!,
            filename: "qwen2.5-coder-1.5b-instruct-q4_k_m.gguf",
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
        ),
        AIModel(
            id: "gemma-4-e2b-it",
            name: "Gemma-4-E2B-IT",
            sizeDescription: "≈4.97 GB · Q8_0",
            url: URL(string:
                "https://huggingface.co/ggml-org/gemma-4-E2B-it-GGUF/resolve/main/gemma-4-e2b-it-Q8_0.gguf"
            )!,
            filename: "gemma-4-e2b-it-Q8_0.gguf",
            template: .gemma
        ),
        AIModel(
            id: "gemma-4-e4b-it",
            name: "Gemma-4-E4B-IT",
            sizeDescription: "≈4.98 GB · Q4_K_M",
            url: URL(string:
                "https://huggingface.co/unsloth/gemma-4-E4B-it-GGUF/resolve/main/gemma-4-E4B-it-Q4_K_M.gguf"
            )!,
            filename: "gemma-4-E4B-it-Q4_K_M.gguf",
            template: .gemma
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

        // Diff truncation: Increased limit for modern smaller LLMs (like Qwen2.5) which support 8k-32k context lengths
        // 40000 characters is roughly 8000-10000 tokens
        let maxDiffLength = 40000
        let trimmedDiff: String
        if diff.count > maxDiffLength {
            trimmedDiff = diff.prefix(maxDiffLength) + "\n\n[Diff truncated]"
        } else {
            trimmedDiff = diff
        }

        // System Prompt tailored for generating high-quality git commit messages
        let systemPrompt = """
        You are an expert software developer generating a git commit message based on the provided diff.
        
        Rules for the commit message:
        1. Start with a Conventional Commit type (feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert).
        2. Follow the type with a colon and a space, then a concise, imperative subject line summarizing the main change (under 50 characters).
        3. If the diff contains multiple distinct changes, add a blank line after the subject and use a bulleted list for details.
        4. Focus on the 'why' and 'what' of the changes, not just the 'how'.
        5. Output ONLY the commit message itself. Do not include any introductory text, conversational filler, markdown formatting (like ```), or explanations.
        """
        
        // Structure the prompt explicitly
        let prompt = """
        Review the following diff and generate a git commit message following the rules.
        
        Diff:
        \(trimmedDiff)
        
        Commit message:
        """

        // Clear previous output state and context history
        bot.setOutput(to: "")
        bot.reset()


        // Use model-appropriate template with system prompt
        let templateWithSystem: Template
        if model.id.hasPrefix("gemma") {
            templateWithSystem = Template(
                system: ("<start_of_turn>system\n", "<end_of_turn>\n"),
                user: ("<start_of_turn>user\n", "<end_of_turn>\n"),
                bot: ("<start_of_turn>model\n", "<end_of_turn>\n"),
                stopSequence: "<end_of_turn>",
                systemPrompt: systemPrompt
            )
        } else {
            templateWithSystem = .chatML(systemPrompt)
        }
        bot.template = templateWithSystem

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
