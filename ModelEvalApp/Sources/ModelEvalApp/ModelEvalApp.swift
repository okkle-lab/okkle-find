import AppKit
import SwiftUI
import UniformTypeIdentifiers

@main
struct ModelEvalApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1120, minHeight: 760)
        }
        .defaultSize(width: 1180, height: 780)
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .pasteboard) {
                Button("Cut") {
                    sendEditCommand(#selector(NSText.cut(_:)))
                }
                .keyboardShortcut("x")

                Button("Copy") {
                    sendEditCommand(#selector(NSText.copy(_:)))
                }
                .keyboardShortcut("c")

                Button("Paste") {
                    sendEditCommand(#selector(NSText.paste(_:)))
                }
                .keyboardShortcut("v")

                Divider()

                Button("Select All") {
                    sendEditCommand(#selector(NSResponder.selectAll(_:)))
                }
                .keyboardShortcut("a")
            }
        }
    }

    private func sendEditCommand(_ selector: Selector) {
        NSApplication.shared.sendAction(selector, to: nil, from: nil)
    }
}

private enum AppPaths {
    static let defaultPromptSpreadsheetName = "Model_Test_Prompts_for_Automation.xlsx"
    static let defaultModelSpreadsheetName = "AI_model_variants.xlsx"
    static let defaultWebsiteSeedCSVName = "model_variants.csv"

    static var developmentRepoRoot: URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 {
            url.deleteLastPathComponent()
        }
        return url
    }

    static var bundledRunnerURL: URL? {
        Bundle.main.url(forResource: "model_eval_runner", withExtension: nil)
    }

    static var developmentScriptURL: URL {
        developmentRepoRoot.appendingPathComponent("script/model_eval_runner.py")
    }

    static var defaultsDirectoryURL: URL? {
        if let bundledDefaults = Bundle.main.resourceURL?.appendingPathComponent("Defaults", isDirectory: true),
           FileManager.default.fileExists(atPath: bundledDefaults.path) {
            return bundledDefaults
        }

        let developmentDefaults = developmentRepoRoot.appendingPathComponent("ModelEvalApp/Defaults", isDirectory: true)
        if FileManager.default.fileExists(atPath: developmentDefaults.path) {
            return developmentDefaults
        }

        return nil
    }

    static var defaultPromptSpreadsheetURL: URL? {
        defaultSpreadsheetURL(named: defaultPromptSpreadsheetName)
    }

    static var defaultModelSpreadsheetURL: URL? {
        defaultSpreadsheetURL(named: defaultModelSpreadsheetName)
    }

    static var defaultWebsiteSeedCSVURL: URL? {
        let developmentSeed = developmentRepoRoot.appendingPathComponent("db/seeds/model_variants.csv")
        if FileManager.default.fileExists(atPath: developmentSeed.path) {
            return developmentSeed
        }

        guard let defaultsDirectoryURL else { return nil }
        let bundledSeed = defaultsDirectoryURL.appendingPathComponent(defaultWebsiteSeedCSVName)
        return FileManager.default.fileExists(atPath: bundledSeed.path) ? bundledSeed : nil
    }

    static var defaultOutputBaseURL: URL {
        if bundledRunnerURL != nil {
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            return documentsURL
                .appendingPathComponent("Model Eval Runner", isDirectory: true)
                .appendingPathComponent("outputs", isDirectory: true)
                .appendingPathComponent("model_tests", isDirectory: true)
        }
        return developmentRepoRoot.appendingPathComponent("outputs/model_tests")
    }

    static var defaultPythonPath: String {
        if let explicitPython = ProcessInfo.processInfo.environment["PYTHON"], !explicitPython.isEmpty {
            return explicitPython
        }

        let candidates = [
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3"
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) } ?? "/usr/bin/python3"
    }

    private static func defaultSpreadsheetURL(named filename: String) -> URL? {
        guard let defaultsDirectoryURL else { return nil }
        let url = defaultsDirectoryURL.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}

private enum AppVersion {
    static var display: String {
        if let bundleVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           !bundleVersion.isEmpty {
            return bundleVersion
        }

        let versionFile = AppPaths.developmentRepoRoot.appendingPathComponent("ModelEvalApp/VERSION")
        if let text = try? String(contentsOf: versionFile, encoding: .utf8) {
            let version = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !version.isEmpty {
                return version
            }
        }

        return "Development"
    }
}

@MainActor
final class RunnerViewModel: ObservableObject {
    @Published var promptSpreadsheetURL: URL? = AppPaths.defaultPromptSpreadsheetURL
    @Published var modelSpreadsheetURL: URL? = AppPaths.defaultModelSpreadsheetURL
    @Published var outputBaseURL: URL = AppPaths.defaultOutputBaseURL
    @Published var pythonPath: String = AppPaths.defaultPythonPath
    @Published var includeImages = false
    @Published var dryRun = false
    @Published var parallelProducts = false
    @Published var skipScoredModels = true
    @Published var maxTokens = 1000
    @Published var openRouterAPIKey: String = ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"] ?? ""
    @Published var openAIAPIKey: String = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
    @Published var githubModelsToken: String = ProcessInfo.processInfo.environment["GITHUB_MODELS_TOKEN"] ?? ""
    @Published var isRunning = false
    @Published var logText = ""
    @Published var lastOutputURL: URL?

