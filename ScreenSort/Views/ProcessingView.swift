//
//  ProcessingView.swift
//  ScreenSort
//
//  Main processing interface with iOS 26 Liquid Glass design.
//

import SwiftUI
import Photos

struct ProcessingView: View {
    @State private var viewModel = ProcessingViewModel()
    @State private var correctionViewModel = CorrectionReviewViewModel()
    @State private var showingReviewSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Animated gradient background (disabled during processing)
                AnimatedBackground(isAnimating: !viewModel.isProcessing)

                ScrollView {
                    VStack(spacing: AppTheme.spacingLG) {
                        // Header stats
                        headerSection

                        // Permission cards
                        permissionCardsSection

                        // Process button
                        processButtonSection

                        // Progress indicator
                        if viewModel.isProcessing {
                            processingSection
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .scale.combined(with: .opacity)
                                ))
                        }

                        // Error display
                        if let error = viewModel.lastError {
                            errorSection(error)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // Results
                        if !viewModel.results.isEmpty {
                            resultsSection
                                .transition(.move(edge: .bottom).combined(with: .opacity))

                            // Review & Correct button
                            reviewCorrectionButton
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        // Google Doc link
                        googleDocSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, AppTheme.spacingMD)
                }
            }
            .navigationTitle("ScreenSort")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                viewModel.checkInitialState()
            }
            .sheet(isPresented: $showingReviewSheet) {
                CorrectionReviewView(viewModel: correctionViewModel)
            }
            .onChange(of: showingReviewSheet) { _, isShowing in
                if isShowing {
                    correctionViewModel.loadResults(viewModel.results, ocrSnapshots: viewModel.ocrSnapshots)
                }
            }
            // Only animate UI state changes, not data changes (prevents layout thrashing)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.isProcessing)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.lastError != nil)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(spacing: AppTheme.spacingMD) {
            StatCard(
                value: "\(viewModel.successCount)",
                label: "Processed",
                icon: "checkmark.circle.fill",
                color: AppTheme.musicColor
            )

            StatCard(
                value: "\(viewModel.flaggedCount)",
                label: "Flagged",
                icon: "flag.fill",
                color: .orange
            )
        }
        .opacity(viewModel.results.isEmpty ? 0.5 : 1)
    }

    // MARK: - Permission Cards

    private var permissionCardsSection: some View {
        VStack(spacing: AppTheme.spacingSM) {
            // Photo Library
            PermissionCard(
                title: "Photo Library",
                subtitle: permissionSubtitle,
                icon: permissionIcon,
                iconColor: permissionColor,
                status: permissionStatus,
                action: permissionAction
            )

            // Google Account
            PermissionCard(
                title: "Google Account",
                subtitle: viewModel.isYouTubeAuthenticated ? "Connected" : "Sign in required",
                icon: "person.crop.circle.badge.checkmark",
                iconColor: viewModel.isYouTubeAuthenticated ? .green : .red,
                status: viewModel.isYouTubeAuthenticated ? .connected : .disconnected,
                action: viewModel.isYouTubeAuthenticated
                    ? PermissionAction(title: "Sign Out", style: .secondary) { viewModel.signOutYouTube() }
                    : PermissionAction(title: "Sign In", style: .primary) { Task { await viewModel.authenticateYouTube() } }
            )
        }
    }

    private var permissionSubtitle: String {
        switch viewModel.photoPermissionStatus {
        case .authorized: return "Full access granted"
        case .limited: return "Limited access"
        case .denied: return "Access denied"
        case .restricted: return "Access restricted"
        case .notDetermined: return "Permission needed"
        @unknown default: return "Unknown"
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
        case .notDetermined: return Color(hex: "6366F1")
        @unknown default: return .gray
        }
    }

    private var permissionStatus: PermissionCard.Status {
        switch viewModel.photoPermissionStatus {
        case .authorized, .limited: return .connected
        case .denied, .restricted: return .error
        case .notDetermined: return .disconnected
        @unknown default: return .disconnected
        }
    }

    private var permissionAction: PermissionAction? {
        switch viewModel.photoPermissionStatus {
        case .notDetermined:
            return PermissionAction(title: "Allow", style: .primary) {
                Task { await viewModel.requestPhotoAccess() }
            }
        case .denied:
            return PermissionAction(title: "Settings", style: .secondary) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        default:
            return nil
        }
    }

    // MARK: - Process Button

    private var processButtonSection: some View {
        let isEnabled = viewModel.hasPhotoAccess && viewModel.isYouTubeAuthenticated && !viewModel.isProcessing

        return VStack(spacing: AppTheme.spacingSM) {
            Button(action: {
                Task { await viewModel.processNow() }
            }) {
                HStack(spacing: AppTheme.spacingSM) {
                    if viewModel.isProcessing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.title3)
                            .symbolEffect(.pulse.wholeSymbol, options: .repeating, isActive: isEnabled)
                    }

                    Text(viewModel.isProcessing ? "Processing..." : "Process Screenshots")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background {
                    if isEnabled {
                        AppTheme.accentGradient
                    } else {
                        Color.gray.opacity(0.3)
                    }
                }
                .foregroundStyle(isEnabled ? .white : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusLG, style: .continuous))
                .shadow(color: isEnabled ? Color(hex: "6366F1").opacity(0.4) : .clear, radius: 16, y: 8)
            }
            .disabled(!isEnabled)
            .sensoryFeedback(.impact(flexibility: .soft), trigger: viewModel.isProcessing)
            .bounceOnTap()

            if !isEnabled && !viewModel.isProcessing {
                Text("Grant permissions above to start")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, AppTheme.spacingSM)
    }

    // MARK: - Processing Section

    private var processingSection: some View {
        GlassCard {
            VStack(spacing: AppTheme.spacingMD) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Processing Screenshots")
                            .font(.headline)

                        Text("Using on-device AI")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    ZStack {
                        ProgressRing(
                            progress: Double(viewModel.processingProgress.current) / Double(max(viewModel.processingProgress.total, 1)),
                            lineWidth: 5,
                            color: Color(hex: "6366F1")
                        )
                        .frame(width: 50, height: 50)

                        Text("\(viewModel.processingProgress.current)")
                            .font(.system(.body, design: .rounded, weight: .bold))
                            .monospacedDigit()
                    }
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 6)

                        Capsule()
                            .fill(AppTheme.accentGradient)
                            .frame(
                                width: geo.size.width * (Double(viewModel.processingProgress.current) / Double(max(viewModel.processingProgress.total, 1))),
                                height: 6
                            )
                            .animation(.spring(response: 0.4), value: viewModel.processingProgress.current)
                    }
                }
                .frame(height: 6)

                Text("\(viewModel.processingProgress.current) of \(viewModel.processingProgress.total) screenshots")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Cancel button
                Button(action: {
                    viewModel.cancelProcessing()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.subheadline)
                        Text("Cancel")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, AppTheme.spacingSM)
            }
        }
    }

    // MARK: - Error Section

    private func errorSection(_ error: String) -> some View {
        GlassCard(tint: .red) {
            HStack(spacing: AppTheme.spacingSM) {
                IconBadge(icon: "exclamationmark.triangle.fill", color: .red, size: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Something went wrong")
                        .font(.subheadline.weight(.semibold))

                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }
        }
    }

    // MARK: - Results Section

    private var resultsSection: some View {
        VStack(spacing: AppTheme.spacingSM) {
            // Section header with summary counters
            HStack {
                Text("Results")
                    .font(.title3.weight(.bold))

                Spacer()

                resultsSummaryPills
            }
            .padding(.horizontal, 4)

            // Summary of non-successful items
            if viewModel.flaggedCount > 0 || viewModel.failedCount > 0 || viewModel.unknownCount > 0 {
                HStack(spacing: AppTheme.spacingSM) {
                    if viewModel.unknownCount > 0 {
                        SummaryChip(
                            icon: "questionmark.circle",
                            text: "Could not classify",
                            count: viewModel.unknownCount,
                            color: AppTheme.unknownColor
                        )
                    }
                    if viewModel.flaggedCount > 0 {
                        SummaryChip(
                            icon: "flag.fill",
                            text: "Flagged",
                            count: viewModel.flaggedCount,
                            color: .orange
                        )
                    }
                    if viewModel.failedCount > 0 {
                        SummaryChip(
                            icon: "xmark.circle",
                            text: "Failed",
                            count: viewModel.failedCount,
                            color: .red
                        )
                    }
                    Spacer()
                }
            }

            // Scrollable list of successful results only
            if !viewModel.successResults.isEmpty {
                GlassCard(padding: AppTheme.spacingSM) {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.successResults) { result in
                                CompactResultRow(result: result)
                                Divider()
                                    .padding(.horizontal, AppTheme.spacingSM)
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                }
            }
        }
    }

    private var resultsSummaryPills: some View {
        HStack(spacing: 6) {
            ForEach(ScreenshotType.allCases.filter { $0 != .unknown }, id: \.self) { type in
                if let count = viewModel.successCountByType[type], count > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: type.iconName)
                            .font(.caption2)
                        Text("\(count)")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(colorForType(type))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(colorForType(type).opacity(0.12))
                    .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Review & Correct Button

    private var reviewCorrectionButton: some View {
        Button(action: {
            showingReviewSheet = true
        }) {
            HStack(spacing: AppTheme.spacingSM) {
                Image(systemName: "pencil.and.list.clipboard")
                    .font(.body.weight(.medium))

                Text("Review & Correct")
                    .fontWeight(.medium)

                Spacer()

                // Show count of flagged items
                if viewModel.flaggedCount > 0 || viewModel.unknownCount > 0 {
                    Text("\(viewModel.flaggedCount + viewModel.unknownCount) to review")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: AppTheme.radiusLG, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Google Doc Section

    @ViewBuilder
    private var googleDocSection: some View {
        if viewModel.googleDocURL != nil || viewModel.googleDocsStatus != nil {
            GlassCard(tint: .blue) {
                HStack(spacing: AppTheme.spacingSM) {
                    IconBadge(icon: "doc.text.fill", color: Color(hex: "3B82F6"), size: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Google Docs Log")
                            .font(.subheadline.weight(.semibold))

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
                                .foregroundStyle(Color(hex: "3B82F6"))
                                .symbolRenderingMode(.hierarchical)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func colorForType(_ type: ScreenshotType) -> Color {
        switch type {
        case .music: return AppTheme.musicColor
        case .movie: return AppTheme.movieColor
        case .book: return AppTheme.bookColor
        case .meme: return AppTheme.memeColor
        case .unknown: return AppTheme.unknownColor
        }
    }
}

// MARK: - Animated Background

struct AnimatedBackground: View {
    let isAnimating: Bool
    @State private var animate = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.systemGray6).opacity(0.3)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Floating orbs (only animate when not processing)
            Circle()
                .fill(Color(hex: "6366F1").opacity(0.08))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: animate && isAnimating ? 50 : -50, y: animate && isAnimating ? -100 : -50)

            Circle()
                .fill(Color(hex: "EC4899").opacity(0.06))
                .frame(width: 250, height: 250)
                .blur(radius: 50)
                .offset(x: animate && isAnimating ? -80 : 80, y: animate && isAnimating ? 200 : 150)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
        .animation(.easeInOut(duration: 0.5), value: isAnimating)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        GlassCard {
            HStack(spacing: AppTheme.spacingSM) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .symbolRenderingMode(.hierarchical)

                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(.system(.title2, design: .rounded, weight: .bold))

                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
    }
}

// MARK: - Permission Card

struct PermissionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let status: Status
    let action: PermissionAction?

    enum Status {
        case connected, disconnected, error
    }

    var body: some View {
        GlassCard {
            HStack(spacing: AppTheme.spacingSM) {
                IconBadge(icon: icon, color: iconColor, size: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let action {
                    Button(action: action.action) {
                        Text(action.title)
                            .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                    .tint(action.style == .primary ? Color(hex: "6366F1") : .secondary)
                } else if status == .connected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                        .symbolEffect(.pulse, options: .speed(0.5))
                }
            }
        }
    }
}

struct PermissionAction {
    let title: String
    let style: Style
    let action: () -> Void

    enum Style { case primary, secondary }
}

// MARK: - Result Row

struct ResultRow: View {
    let result: ProcessingResultItem

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.spacingSM) {
            // Type icon
            Circle()
                .fill(colorForType(result.contentType).opacity(0.12))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: result.contentType.iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(colorForType(result.contentType))
                }

            VStack(alignment: .leading, spacing: 4) {
                // Title
                if let title = result.title {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.subheadline.weight(.medium))
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

                // Status
                HStack(spacing: 6) {
                    Image(systemName: statusIcon)
                        .font(.caption2)
                        .foregroundStyle(statusColor)

                    Text(result.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Link
                if let link = result.serviceLink, let url = URL(string: link) {
                    Link(destination: url) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right.circle.fill")
                                .font(.caption)
                            Text(serviceName)
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(Color(hex: "6366F1"))
                    }
                    .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppTheme.spacingMD)
        .padding(.vertical, AppTheme.spacingSM)
    }

    private var statusIcon: String {
        switch result.status {
        case .success: return "checkmark.circle.fill"
        case .flagged: return "flag.fill"
        case .failed: return "xmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch result.status {
        case .success: return .green
        case .flagged: return .orange
        case .failed: return .red
        }
    }

    private var serviceName: String {
        switch result.contentType {
        case .music: return "YouTube"
        case .movie: return "TMDb"
        case .book: return "Google Books"
        case .meme, .unknown: return "Open"
        }
    }

    private func colorForType(_ type: ScreenshotType) -> Color {
        switch type {
        case .music: return AppTheme.musicColor
        case .movie: return AppTheme.movieColor
        case .book: return AppTheme.bookColor
        case .meme: return AppTheme.memeColor
        case .unknown: return AppTheme.unknownColor
        }
    }
}

// MARK: - Summary Chip

struct SummaryChip: View {
    let icon: String
    let text: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)

            Text("\(text) – \(count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.08))
        .clipShape(Capsule())
    }
}

// MARK: - Compact Result Row

struct CompactResultRow: View {
    let result: ProcessingResultItem

    var body: some View {
        HStack(spacing: AppTheme.spacingSM) {
            // Type icon
            Image(systemName: result.contentType.iconName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(colorForType(result.contentType))
                .frame(width: 24)

            // Title and creator
            VStack(alignment: .leading, spacing: 2) {
                if let title = result.title {
                    Text(title)
                        .font(.subheadline)
                        .lineLimit(1)
                }

                if let creator = result.creator {
                    Text(creator)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            // Service link
            if let link = result.serviceLink, let url = URL(string: link) {
                Link(destination: url) {
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(Color(hex: "6366F1"))
                }
            }
        }
        .padding(.horizontal, AppTheme.spacingSM)
        .padding(.vertical, 8)
    }

    private func colorForType(_ type: ScreenshotType) -> Color {
        switch type {
        case .music: return AppTheme.musicColor
        case .movie: return AppTheme.movieColor
        case .book: return AppTheme.bookColor
        case .meme: return AppTheme.memeColor
        case .unknown: return AppTheme.unknownColor
        }
    }
}

// MARK: - Preview

#Preview {
    ProcessingView()
}
