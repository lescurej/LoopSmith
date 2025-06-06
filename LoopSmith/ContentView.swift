import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ContentView: View {
    @State private var audioFiles: [AudioFileItem] = []
    @State private var isImporting: Bool = false
    @State private var isExporting: Bool = false
    @State private var exportProgress: Double = 0.0
    @State private var exportCompleted: Bool = false
    @State private var selectedFormat: AudioFileFormat = .wav

    var body: some View {
        VStack(alignment: .leading) {
            headerView
            importSection
            filesTableSection
            exportSection
            progressSection
        }
        .padding()
        .background(Color.backgroundPrimary)
        .fileImporter(isPresented: $isImporting, allowedContentTypes: AudioFileFormat.allowedUTTypes, allowsMultipleSelection: true) { result in
            handleImport(result: result)
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [.accentMain, .accentSecondary]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
            HStack {
                Image("title")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(Color("AccentColor"))
                    .padding(.top, 5.0)
                    .frame(maxWidth: .infinity, maxHeight: 50)

                Spacer()
            }
            .padding(.bottom, -15)
        }
    }

    private var importSection: some View {
        HStack {
            Button {
                isImporting = true
            } label: {
                Label("Import", systemImage: "square.and.arrow.down")
                    .padding(.horizontal)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentMain)

            Spacer()

            Text("Drag and drop audio files into the list")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical)
    }

    private var filesTableSection: some View {
        Table(audioFiles) {
            TableColumn("Name") { file in
                Text(file.fileName)
                    .font(.body)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.backgroundSecondary))
            }
            TableColumn("Duration") { file in
                Text(file.durationString)
                    .monospacedDigit()
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.backgroundSecondary))
            }
            TableColumn("Waveform") { file in
                WaveformView(samples: file.waveform)
                    .frame(height: 30)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.backgroundSecondary))
            }
            TableColumn("Fade (%)") { file in
                // 1️⃣ Calculer d’abord le pourcentage
                let percent: Double = {
                    guard file.duration > 0 else { return 0 }
                    return (file.fadeDurationMs / (file.duration * 1_000)) * 100
                }()

                // 2️⃣ Créer un Binding<Double> pour le Slider
                let fadeBinding = Binding<Double>(
                    get: {
                        guard let idx = audioFiles.firstIndex(where: { $0.id == file.id }) else { return percent }
                        let f = audioFiles[idx]
                        return (f.duration > 0) ? (f.fadeDurationMs / (f.duration * 1_000)) * 100 : 0
                    },
                    set: { newPercent in
                        if let idx = audioFiles.firstIndex(where: { $0.id == file.id }) {
                            audioFiles[idx].fadeDurationMs = (newPercent / 100) * audioFiles[idx].duration * 1_000
                        }
                    }
                )

                // 3️⃣ Construire le HStack avec Slider, pastille colorée et texte
                HStack {
                    Slider(value: fadeBinding, in: 0...100)
                        .tint(.accentColor)
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 4)

                    Circle()
                        .fill(gradientColor(for: percent))
                        .frame(width: 8, height: 8)

                    Text(String(format: "%.0f%%", percent))
                        .monospacedDigit()
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.backgroundSecondary)
                )
            }
            // Appliquer le modificateur `.width(min:ideal:)` à la colonne Fade (%)
            .width(min: 200, ideal: 260)

            TableColumn("Crossfade Mode") { file in
                Picker("", selection: Binding(
                    get: { file.crossfadeMode },
                    set: { newVal in
                        if let idx = audioFiles.firstIndex(where: { $0.id == file.id }) {
                            audioFiles[idx].crossfadeMode = newVal
                        }
                    }
                )) {
                    ForEach(CrossfadeMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .labelsHidden()
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.backgroundSecondary))
            }
            TableColumn("Preview") { file in
                PreviewButton(file: file, isExporting: $isExporting)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.backgroundSecondary))
            }
            TableColumn("Progress") { file in
                if let url = file.exportedURL, file.progress >= 1.0 {
                    Button("Open Folder") {
                        NSWorkspace.shared.open(url.deletingLastPathComponent())
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.backgroundSecondary))
                } else {
                    ProgressBar(progress: file.progress)
                        .frame(width: 100)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.backgroundSecondary))
                }
            }

            TableColumn("Exported Path") { file in
                Text(file.exportedURL?.path ?? "-")
                    .lineLimit(1)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.backgroundSecondary))
            }

            TableColumn("") { file in
                Button(action: { audioFiles.removeAll { $0.id == file.id } }) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.backgroundSecondary))
            }
        }
        .frame(minHeight: 200)
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
    }

    private var exportSection: some View {
        HStack {
            Button("Clear exported", action: clearExported)
                .disabled(!audioFiles.contains { $0.exportedURL != nil })
            Spacer()
            Button("Export files", action: exportFiles)
                .disabled(audioFiles.isEmpty || isExporting)
        }
    }

    private var progressSection: some View {
        Group {
            if isExporting {
                ProgressView(value: exportProgress, total: 1.0)
                    .tint(.accentSecondary)
                    .padding(.vertical)
            } else if exportCompleted {
                Text("Export terminé")
                    .foregroundColor(.green)
                    .padding(.vertical)
            }
        }
    }

    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                AudioFileItem.load(url: url) { item in
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
                       let url = NSURL(absoluteURLWithDataRepresentation: urlData, relativeTo: nil) as URL?,
                       AudioFileFormat(url: url) != nil {
                        AudioFileItem.load(url: url) { item in
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
        exportCompleted = false

        let filesToExport = audioFiles
        let group = DispatchGroup()

        for file in filesToExport {
            group.enter()
            updateFileProgress(fileID: file.id, progress: 0)

            let outputURL = file.outputURL(in: outputDirectory, format: selectedFormat)

            DispatchQueue.global(qos: .userInitiated).async {
                SeamlessProcessor.process(
                    inputURL: file.url,
                    outputURL: outputURL,
                    fadeDurationMs: file.fadeDurationMs,
                    format: selectedFormat,
                    crossfadeMode: file.crossfadeMode,
                    bpm: file.bpm,
                    progress: { percent in
                        updateFileProgress(fileID: file.id, progress: percent)
                    }
                ) { result in
                    if case .failure(let error) = result {
                        print("Error processing \(file.fileName):", error)
                    }
                    DispatchQueue.main.async {
                        updateFileProgress(fileID: file.id, progress: 1.0)
                        markFileExported(fileID: file.id, url: outputURL)
                        group.leave()
                    }
                }
            }
        }

        group.notify(queue: .main) {
            isExporting = false
            exportCompleted = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                exportCompleted = false
            }
        }
    }

    private func updateFileProgress(fileID: UUID, progress: Double) {
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.25)) {
                if let idx = audioFiles.firstIndex(where: { $0.id == fileID }) {
                    audioFiles[idx].progress = progress
                }
                let total = audioFiles.reduce(0.0) { $0 + $1.progress }
                exportProgress = total / Double(audioFiles.count)
            }
        }
    }

    private func markFileExported(fileID: UUID, url: URL) {
        if let idx = audioFiles.firstIndex(where: { $0.id == fileID }) {
            audioFiles[idx].exportedURL = url
        }
    }

    private func gradientColor(for percent: Double) -> Color {
        let hue = (100 - percent) / 300
        return Color(hue: hue, saturation: 0.9, brightness: 0.9)
    }

    private func clearExported() {
        audioFiles.removeAll { $0.exportedURL != nil }
    }
}

#Preview {
    ContentView()
}