    private var process: Process?

    var canRun: Bool {
        promptSpreadsheetURL != nil && modelSpreadsheetURL != nil && !isRunning
    }

    var usesBundledRunner: Bool {
        AppPaths.bundledRunnerURL != nil
    }

    func run() {
        guard let promptSpreadsheetURL, let modelSpreadsheetURL else { return }

        let runFolder = outputBaseURL.appendingPathComponent("swiftui-\(Self.timestamp())")
        lastOutputURL = runFolder
        logText = ""
        isRunning = true

        do {
            try FileManager.default.createDirectory(at: runFolder, withIntermediateDirectories: true)
            try runProcess(
                promptSpreadsheetURL: promptSpreadsheetURL,
                modelSpreadsheetURL: modelSpreadsheetURL,
                outputURL: runFolder
            )
        } catch {
            appendLog("Error: \(error.localizedDescription)\n")
            isRunning = false
        }
    }

    func cancel() {
        process?.terminate()
        appendLog("\nCancelled.\n")
        isRunning = false
    }

    func revealOutput() {
        guard let lastOutputURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([lastOutputURL])
    }

    private func runProcess(
        promptSpreadsheetURL: URL,
        modelSpreadsheetURL: URL,
        outputURL: URL
    ) throws {
        let runner = Process()

        var arguments = [
            "--workbook", promptSpreadsheetURL.path,
            "--models-workbook", modelSpreadsheetURL.path,
            "--output-dir", outputURL.path,
            "--max-tokens", "\(maxTokens)"
        ]

        if let bundledRunnerURL = AppPaths.bundledRunnerURL {
            runner.executableURL = bundledRunnerURL
            runner.currentDirectoryURL = outputURL
        } else {
            runner.executableURL = URL(fileURLWithPath: pythonPath)
            runner.currentDirectoryURL = AppPaths.developmentRepoRoot
            arguments.insert(AppPaths.developmentScriptURL.path, at: 0)
        }

        if includeImages {
            arguments.append("--include-image")
        }
        if dryRun {
            arguments.append("--dry-run")
        }
        if parallelProducts {
            arguments.append("--parallel-products")
        }
        if skipScoredModels, let websiteSeedCSVURL = AppPaths.defaultWebsiteSeedCSVURL {
            arguments.append(contentsOf: ["--website-seed-csv", websiteSeedCSVURL.path])
            arguments.append("--skip-scored-models")
        }
        runner.arguments = arguments
        runner.environment = processEnvironment()

        let outputPipe = Pipe()
        runner.standardOutput = outputPipe
        runner.standardError = outputPipe

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in
                self?.appendLog(text)
            }
        }

        runner.terminationHandler = { [weak self] process in
            outputPipe.fileHandleForReading.readabilityHandler = nil
            Task { @MainActor in
                self?.appendLog("\nFinished with exit code \(process.terminationStatus).\n")
                self?.isRunning = false
            }
        }

        process = runner
        appendLog("$ \(commandDescription(arguments: arguments))\n\n")
        try runner.run()
    }

    private func commandDescription(arguments: [String]) -> String {
        if let bundledRunnerURL = AppPaths.bundledRunnerURL {
            return ([bundledRunnerURL.path] + arguments).map(Self.shellQuoted).joined(separator: " ")
        }
        return ([pythonPath] + arguments).map(Self.shellQuoted).joined(separator: " ")
    }

    private func processEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let openRouterKey = openRouterAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let openAIKey = openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let githubToken = githubModelsToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if !openRouterKey.isEmpty {
            environment["OPENROUTER_API_KEY"] = openRouterKey
        }
        if !openAIKey.isEmpty {
            environment["OPENAI_API_KEY"] = openAIKey
        }
        if !githubToken.isEmpty {
            environment["GITHUB_MODELS_TOKEN"] = githubToken
        }
        return environment
    }

    private func appendLog(_ text: String) {
        logText.append(text)
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }

    private static func shellQuoted(_ value: String) -> String {
        if value.rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines) == nil {
            return value
        }
        return "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}

