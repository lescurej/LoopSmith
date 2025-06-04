import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ContentView: View {
    @State private var audioFiles: [AudioFileItem] = []
    @State private var isImporting: Bool = false
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
                Text("Glissez-déposez des fichiers audio dans la liste")
                    .font(.caption)
            }
            .padding(.vertical)
            HStack {
                Text("Global fade (s):")
                Slider(value: Binding(
                    get: { fadeDurationMs / 1000 },
                    set: { fadeDurationMs = $0 * 1000 }
                ), in: 1...60)
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
                TableColumn("Waveform") { file in
                    WaveformView(samples: file.waveform)
                        .frame(height: 30)
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
                        ), in: 1...60)
                        Text("\(Int(file.fadeDurationMs / 1000)) s")
                    }
                }
                TableColumn("Fade %") { file in
                    let percent = file.duration > 0 ? (file.fadeDurationMs / (file.duration * 1000)) * 100 : 0
                    Text(String(format: "%.0f%%", percent))
                }
                TableColumn("Progress") { file in
                    ProgressView(value: file.progress, total: 1.0)
                        .frame(width: 100)
                }
            }
            .frame(minHeight: 200)
            .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { providers in
                handleDrop(providers: providers)
            }
            HStack {
                Spacer()
                Button("Export files", action: exportFiles)
                    .disabled(audioFiles.isEmpty || isExporting)
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

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (data, _) in
                    if let urlData = data as? Data,
                       let url = NSURL(absoluteURLWithDataRepresentation: urlData, relativeTo: nil) as URL? ,
                       AudioFileFormat(url: url) != nil {
                        AudioFileItem.load(url: url, fadeDurationMs: fadeDurationMs) { item in
                            if let item = item {
                                DispatchQueue.main.async {
                                    audioFiles.append(item)
                                }
                            }
                        }
                    }
                }
            }
        }
        return true
    }
    
    private func exportFiles() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.begin { response in
            if response == .OK, let outputDirectory = panel.url {
                startExport(to: outputDirectory)
            }
        }
    }

    private func startExport(to outputDirectory: URL) {
        isExporting = true
        exportProgress = 0.0

        let filesToExport = audioFiles
        let group = DispatchGroup()

        for file in filesToExport {
            group.enter()
            updateFileProgress(fileID: file.id, progress: 0)

            let baseName = file.fileName.replacingOccurrences(of: "." + file.format.rawValue, with: "")
            let outputFileName = "LOOP_" + baseName + "." + selectedFormat.rawValue
            let outputURL = outputDirectory.appendingPathComponent(outputFileName)

            DispatchQueue.global(qos: .userInitiated).async {
                SeamlessProcessor.process(
                    inputURL: file.url,
                    outputURL: outputURL,
                    fadeDurationMs: file.fadeDurationMs,
                    format: selectedFormat,
                    progress: { percent in
                        updateFileProgress(fileID: file.id, progress: percent)
                    }
                ) { result in
                    if case .failure(let error) = result {
                        print("Error processing \(file.fileName):", error)
                    }
                    DispatchQueue.main.async {
                        updateFileProgress(fileID: file.id, progress: 1.0)
                        group.leave()
                    }
                }
            }
        }

        group.notify(queue: .main) {
            isExporting = false
        }
    }

    private func updateFileProgress(fileID: UUID, progress: Double) {
        if let idx = audioFiles.firstIndex(where: { $0.id == fileID }) {
            audioFiles[idx].progress = progress
        }
        let total = audioFiles.reduce(0.0) { $0 + $1.progress }
        exportProgress = total / Double(audioFiles.count)
    }
}

#Preview {
    ContentView()
}
