import SwiftUI
import Photos

struct ProcessingView: View {
    @State private var viewModel = ProcessingViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                // iOS 26 Liquid Glass background
                backgroundGradient

                ScrollView {
                    VStack(spacing: 16) {
                        // Status Cards
                        statusCardsSection

                        // Process Button
                        processButton
                            .padding(.top, 8)

                        // Progress
                        if viewModel.isProcessing {
                            progressSection
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }

                        // Error
                        if let error = viewModel.lastError {
                            errorSection(error)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // Results
                        if !viewModel.results.isEmpty {
                            resultsSection
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        // Google Doc Section
                        googleDocSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("ScreenSort")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                viewModel.checkInitialState()
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.isProcessing)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.lastError)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.results.count)
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color(.systemGray6).opacity(0.5)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Status Cards Section

    private var statusCardsSection: some View {
        VStack(spacing: 12) {
            // Photo Permission Card
            GlassCard {
                HStack(spacing: 14) {
                    // Icon with gradient background
                    Circle()
                        .fill(permissionColor.gradient)
                        .frame(width: 44, height: 44)
                        .overlay {
                            Image(systemName: permissionIcon)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Photo Library")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text(permissionText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if viewModel.photoPermissionStatus == .notDetermined {
                        Button("Allow") {
                            Task {
                                await viewModel.requestPhotoAccess()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .controlSize(.small)
                    } else if viewModel.photoPermissionStatus == .denied {
                        Button("Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .controlSize(.small)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }

            // Google Auth Card
            GlassCard {
                HStack(spacing: 14) {
                    Circle()
                        .fill(viewModel.isYouTubeAuthenticated ? Color.green.gradient : Color.red.gradient)
                        .frame(width: 44, height: 44)
                        .overlay {
                            Image(systemName: "person.crop.circle.badge.checkmark")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                                .symbolRenderingMode(.hierarchical)
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Google Account")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text(viewModel.isYouTubeAuthenticated ? "Connected" : "Sign in required")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if viewModel.isYouTubeAuthenticated {
                        Button("Sign Out") {
                            viewModel.signOutYouTube()
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .controlSize(.small)
                        .tint(.secondary)
                    } else {
                        Button("Sign In") {
                            Task {
                                await viewModel.authenticateYouTube()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    private var permissionIcon: String {
        switch viewModel.photoPermissionStatus {
        case .authorized: return "photo.stack.fill"
        case .limited: return "photo.on.rectangle"
        case .denied, .restricted: return "xmark.circle.fill"
        case .notDetermined: return "photo.badge.plus"
        @unknown default: return "questionmark.circle"
        }
    }

    private var permissionColor: Color {
        switch viewModel.photoPermissionStatus {
        case .authorized: return .green
        case .limited: return .orange
        case .denied, .restricted: return .red
        case .notDetermined: return .blue
        @unknown default: return .gray
        }
    }

    private var permissionText: String {
        switch viewModel.photoPermissionStatus {
        case .authorized: return "Full access granted"
        case .limited: return "Limited access"
        case .denied: return "Access denied"
        case .restricted: return "Access restricted"
        case .notDetermined: return "Permission needed"
        @unknown default: return "Unknown"
        }
    }

    // MARK: - Process Button

    private var processButton: some View {
        let isEnabled = viewModel.hasPhotoAccess && viewModel.isYouTubeAuthenticated && !viewModel.isProcessing

        return Button(action: {
            Task {
                await viewModel.processNow()
            }
        }) {
            HStack(spacing: 12) {
                if viewModel.isProcessing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "sparkles")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                }

                Text(viewModel.isProcessing ? "Processing..." : "Process Screenshots")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background {
                if isEnabled {
                    LinearGradient(
                        colors: [.accentColor, .accentColor.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    Color.gray.opacity(0.3)
                }
            }
            .foregroundStyle(isEnabled ? .white : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: isEnabled ? .accentColor.opacity(0.3) : .clear, radius: 12, y: 6)
        }
        .disabled(!isEnabled)
        .animation(.spring(response: 0.3), value: isEnabled)
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        GlassCard {
            VStack(spacing: 14) {
                HStack {
                    Text("Processing")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Spacer()

                    Text("\(viewModel.processingProgress.current)/\(viewModel.processingProgress.total)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                ProgressView(
                    value: Double(viewModel.processingProgress.current),
                    total: Double(max(viewModel.processingProgress.total, 1))
                )
                .tint(.accentColor)
            }
        }
    }

    // MARK: - Error Section

    private func errorSection(_ error: String) -> some View {
        GlassCard(tint: .red) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(.red)
                    .symbolRenderingMode(.hierarchical)

                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Spacer()
            }
        }
    }

    // MARK: - Results Section

    private var resultsSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Results")
                        .font(.headline)

                    Spacer()

                    resultsSummary
                }

                Divider()
                    .opacity(0.5)

                LazyVStack(spacing: 12) {
                    ForEach(viewModel.results) { result in
                        resultRow(result)
                    }
                }
            }
        }
    }

    private var resultsSummary: some View {
        let grouped = Dictionary(grouping: viewModel.results) { $0.contentType }

        return HStack(spacing: 10) {
            ForEach(ScreenshotType.allCases, id: \.self) { type in
                if let count = grouped[type]?.count, count > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: type.iconName)
                            .font(.caption2)
                        Text("\(count)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(contentTypeColor(type))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(contentTypeColor(type).opacity(0.15))
                    .clipShape(Capsule())
                }
            }
        }
    }

    private func resultRow(_ result: ProcessingResultItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Content type icon
            Circle()
                .fill(contentTypeColor(result.contentType).opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: result.contentType.iconName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(contentTypeColor(result.contentType))
                }

            VStack(alignment: .leading, spacing: 4) {
                // Title and creator
                if let title = result.title {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)

                        if let creator = result.creator {
                            Text("•")
                                .foregroundStyle(.tertiary)
                            Text(creator)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                // Message with status
                HStack(spacing: 6) {
                    Image(systemName: resultIcon(for: result.status))
                        .font(.caption2)
                        .foregroundStyle(resultColor(for: result.status))

                    Text(result.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Service link
                if let link = result.serviceLink, let url = URL(string: link) {
                    Link(destination: url) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right.circle.fill")
                                .font(.caption)
                            Text(serviceLinkLabel(for: result.contentType))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(Color.accentColor)
                    }
                    .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private func contentTypeColor(_ type: ScreenshotType) -> Color {
        switch type {
        case .music: return .pink
        case .movie: return .purple
        case .book: return .orange
        case .meme: return .green
        case .unknown: return .gray
        }
    }

    private func serviceLinkLabel(for type: ScreenshotType) -> String {
        switch type {
        case .music: return "YouTube"
        case .movie: return "TMDb"
        case .book: return "Google Books"
        case .meme, .unknown: return "Open"
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
        if viewModel.googleDocURL != nil || viewModel.googleDocsStatus != nil || viewModel.googleDocsError != nil {
            GlassCard(tint: viewModel.googleDocsError != nil ? .orange : .blue) {
                HStack(spacing: 14) {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 40, height: 40)
                        .overlay {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(.blue)
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Google Docs Log")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        if let error = viewModel.googleDocsError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.orange)
                        } else if let status = viewModel.googleDocsStatus {
                            Text(status)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if let url = viewModel.googleDocURL, let docURL = URL(string: url) {
                        Link(destination: docURL) {
                            Image(systemName: "arrow.up.right.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.blue)
                                .symbolRenderingMode(.hierarchical)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Glass Card Component

struct GlassCard<Content: View>: View {
    var tint: Color = .clear
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.3),
                                        .white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .overlay {
                        if tint != .clear {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(tint.opacity(0.05))
                        }
                    }
            }
            .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }
}

#Preview {
    ProcessingView()
}
