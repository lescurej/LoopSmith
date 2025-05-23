import SwiftUI

struct ContentView: View {
    @State private var audioFiles: [AudioFileItem] = []
    @State private var isImporting: Bool = false
    @State private var outputDirectory: URL? = nil
    @State private var fadeDurationMs: Double = 30_000.0
    @State private var isExporting: Bool = false
    @State private var exportProgress: Double = 0.0
    @State private var selectedFormat: AudioFileFormat = .wav
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Button("Import audio files…") {
                    isImporting = true
                }
                .padding(.trailing)
                Button("Choose output folder…") {
                    selectOutputDirectory()
                }
                if let outputDirectory = outputDirectory {
                    Text("Output folder: \(outputDirectory.path)")
                        .font(.caption)
                }
            }
            .padding(.vertical)
            HStack {
                Text("Output format:")
                Picker("Format", selection: $selectedFormat) {
                    ForEach(AudioFileFormat.allCases, id: \.self) { format in
                        Text(format.rawValue.uppercased()).tag(format)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                Spacer()
                Text("Global fade (s):")
                Slider(value: Binding(
                    get: { fadeDurationMs / 1000 },
                    set: { fadeDurationMs = $0 * 1000 }
                ), in: 1...60, step: 1)
                Text("\(Int(fadeDurationMs / 1000)) s")
            }
            .padding(.bottom)
            Table(audioFiles) {
                TableColumn("Name") { file in
                    Text(file.fileName)
                }
                TableColumn("Duration") { file in
                    Text(file.durationString)
                }
                TableColumn("Fade (s)") { file in
                    HStack {
                        Slider(value: Binding(
                            get: { file.fadeDurationMs / 1000 },
                            set: { newValue in
                                if let idx = audioFiles.firstIndex(where: { $0.id == file.id }) {
                                    audioFiles[idx].fadeDurationMs = newValue * 1000
                                }
                            }
                        ), in: 1...60, step: 1)
                        Text("\(Int(file.fadeDurationMs / 1000)) s")
                    }
                }
            }
            .frame(minHeight: 200)
            HStack {
                Spacer()
                Button("Export files", action: exportFiles)
                    .disabled(audioFiles.isEmpty || outputDirectory == nil || isExporting)
            }
            if isExporting {
                ProgressView(value: exportProgress, total: 1.0)
                    .padding(.vertical)
            }
        }
        .padding()
        .fileImporter(isPresented: $isImporting, allowedContentTypes: AudioFileFormat.allowedUTTypes, allowsMultipleSelection: true) { result in
            handleImport(result: result)
        }
    }
    
    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                AudioFileItem.load(url: url, fadeDurationMs: fadeDurationMs) { item in
                    if let item = item {
                        DispatchQueue.main.async {
                            audioFiles.append(item)
                        }
                    }
                }
            }
        case .failure(let error):
            print("Import error:", error)
        }
    }
    
    private func selectOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK {
                outputDirectory = panel.url
            }
        }
    }
    
    private func exportFiles() {
        isExporting = true
        exportProgress = 0.0
        let filesToExport = audioFiles
        let total = filesToExport.count
        guard let outputDirectory = outputDirectory else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            var completed = 0
            for file in filesToExport {
                let baseName = file.fileName.replacingOccurrences(of: "." + file.format.rawValue, with: "")
                let outputFileName = baseName + "." + selectedFormat.rawValue
                let outputURL = outputDirectory.appendingPathComponent(outputFileName)
                print("Exporting to:", outputURL.path)
                let semaphore = DispatchSemaphore(value: 0)
                SeamlessProcessor.process(
                    inputURL: file.url,
                    outputURL: outputURL,
                    fadeDurationMs: file.fadeDurationMs,
                    format: selectedFormat
                ) { result in
                    if case .failure(let error) = result {
                        print("Error processing \(file.fileName):", error)
                    }
                    semaphore.signal()
                }
                semaphore.wait()
                completed += 1
                DispatchQueue.main.async {
                    exportProgress = Double(completed) / Double(total)
                }
            }
            DispatchQueue.main.async {
                isExporting = false
            }
        }
    }
}

#Preview {
    ContentView()
}
