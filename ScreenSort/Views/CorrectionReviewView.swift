import SwiftUI
import Photos

/// Main review interface for correcting misclassified screenshots
struct CorrectionReviewView: View {
    @Bindable var viewModel: CorrectionReviewViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter pills
                filterSection
                    .padding(.horizontal)
                    .padding(.vertical, AppTheme.spacingSM)

                Divider()

                // Results list
                if viewModel.filteredResults.isEmpty {
                    emptyState
                } else {
                    resultsList
                }
            }
            .navigationTitle("Review & Correct")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingCorrectionSheet) {
                if let result = viewModel.selectedResult,
                   let asset = viewModel.asset(for: result) {
                    CorrectionSheet(
                        asset: asset,
                        result: result,
                        existingCorrection: viewModel.getCorrection(for: result),
                        ocrSnapshot: viewModel.getOCRSnapshot(for: result),
                        onDismiss: {
                            viewModel.dismissCorrectionSheet()
                        }
                    )
                }
            }
        }
    }

    // MARK: - Filter Section

    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.spacingSM) {
                ForEach(ReviewFilter.allCases, id: \.self) { filter in
                    FilterPill(
                        filter: filter,
                        count: viewModel.filterCounts[filter] ?? 0,
                        isSelected: viewModel.selectedFilter == filter,
                        onTap: {
                            withAnimation(.spring(response: 0.3)) {
                                viewModel.selectedFilter = filter
                            }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Results List

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.spacingSM) {
                ForEach(viewModel.filteredResults) { result in
                    if let asset = viewModel.asset(for: result) {
                        ReviewCard(
                            asset: asset,
                            result: result,
                            hasCorrection: viewModel.hasCorrection(for: result),
                            onTap: {
                                viewModel.selectForCorrection(result)
                            }
                        )
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppTheme.spacingMD) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No screenshots to review")
                .font(.headline)

            Text("Screenshots matching your filter will appear here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Filter Pill

private struct FilterPill: View {
    let filter: ReviewFilter
    let count: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: filter.iconName)
                    .font(.caption)

                Text(filter.rawValue)
                    .font(.subheadline.weight(.medium))

                if count > 0 {
                    Text("\(count)")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? .white.opacity(0.3) : Color.secondary.opacity(0.2))
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    Capsule()
                        .fill(colorForFilter(filter))
                } else {
                    Capsule()
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                }
            }
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    private func colorForFilter(_ filter: ReviewFilter) -> Color {
        switch filter {
        case .all: return Color(hex: "6366F1")
        case .flagged: return .orange
        case .music: return AppTheme.musicColor
        case .movies: return AppTheme.movieColor
        case .books: return AppTheme.bookColor
        case .memes: return AppTheme.memeColor
        }
    }
}

// MARK: - Preview

#Preview {
    let viewModel = CorrectionReviewViewModel()
    viewModel.loadResults([
        ProcessingResultItem(
            assetId: "1",
            status: .success,
            contentType: .music,
            title: "Bohemian Rhapsody",
            creator: "Queen",
            message: "Added to playlist",
            serviceLink: nil
        ),
        ProcessingResultItem(
            assetId: "2",
            status: .flagged,
            contentType: .unknown,
            title: nil,
            creator: nil,
            message: "Could not classify",
            serviceLink: nil
        )
    ])

    return CorrectionReviewView(viewModel: viewModel)
}
