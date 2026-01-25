import SwiftUI
import Photos

struct ProcessingView: View {
    @StateObject private var viewModel: ProcessingViewModel

    init(viewModel: ProcessingViewModel? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel ?? ProcessingViewModel(
            photoService: PhotoLibraryService(),
            extractor: MusicExtractor(),
            youtubeService: YouTubeService(),
            authService: AuthService()
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
            Text("Results")
                .font(.headline)

            ForEach(viewModel.results) { result in
                HStack {
                    Image(systemName: resultIcon(for: result.status))
                        .foregroundColor(resultColor(for: result.status))

                    VStack(alignment: .leading) {
                        if let title = result.songTitle, let artist = result.artist {
                            Text("\(title) - \(artist)")
                                .font(.subheadline)
                        }
                        Text(result.message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
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
}

#Preview {
    ProcessingView()
}
