import SwiftUI
import Photos

/// Asynchronously loads and displays a thumbnail for a PHAsset
struct AsyncThumbnailView: View {
    let asset: PHAsset
    var targetSize: CGSize = CGSize(width: 120, height: 120)
    var contentMode: PHImageContentMode = .aspectFill
    var cornerRadius: CGFloat = AppTheme.radiusSM

    @State private var image: UIImage?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isLoading {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    .shimmer()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: asset.localIdentifier) {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        isLoading = true

        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        let manager = PHImageManager.default()

        // Use continuation to bridge callback-based API to async/await
        let loadedImage: UIImage? = await withCheckedContinuation { continuation in
            manager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: contentMode,
                options: options
            ) { result, info in
                // Only continue if this is the final result (not a degraded placeholder)
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !isDegraded {
                    continuation.resume(returning: result)
                }
            }
        }

        await MainActor.run {
            self.image = loadedImage
            self.isLoading = false
        }
    }
}

// MARK: - Preview

#Preview {
    HStack {
        // This won't show actual images in preview, but demonstrates the loading state
        AsyncThumbnailView(asset: PHAsset())
            .frame(width: 80, height: 80)

        AsyncThumbnailView(asset: PHAsset())
            .frame(width: 120, height: 120)
    }
    .padding()
}
