import SwiftUI
import Photos

struct ProcessingView: View {
    @StateObject private var viewModel: ProcessingViewModel

    init(viewModel: ProcessingViewModel? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel ?? ProcessingViewModel(
            photoService: PhotoLibraryService(),
            ocrService: OCRService(),
            classifier: ScreenshotClassifier(),
            musicExtractor: MusicExtractor(),
            movieExtractor: MovieExtractor(),
            bookExtractor: BookExtractor(),
            youtubeService: YouTubeService(),
            tmdbService: TMDbService(),
            googleBooksService: GoogleBooksService(),
            authService: AuthService(),
            googleDocsService: GoogleDocsService()
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Photo Permission Status
                    permissionSection

                    // YouTube Auth Status
                    AuthStatusView(
                        isAuthenticated: viewModel.isYouTubeAuthenticated,
                        onLogin: { await viewModel.authenticateYouTube() },
                        onLogout: { viewModel.signOutYouTube() }
                    )

                    // Process Button
                    processButton

                    // Progress
                    if viewModel.isProcessing {
                        progressSection
                    }

                    // Error
                    if let error = viewModel.lastError {
                        errorSection(error)
                    }

                    // Results
                    if !viewModel.results.isEmpty {
                        resultsSection
                    }

                    // Google Doc Section (always show after processing to display status/errors)
                    googleDocSection
                }
                .padding()
            }
            .navigationTitle("ScreenSort")
            .onAppear {
                viewModel.checkInitialState()
            }
        }
    }

    // MARK: - Permission Section

    @ViewBuilder
    private var permissionSection: some View {
        HStack {
            Image(systemName: permissionIcon)
                .foregroundColor(permissionColor)

            Text(permissionText)
                .font(.subheadline)

            Spacer()

            if viewModel.photoPermissionStatus == .notDetermined {
                Button("Grant Access") {
                    Task {
                        await viewModel.requestPhotoAccess()
                    }
                }
                .buttonStyle(.bordered)
            } else if viewModel.photoPermissionStatus == .denied {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }

    private var permissionIcon: String {
        switch viewModel.photoPermissionStatus {
        case .authorized:
            return "photo.fill.on.rectangle.fill"
        case .limited:
            return "photo.on.rectangle"
        case .denied, .restricted:
            return "xmark.circle.fill"
        case .notDetermined:
            return "questionmark.circle.fill"
        @unknown default:
            return "questionmark.circle.fill"
        }
    }

    private var permissionColor: Color {
        switch viewModel.photoPermissionStatus {
        case .authorized:
            return .green
        case .limited:
            return .orange
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .gray
        @unknown default:
            return .gray
        }
    }

    private var permissionText: String {
        switch viewModel.photoPermissionStatus {
        case .authorized:
            return "Full Photo Access"
        case .limited:
            return "Limited Photo Access"
        case .denied:
            return "Photo Access Denied"
        case .restricted:
            return "Photo Access Restricted"
        case .notDetermined:
            return "Photo Access Not Set"
        @unknown default:
            return "Unknown Status"
        }
    }

    // MARK: - Process Button

    @ViewBuilder
    private var processButton: some View {
        Button(action: {
            Task {
                await viewModel.processNow()
            }
        }) {
            HStack {
                Image(systemName: "play.fill")
                Text("Process Now")
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .buttonStyle(.borderedProminent)
        .disabled(!viewModel.hasPhotoAccess || !viewModel.isYouTubeAuthenticated || viewModel.isProcessing)
    }

    // MARK: - Progress Section

    @ViewBuilder
    private var progressSection: some View {
        VStack(spacing: 10) {
            ProgressView(value: Double(viewModel.processingProgress.current),
                        total: Double(max(viewModel.processingProgress.total, 1)))

            Text("Processing \(viewModel.processingProgress.current) of \(viewModel.processingProgress.total)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }

    // MARK: - Error Section

    @ViewBuilder
    private func errorSection(_ error: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(error)
                .font(.caption)
                .foregroundColor(.red)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.1))
        .cornerRadius(10)
    }

    // MARK: - Results Section

    @ViewBuilder
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Results")
                    .font(.headline)

                Spacer()

                // Summary badges
                resultsSummary
            }

            ForEach(viewModel.results) { result in
                resultRow(result)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }

    @ViewBuilder
    private var resultsSummary: some View {
        let grouped = Dictionary(grouping: viewModel.results) { $0.contentType }

        HStack(spacing: 8) {
            ForEach(ScreenshotType.allCases, id: \.self) { type in
                if let count = grouped[type]?.count, count > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: type.iconName)
                            .font(.caption)
                        Text("\(count)")
                            .font(.caption)
                    }
                    .foregroundColor(contentTypeColor(type))
                }
            }
        }
    }

    @ViewBuilder
    private func resultRow(_ result: ProcessingResultItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Content type icon
            Image(systemName: result.contentType.iconName)
                .foregroundColor(contentTypeColor(result.contentType))
                .frame(width: 24)

            // Status icon
            Image(systemName: resultIcon(for: result.status))
                .foregroundColor(resultColor(for: result.status))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                // Title and creator
                if let title = result.title {
                    if let creator = result.creator {
                        Text("\(title) - \(creator)")
                            .font(.subheadline)
                            .lineLimit(2)
                    } else {
                        Text(title)
                            .font(.subheadline)
                            .lineLimit(2)
                    }
                }

                // Message
                Text(result.message)
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Service link if available
                if let link = result.serviceLink, let url = URL(string: link) {
                    Link(destination: url) {
                        HStack(spacing: 4) {
                            Image(systemName: serviceLinkIcon(for: result.contentType))
                                .font(.caption)
                            Text(serviceLinkLabel(for: result.contentType))
                                .font(.caption)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func contentTypeColor(_ type: ScreenshotType) -> Color {
        switch type {
        case .music:
            return .pink
        case .movie:
            return .purple
        case .book:
            return .orange
        case .meme:
            return .green
        case .unknown:
            return .gray
        }
    }

    private func serviceLinkIcon(for type: ScreenshotType) -> String {
        switch type {
        case .music:
            return "play.rectangle.fill"
        case .movie:
            return "film"
        case .book:
            return "book.closed.fill"
        case .meme, .unknown:
            return "link"
        }
    }

    private func serviceLinkLabel(for type: ScreenshotType) -> String {
        switch type {
        case .music:
            return "Open in YouTube"
        case .movie:
            return "View on TMDb"
        case .book:
            return "View on Google Books"
        case .meme, .unknown:
            return "Open Link"
        }
    }

    private func resultIcon(for status: ProcessingResultItem.Status) -> String {
        switch status {
        case .success: return "checkmark.circle.fill"
        case .flagged: return "flag.fill"
        case .failed: return "xmark.circle.fill"
        }
    }

    private func resultColor(for status: ProcessingResultItem.Status) -> Color {
        switch status {
        case .success: return .green
        case .flagged: return .orange
        case .failed: return .red
        }
    }

    // MARK: - Google Doc Section

    @ViewBuilder
    private var googleDocSection: some View {
        // Only show if we have URL, status, or error to display
        if viewModel.googleDocURL != nil || viewModel.googleDocsStatus != nil || viewModel.googleDocsError != nil {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(viewModel.googleDocsError != nil ? .orange : .blue)

                    Text("Google Docs Log")
                        .font(.subheadline)

                    Spacer()

                    if let url = viewModel.googleDocURL, let docURL = URL(string: url) {
                        Link("Open", destination: docURL)
                            .font(.subheadline)
                    }
                }

                // Status message
                if let status = viewModel.googleDocsStatus {
                    Text(status)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Error message
                if let error = viewModel.googleDocsError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
}

#Preview {
    ProcessingView()
}
