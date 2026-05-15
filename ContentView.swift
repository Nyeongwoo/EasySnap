import SwiftUI
import UniformTypeIdentifiers
import AVFoundation
import PDFKit

enum FileType: Equatable, Sendable {
    case video
    case pdf
}

enum VideoStatus: Sendable {
    case waiting
    case processing
    case completed
    case failed(String)
}

struct VideoItem: Identifiable, Sendable {
    let id = UUID()
    let url: URL
    let fileType: FileType
    var thumbnail: NSImage?
    var thumbnailFailed: Bool = false
    var status: VideoStatus = .waiting
}

struct VideoRowView: View {
    let item: VideoItem
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black)
                    .frame(width: 80, height: 45)

                if let thumb = item.thumbnail {
                    Image(nsImage: thumb)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 45)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else if item.thumbnailFailed {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.secondary)
                } else {
                    Image(systemName: item.fileType == .pdf ? "doc.fill" : "film")
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.url.lastPathComponent.removingPercentEncoding ?? item.url.lastPathComponent)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.middle)

                switch item.status {
                case .waiting:
                    EmptyView()
                case .processing:
                    HStack(spacing: 4) {
                        ProgressView().scaleEffect(0.6)
                        Text(NSLocalizedString("processing", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                case .completed:
                    Text(NSLocalizedString("complete", comment: ""))
                        .font(.caption)
                        .foregroundColor(.green)
                case .failed:
                    Text(NSLocalizedString("error_exec", comment: ""))
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .disabled({
                if case .processing = item.status { return true }
                return false
            }())
        }
        .padding(8)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

actor ExtractionActor {
    func extractVideo(
        ffmpeg: String,
        inputURL: URL,
        outputURL: URL,
        fps: Double,
        qualityArgs: [String],
        outputFormat: String
    ) throws -> Bool {
        let outputPattern = outputURL.appendingPathComponent("frame_%04d.\(outputFormat)").path(percentEncoded: false)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpeg)
        process.arguments = [
            "-i", inputURL.path(percentEncoded: false),
            "-vf", "fps=\(fps)",
        ] + qualityArgs + [outputPattern]

        let pipe = Pipe()
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        return process.terminationStatus == 0
    }

    func extractPDF(
        inputURL: URL,
        outputURL: URL,
        outputFormat: String
    ) -> Bool {
        guard let pdf = PDFDocument(url: inputURL) else { return false }
        let pageCount = pdf.pageCount

        for i in 0..<pageCount {
            guard let page = pdf.page(at: i) else { continue }
            let pageRect = page.bounds(for: .mediaBox)

            let scale: CGFloat = 2.0
            let width = Int(pageRect.width * scale)
            let height = Int(pageRect.height * scale)

            guard let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ) else { continue }

            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.scaleBy(x: scale, y: scale)
            page.draw(with: .mediaBox, to: context)

            guard let cgImage = context.makeImage() else { continue }

            let pageNum = String(format: "%04d", i + 1)
            let outputFile = outputURL.appendingPathComponent("page_\(pageNum).\(outputFormat)")

            let imageRep = NSBitmapImageRep(cgImage: cgImage)
            if outputFormat == "jpg" {
                let data = imageRep.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
                try? data?.write(to: outputFile)
            } else {
                let data = imageRep.representation(using: .png, properties: [:])
                try? data?.write(to: outputFile)
            }
        }
        return true
    }
}

struct ContentView: View {
    @State private var videoItems: [VideoItem] = []
    @State private var interval: Double = 1.0
    @State private var isProcessing = false
    @State private var isCompleted = false
    @State private var processedCount: Int = 0
    @State private var totalCount: Int = 0
    @State private var isDragging = false
    @State private var outputFormat: String = "png"
    @State private var quality: String = "high"
    @AppStorage("colorScheme") private var colorSchemePreference: String = "system"
    @AppStorage("outputDirectory") private var outputDirectory: String = ""
    @Environment(\.colorScheme) var colorScheme

    private let rowHeight: CGFloat = 61
    private let rowSpacing: CGFloat = 6
    private let maxVisibleRows: Int = 3
    private let extractor = ExtractionActor()

    var outputURL: URL {
        if outputDirectory.isEmpty {
            return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        }
        return URL(fileURLWithPath: outputDirectory)
    }

    var shortOutputPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let full = outputURL.path
        let tilde = full.replacingOccurrences(of: home, with: "~")
        let components = tilde.components(separatedBy: "/")
        if components.count >= 2 {
            return components.suffix(2).joined(separator: "/")
        }
        return tilde
    }

    var hasVideoItems: Bool {
        videoItems.contains { $0.fileType == .video }
    }

    var listHeight: CGFloat {
        let count = min(videoItems.count, maxVisibleRows)
        return CGFloat(count) * rowHeight + CGFloat(count - 1) * rowSpacing
    }

    var intervalDescription: String {
        let fps = 1.0 / interval
        if fps >= 1 {
            let rounded = Int(fps.rounded())
            return String(format: NSLocalizedString("fps_per_sec", comment: ""), rounded)
        } else {
            let secs = Int(interval.rounded())
            return String(format: NSLocalizedString("fps_per_secs", comment: ""), secs)
        }
    }

    var qualityArgs: [String] {
        if outputFormat == "jpg" {
            switch quality {
            case "low":    return ["-q:v", "10"]
            case "medium": return ["-q:v", "5"]
            default:       return ["-q:v", "2"]
            }
        } else {
            switch quality {
            case "low":    return ["-compression_level", "9"]
            case "medium": return ["-compression_level", "5"]
            default:       return ["-compression_level", "1"]
            }
        }
    }

    var logoName: String {
        switch colorSchemePreference {
        case "dark": return "easysnap"
        case "light": return "easysnap_dark"
        default: return colorScheme == .dark ? "easysnap" : "easysnap_dark"
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 8)

            VStack(spacing: 0) {
                Image(logoName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)

                Spacer().frame(height: 10)

                Text("EasySnap+")
                    .font(.title)
                    .fontWeight(.bold)

                Spacer().frame(height: 10)
            }
            .padding(.bottom, 4)

            if videoItems.isEmpty {
                dropZone
            } else if videoItems.count == 1 {
                singleItemView
            } else {
                multiItemView
            }

            if hasVideoItems {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(NSLocalizedString("extract_interval", comment: ""))
                            .fontWeight(.medium)
                        Spacer()
                        Text(intervalDescription)
                            .foregroundColor(.accentColor)
                            .fontWeight(.medium)
                    }
                    CustomSlider(value: $interval, range: 0.1...60, step: 0.1)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(NSLocalizedString("output_format", comment: ""))
                    .fontWeight(.medium)
                Picker("", selection: $outputFormat) {
                    Text("PNG").tag("png")
                    Text("JPG").tag("jpg")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: .infinity)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(NSLocalizedString("quality", comment: ""))
                    .fontWeight(.medium)
                Picker("", selection: $quality) {
                    Text("Low").tag("low")
                    Text("Medium").tag("medium")
                    Text("High").tag("high")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: .infinity)
            }

            HStack(spacing: 4) {
                Image(systemName: "folder")
                    .foregroundColor(.secondary)
                    .font(.caption)
                Text(String(format: NSLocalizedString("save_location", comment: ""), shortOutputPath))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: { Task { await extractFrames() } }) {
                HStack {
                    if isProcessing {
                        ProgressView().scaleEffect(0.8)
                    }
                    Text(isProcessing ?
                         NSLocalizedString("processing", comment: "") :
                         NSLocalizedString("start_button", comment: ""))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(videoItems.isEmpty || isProcessing)
            .controlSize(.large)
            .frame(maxWidth: .infinity, minHeight: 50)

            if isProcessing {
                VStack(spacing: 4) {
                    ProgressView(value: totalCount > 0 ? Double(processedCount) / Double(totalCount) : 0)
                        .progressViewStyle(.linear)
                    Text("\(processedCount)/\(totalCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if isCompleted {
                Text(NSLocalizedString("complete", comment: ""))
                    .foregroundColor(.green)
                    .fontWeight(.medium)
                    .font(.callout)
            } else if !isCompleted && processedCount > 0 {
                Text(NSLocalizedString("error_exec", comment: ""))
                    .foregroundColor(.red)
                    .fontWeight(.medium)
                    .font(.callout)
            }
        }
        .padding(24)
        .frame(minWidth: 360, maxWidth: 360)
    }

    var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(isDragging ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))

            VStack(spacing: 6) {
                Text(NSLocalizedString("drop_video", comment: ""))
                    .foregroundColor(.secondary)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 160, maxHeight: 160)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture { selectVideoFile() }
        .onDrop(of: ["public.file-url"], isTargeted: $isDragging) { providers in
            handleDrop(providers: providers)
            return true
        }
    }

    var singleItemView: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.1))

                if let thumb = videoItems.first?.thumbnail {
                    GeometryReader { geo in
                        ZStack {
                            Color.black
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            Image(nsImage: thumb)
                                .resizable()
                                .scaledToFit()
                                .frame(width: geo.size.width, height: geo.size.height)
                        }
                    }

                    VStack {
                        Spacer()
                        Text(videoItems.first?.url.lastPathComponent.removingPercentEncoding ?? videoItems.first?.url.lastPathComponent ?? "")
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(8)
                    }
                } else if videoItems.first?.thumbnailFailed == true {
                    VStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text(videoItems.first?.url.lastPathComponent.removingPercentEncoding ?? videoItems.first?.url.lastPathComponent ?? "")
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(.horizontal, 12)
                        Text(NSLocalizedString("thumbnail_failed", comment: ""))
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                } else {
                    VStack(spacing: 6) {
                        ProgressView().scaleEffect(0.8)
                        Text(videoItems.first?.url.lastPathComponent.removingPercentEncoding ?? videoItems.first?.url.lastPathComponent ?? "")
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(.horizontal, 12)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 160, maxHeight: 160)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button(action: { videoItems.removeAll() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.4), radius: 2)
            }
            .buttonStyle(.plain)
            .padding(8)
        }
        .onDrop(of: ["public.file-url"], isTargeted: $isDragging) { providers in
            handleDrop(providers: providers)
            return true
        }
    }

    var multiItemView: some View {
        VStack(spacing: 8) {
            ScrollView {
                VStack(spacing: rowSpacing) {
                    ForEach(videoItems) { item in
                        VideoRowView(item: item) {
                            videoItems.removeAll { $0.id == item.id }
                        }
                    }
                }
            }
            .frame(height: listHeight)

            Button(action: selectVideoFile) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle")
                    Text(NSLocalizedString("add_files", comment: ""))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .onDrop(of: ["public.file-url"], isTargeted: $isDragging) { providers in
                handleDrop(providers: providers)
                return true
            }
        }
    }

    func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadDataRepresentation(forTypeIdentifier: "public.file-url") { data, _ in
                if let data = data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        addVideoItem(url: url)
                    }
                }
            }
        }
    }

    func addVideoItem(url: URL) {
        let decodedURL = URL(fileURLWithPath: url.path(percentEncoded: false))
        guard !videoItems.contains(where: { $0.url == decodedURL }) else { return }
        let ext = decodedURL.pathExtension.lowercased()
        let fileType: FileType = ext == "pdf" ? .pdf : .video
        let item = VideoItem(url: decodedURL, fileType: fileType)
        videoItems.append(item)
        let id = item.id
        if fileType == .pdf {
            generatePDFThumbnail(for: decodedURL) { image, failed in
                if let idx = videoItems.firstIndex(where: { $0.id == id }) {
                    videoItems[idx].thumbnail = image
                    videoItems[idx].thumbnailFailed = failed
                }
            }
        } else {
            generateThumbnail(for: decodedURL) { image, failed in
                if let idx = videoItems.firstIndex(where: { $0.id == id }) {
                    videoItems[idx].thumbnail = image
                    videoItems[idx].thumbnailFailed = failed
                }
            }
        }
    }

    func generateThumbnail(for url: URL, completion: @escaping (NSImage?, Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let asset = AVAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 600, height: 400)

            let time = CMTime(seconds: 1, preferredTimescale: 60)
            if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                let image = NSImage(cgImage: cgImage, size: .zero)
                DispatchQueue.main.async { completion(image, false) }
            } else {
                DispatchQueue.main.async { completion(nil, true) }
            }
        }
    }

    func generatePDFThumbnail(for url: URL, completion: @escaping (NSImage?, Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let pdf = PDFDocument(url: url),
                  let page = pdf.page(at: 0) else {
                DispatchQueue.main.async { completion(nil, true) }
                return
            }
            let pageRect = page.bounds(for: .mediaBox)
            let image = NSImage(size: pageRect.size)
            image.lockFocus()
            if let context = NSGraphicsContext.current?.cgContext {
                context.setFillColor(NSColor.white.cgColor)
                context.fill(pageRect)
                page.draw(with: .mediaBox, to: context)
            }
            image.unlockFocus()
            DispatchQueue.main.async { completion(image, false) }
        }
    }

    func selectVideoFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .video, .mpeg4Movie, .quickTimeMovie, .pdf]
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            for url in panel.urls {
                addVideoItem(url: url)
            }
        }
    }

    func extractFrames() async {
        guard !videoItems.isEmpty else { return }
        guard let ffmpeg = Bundle.main.path(forResource: "ffmpeg", ofType: nil) else { return }

        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: ffmpeg
        )

        isProcessing = true
        isCompleted = false
        processedCount = 0

        let itemsToProcess = videoItems.indices.filter {
            if case .completed = videoItems[$0].status { return false }
            return true
        }

        totalCount = itemsToProcess.count

        let snapshots: [(idx: Int, url: URL, fileType: FileType)] = itemsToProcess.map {
            (idx: $0, url: videoItems[$0].url, fileType: videoItems[$0].fileType)
        }

        let currentOutputURL = outputURL
        let currentOutputFormat = outputFormat
        let currentQualityArgs = qualityArgs
        let currentInterval = interval

        var allSucceeded = true

        for snap in snapshots {
            videoItems[snap.idx].status = .processing

            let rawFolderName = snap.url.deletingPathExtension().lastPathComponent
            let folderName = rawFolderName.removingPercentEncoding ?? rawFolderName
            let autoOutputURL = currentOutputURL.appendingPathComponent(folderName)

            do {
                try FileManager.default.createDirectory(at: autoOutputURL, withIntermediateDirectories: true)
            } catch {
                videoItems[snap.idx].status = .failed(error.localizedDescription)
                processedCount += 1
                allSucceeded = false
                continue
            }

            let fileType = snap.fileType
            let snapURL = snap.url
            let snapIdx = snap.idx

            if fileType == .pdf {
                let success = await extractor.extractPDF(
                    inputURL: snapURL,
                    outputURL: autoOutputURL,
                    outputFormat: currentOutputFormat
                )
                videoItems[snapIdx].status = success ? .completed : .failed("PDF extraction failed")
                processedCount += 1
                if !success { allSucceeded = false }
            } else {
                let fps = 1.0 / currentInterval
                do {
                    let success = try await extractor.extractVideo(
                        ffmpeg: ffmpeg,
                        inputURL: snapURL,
                        outputURL: autoOutputURL,
                        fps: fps,
                        qualityArgs: currentQualityArgs,
                        outputFormat: currentOutputFormat
                    )
                    if success {
                        videoItems[snapIdx].status = .completed
                    } else {
                        videoItems[snapIdx].status = .failed(NSLocalizedString("error_exec", comment: ""))
                        allSucceeded = false
                    }
                } catch {
                    videoItems[snapIdx].status = .failed(error.localizedDescription)
                    allSucceeded = false
                }
                processedCount += 1
            }
        }

        isProcessing = false
        if allSucceeded {
            isCompleted = true
            withAnimation {
                videoItems.removeAll()
            }
        } else {
            isCompleted = false
        }
    }
}

#Preview {
    ContentView()
}