struct ContentView: View {
    @StateObject private var viewModel = RunnerViewModel()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(alignment: .top, spacing: 18) {
                controls
                    .frame(width: 330)
                logPanel
            }
            .padding(18)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "tablecells.badge.ellipsis")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text("Model Eval Runner")
                    .font(.title2.weight(.semibold))
                Text("Prompt sheet + model sheet - v\(AppVersion.display)")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                viewModel.revealOutput()
            } label: {
                Label("Output", systemImage: "folder")
            }
            .disabled(viewModel.lastOutputURL == nil)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            SpreadsheetDropZone(
                title: "Prompt Spreadsheet",
                systemImage: "doc.badge.plus",
                url: $viewModel.promptSpreadsheetURL
            )
            SpreadsheetDropZone(
                title: "Model Spreadsheet",
                systemImage: "list.bullet.rectangle",
                url: $viewModel.modelSpreadsheetURL
            )
            outputPicker
            options
            HStack {
                Button(role: .cancel) {
                    viewModel.cancel()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .disabled(!viewModel.isRunning)
                Spacer()
                Button {
                    viewModel.run()
                } label: {
                    Label(viewModel.isRunning ? "Running" : "Run", systemImage: "play.fill")
                }
                .keyboardShortcut(.return)
                .disabled(!viewModel.canRun)
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var outputPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Output Folder")
                .font(.headline)
            HStack(spacing: 8) {
                Text(viewModel.outputBaseURL.path)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    chooseOutputFolder()
                } label: {
                    Image(systemName: "folder.badge.gearshape")
                }
                .help("Choose output folder")
            }
            .padding(10)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.25))
            )
        }
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $viewModel.dryRun) {
                Label("Dry Run", systemImage: "checklist")
            }
            Toggle(isOn: $viewModel.includeImages) {
                Label("Image Generation", systemImage: "photo")
            }
            Toggle(isOn: $viewModel.parallelProducts) {
                Label("Parallel Products", systemImage: "arrow.triangle.branch")
            }
            Toggle(isOn: $viewModel.skipScoredModels) {
                Label("Skip Already Scored", systemImage: "forward.end")
            }
            HStack {
                Label("Max Tokens", systemImage: "text.word.spacing")
                Spacer()
                Stepper(value: $viewModel.maxTokens, in: 200...4000, step: 100) {
                    Text("\(viewModel.maxTokens)")
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 56, alignment: .trailing)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("API Keys")
                    .font(.headline)
                SecureField("OpenRouter API Key", text: $viewModel.openRouterAPIKey)
                    .textFieldStyle(.roundedBorder)
                SecureField("OpenAI API Key", text: $viewModel.openAIAPIKey)
                    .textFieldStyle(.roundedBorder)
                SecureField("GitHub Models Token", text: $viewModel.githubModelsToken)
                    .textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Python")
                    .font(.headline)
                if viewModel.usesBundledRunner {
                    Label("Bundled with app", systemImage: "shippingbox")
                        .foregroundStyle(.secondary)
                } else {
                    TextField("Python", text: $viewModel.pythonPath)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }
            }
        }
        .padding(12)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.25))
        )
    }

    private var logPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Run Log")
                    .font(.headline)
                Spacer()
                if viewModel.isRunning {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            ScrollViewReader { proxy in
                ScrollView {
                    Text(viewModel.logText.isEmpty ? "Ready." : viewModel.logText)
                        .font(.system(.callout, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .id("log-end")
                        .padding(12)
                }
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onChange(of: viewModel.logText) { _, _ in
                    proxy.scrollTo("log-end", anchor: .bottom)
                }
            }
        }
    }

    private func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = viewModel.outputBaseURL
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.outputBaseURL = url
        }
    }
}

struct SpreadsheetDropZone: View {
    let title: String
    let systemImage: String
    @Binding var url: URL?
    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                Spacer()
                Button {
                    chooseFile()
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .help("Choose spreadsheet")
            }
            VStack(spacing: 8) {
                let hasFile = url != nil
                Image(systemName: hasFile ? "checkmark.circle.fill" : "arrow.down.doc")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(hasFile ? Color.green : Color.secondary)
                Text(url?.lastPathComponent ?? "Drop .xlsx")
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .font(url == nil ? .body : .callout)
                if let url {
                    Text(url.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 108)
            .padding(12)
            .background(isTargeted ? Color.blue.opacity(0.10) : Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isTargeted ? Color.blue : Color.secondary.opacity(0.25),
                        style: StrokeStyle(lineWidth: 1.25, dash: [6, 4])
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isTargeted) { providers in
                handleDrop(providers)
            }
        }
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = spreadsheetTypes()
        if panel.runModal() == .OK, let pickedURL = panel.url {
            url = pickedURL
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let droppedURL: URL?
            if let data = item as? Data {
                droppedURL = URL(dataRepresentation: data, relativeTo: nil)
            } else {
                droppedURL = item as? URL
            }
            guard let droppedURL, Self.isSpreadsheet(droppedURL) else { return }
            DispatchQueue.main.async {
                url = droppedURL
            }
        }
        return true
    }

    private static func isSpreadsheet(_ url: URL) -> Bool {
        ["xlsx", "xlsm", "xls"].contains(url.pathExtension.lowercased())
    }

    private func spreadsheetTypes() -> [UTType] {
        ["xlsx", "xlsm", "xls"].compactMap { UTType(filenameExtension: $0) }
    }
}
