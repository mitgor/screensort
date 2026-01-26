import SwiftUI
import Photos

/// Modal sheet for correcting a misclassified screenshot
struct CorrectionSheet: View {
    let asset: PHAsset
    let result: ProcessingResultItem
    let existingCorrection: Correction?
    let ocrSnapshot: [String]
    let onDismiss: () -> Void

    @State private var selectedType: ScreenshotType
    @State private var title: String
    @State private var creator: String
    @State private var selectedReason: CorrectionReason = .wrongCategory
    @State private var isApplying = false
    @State private var showError = false
    @State private var errorMessage = ""

    @Environment(\.dismiss) private var dismiss

    init(
        asset: PHAsset,
        result: ProcessingResultItem,
        existingCorrection: Correction?,
        ocrSnapshot: [String] = [],
        onDismiss: @escaping () -> Void
    ) {
        self.asset = asset
        self.result = result
        self.existingCorrection = existingCorrection
        self.ocrSnapshot = ocrSnapshot
        self.onDismiss = onDismiss

        // Initialize state from existing correction or original result
        _selectedType = State(initialValue: existingCorrection?.correctedType ?? result.contentType)
        _title = State(initialValue: existingCorrection?.correctedTitle ?? result.title ?? "")
        _creator = State(initialValue: existingCorrection?.correctedCreator ?? result.creator ?? "")
        _selectedReason = State(initialValue: existingCorrection?.correctionReason ?? .wrongCategory)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacingLG) {
                    // Screenshot preview
                    previewSection

                    // Original classification (read-only)
                    originalSection

                    // Correction form
                    correctionSection
                }
                .padding()
            }
            .navigationTitle("Correct Classification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task {
                            await saveCorrection()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(isApplying || !hasChanges)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
        .interactiveDismissDisabled(isApplying)
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        GlassCard {
            HStack(spacing: AppTheme.spacingMD) {
                AsyncThumbnailView(
                    asset: asset,
                    targetSize: CGSize(width: 200, height: 200),
                    cornerRadius: AppTheme.radiusMD
                )
                .frame(width: 100, height: 100)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Screenshot Preview")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let date = asset.creationDate {
                        Text(date, style: .date)
                            .font(.subheadline)

                        Text(date, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
        }
    }

    // MARK: - Original Section

    private var originalSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
                Label("Original Classification", systemImage: "tag")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: AppTheme.spacingSM) {
                    Image(systemName: result.contentType.iconName)
                        .foregroundStyle(colorForType(result.contentType))

                    Text(result.contentType.displayName)
                        .font(.body.weight(.medium))

                    Spacer()

                    statusBadge
                }

                if let title = result.title {
                    HStack {
                        Text("Title:")
                            .foregroundStyle(.secondary)
                        Text(title)
                    }
                    .font(.subheadline)
                }

                if let creator = result.creator {
                    HStack {
                        Text("Creator:")
                            .foregroundStyle(.secondary)
                        Text(creator)
                    }
                    .font(.subheadline)
                }
            }
        }
    }

    // MARK: - Correction Section

    private var correctionSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingMD) {
            Text("Your Correction")
                .font(.headline)

            // Type picker
            VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
                Text("Correct Category")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                typePicker
            }

            // Title field (if applicable)
            if selectedType.requiresExtraction {
                VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
                    Text(titleLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextField(titlePlaceholder, text: $title)
                        .textFieldStyle(.roundedBorder)
                }

                // Creator field
                VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
                    Text(creatorLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextField(creatorPlaceholder, text: $creator)
                        .textFieldStyle(.roundedBorder)
                }
            }

            // Reason picker
            VStack(alignment: .leading, spacing: AppTheme.spacingSM) {
                Text("Reason for Correction")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Picker("Reason", selection: $selectedReason) {
                    ForEach(CorrectionReason.allCases, id: \.self) { reason in
                        Text(reason.displayName).tag(reason)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color(hex: "6366F1"))
            }

            // Previously corrected indicator
            if existingCorrection != nil {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.blue)
                    Text("This screenshot was previously corrected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, AppTheme.spacingSM)
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: AppTheme.radiusLG, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        }
    }

    // MARK: - Type Picker

    private var typePicker: some View {
        HStack(spacing: AppTheme.spacingSM) {
            ForEach(ScreenshotType.allCases.filter { $0 != .unknown }, id: \.self) { type in
                TypePickerButton(
                    type: type,
                    isSelected: selectedType == type,
                    onTap: {
                        withAnimation(.spring(response: 0.3)) {
                            selectedType = type
                        }
                    }
                )
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private var statusBadge: some View {
        switch result.status {
        case .success:
            StatusPill("Success", color: .green, icon: "checkmark.circle.fill")
        case .flagged:
            StatusPill("Flagged", color: .orange, icon: "flag.fill")
        case .failed:
            StatusPill("Failed", color: .red, icon: "xmark.circle.fill")
        }
    }

    private var hasChanges: Bool {
        selectedType != result.contentType ||
        (selectedType.requiresExtraction && title != (result.title ?? "")) ||
        (selectedType.requiresExtraction && creator != (result.creator ?? ""))
    }

    private var titleLabel: String {
        switch selectedType {
        case .music: return "Song Title"
        case .movie: return "Movie Title"
        case .book: return "Book Title"
        default: return "Title"
        }
    }

    private var titlePlaceholder: String {
        switch selectedType {
        case .music: return "Enter song title"
        case .movie: return "Enter movie title"
        case .book: return "Enter book title"
        default: return "Enter title"
        }
    }

    private var creatorLabel: String {
        switch selectedType {
        case .music: return "Artist"
        case .movie: return "Director"
        case .book: return "Author"
        default: return "Creator"
        }
    }

    private var creatorPlaceholder: String {
        switch selectedType {
        case .music: return "Enter artist name"
        case .movie: return "Enter director name"
        case .book: return "Enter author name"
        default: return "Enter creator"
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

    // MARK: - Save Action

    private func saveCorrection() async {
        isApplying = true

        do {
            let correctionService = CorrectionService()

            let correction = Correction(
                assetId: result.assetId,
                originalType: result.contentType,
                originalTitle: result.title,
                originalCreator: result.creator,
                correctedType: selectedType,
                correctedTitle: selectedType.requiresExtraction ? (title.isEmpty ? nil : title) : nil,
                correctedCreator: selectedType.requiresExtraction ? (creator.isEmpty ? nil : creator) : nil,
                ocrTextSnapshot: ocrSnapshot,
                correctionReason: selectedReason
            )

            try await correctionService.applyCorrection(correction, for: asset)

            await MainActor.run {
                isApplying = false
                onDismiss()
                dismiss()
            }
        } catch {
            await MainActor.run {
                isApplying = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Type Picker Button

private struct TypePickerButton: View {
    let type: ScreenshotType
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Image(systemName: type.iconName)
                    .font(.title3)

                Text(type.displayName)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.spacingSM)
            .background {
                RoundedRectangle(cornerRadius: AppTheme.radiusSM, style: .continuous)
                    .fill(isSelected ? colorForType(type).opacity(0.15) : Color.clear)
                    .overlay {
                        RoundedRectangle(cornerRadius: AppTheme.radiusSM, style: .continuous)
                            .stroke(isSelected ? colorForType(type) : Color.secondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                    }
            }
            .foregroundStyle(isSelected ? colorForType(type) : .secondary)
        }
        .buttonStyle(.plain)
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
    CorrectionSheet(
        asset: PHAsset(),
        result: ProcessingResultItem(
            assetId: "test",
            status: .flagged,
            contentType: .unknown,
            title: nil,
            creator: nil,
            message: "Could not classify",
            serviceLink: nil
        ),
        existingCorrection: nil,
        onDismiss: {}
    )
}
