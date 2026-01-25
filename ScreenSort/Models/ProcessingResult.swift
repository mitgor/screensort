import Foundation

/// Result of processing a screenshot through the music pipeline
enum ProcessingResult {
    /// Successfully extracted music metadata and added to YouTube Music
    case success(metadata: MusicMetadata, videoId: String)

    /// Extracted metadata but confidence below 0.7 threshold
    case lowConfidence(metadata: MusicMetadata)

    /// Screenshot classified as non-music type
    case notMusic

    /// OCR or parsing failed
    case extractionFailed(reason: String)

    /// YouTube API error
    case apiError(reason: String)

    /// Destination album based on processing outcome
    var destinationAlbum: String {
        switch self {
        case .success:
            return "ScreenSort - Processed"
        case .lowConfidence, .notMusic, .extractionFailed, .apiError:
            return "ScreenSort - Flagged"
        }
    }
}
