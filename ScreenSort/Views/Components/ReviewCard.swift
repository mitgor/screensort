import SwiftUI
import Photos

/// Individual screenshot card in the review list
struct ReviewCard: View {
    let asset: PHAsset
    let result: ProcessingResultItem
    let hasCorrection: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppTheme.spacingSM) {
                // Thumbnail
                AsyncThumbnailView(asset: asset, targetSize: CGSize(width: 120, height: 120))
                    .frame(width: 60, height: 60)

                // Content info
                VStack(alignment: .leading, spacing: 4) {
                    // Title row
                    HStack(spacing: 6) {
                        Image(systemName: result.contentType.iconName)
                            .font(.caption)
                            .foregroundStyle(colorForType(result.contentType))

                        Text(result.title ?? result.contentType.displayName)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                    }

                    // Creator if available
                    if let creator = result.creator {
                        Text(creator)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    // Status badges
                    HStack(spacing: 6) {
                        statusBadge

                        if hasCorrection {
                            StatusPill("Corrected", color: .blue, icon: "checkmark.circle.fill")
                        }
                    }
                }

                Spacer(minLength: 0)

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(AppTheme.spacingSM)
            .background {
                RoundedRectangle(cornerRadius: AppTheme.radiusMD, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            }
        }
        .buttonStyle(.plain)
    }

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
    VStack(spacing: AppTheme.spacingSM) {
        ReviewCard(
            asset: PHAsset(),
            result: ProcessingResultItem(
                assetId: "test",
                status: .success,
                contentType: .music,
                title: "Bohemian Rhapsody",
                creator: "Queen",
                message: "Added to playlist",
                serviceLink: nil
            ),
            hasCorrection: false,
            onTap: {}
        )

        ReviewCard(
            asset: PHAsset(),
            result: ProcessingResultItem(
                assetId: "test2",
                status: .flagged,
                contentType: .unknown,
                title: nil,
                creator: nil,
                message: "Could not classify",
                serviceLink: nil
            ),
            hasCorrection: true,
            onTap: {}
        )
    }
    .padding()
}
