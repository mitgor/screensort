//
//  MusicMetadata.swift
//  ScreenSort
//
//  Represents extracted music information from a screenshot.
//

import Foundation

/// Configuration constants for music metadata validation.
enum MusicMetadataConfig {
    /// Minimum confidence score (0.0-1.0) required for high-confidence extraction.
    static let highConfidenceThreshold: Float = 0.7

    /// Minimum character count for valid song titles.
    static let minimumTitleLength = 2

    /// Minimum character count for valid artist names.
    static let minimumArtistLength = 2
}

/// Extracted music information from a screenshot.
///
/// This struct holds the results of AI-powered music extraction from
/// screenshots of music player apps (Spotify, Apple Music, etc.).
///
/// ## Example Usage
/// ```swift
/// let metadata = MusicMetadata(
///     songTitle: "Bohemian Rhapsody",
///     artist: "Queen",
///     confidenceScore: 0.95,
///     rawText: ["Bohemian Rhapsody", "Queen", "Now Playing"]
/// )
///
/// if metadata.isHighConfidence {
///     let searchQuery = metadata.searchQuery
///     // Use searchQuery for YouTube API
/// }
/// ```
struct MusicMetadata: Equatable, Hashable {

    // MARK: - Properties

    /// The extracted song title, cleaned of UI elements and timestamps.
    let songTitle: String

    /// The extracted artist or band name.
    let artist: String

    /// AI confidence score for the extraction (0.0 to 1.0).
    ///
    /// Higher values indicate more reliable extraction:
    /// - 0.9-1.0: Very high confidence
    /// - 0.7-0.9: High confidence (above threshold)
    /// - 0.5-0.7: Medium confidence (may need review)
    /// - Below 0.5: Low confidence (likely incorrect)
    let confidenceScore: Float

    /// Raw OCR text from the screenshot for debugging and logging.
    let rawText: [String]

    // MARK: - Computed Properties

    /// Whether the extraction confidence meets the required threshold.
    ///
    /// Uses `MusicMetadataConfig.highConfidenceThreshold` (currently 0.7).
    var isHighConfidence: Bool {
        confidenceScore >= MusicMetadataConfig.highConfidenceThreshold
    }

    /// Formatted query string optimized for YouTube search.
    ///
    /// Combines song title and artist for best search results.
    var searchQuery: String {
        "\(songTitle) \(artist)"
    }

    /// A display-friendly string showing song and artist.
    var displayTitle: String {
        "\(songTitle) - \(artist)"
    }

    // MARK: - Validation

    /// Validates that the metadata contains meaningful content.
    ///
    /// Checks for:
    /// - Minimum length requirements for title and artist
    /// - Non-empty trimmed strings
    ///
    /// - Returns: `true` if the metadata passes basic validation.
    var isValid: Bool {
        let trimmedTitle = songTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)

        return trimmedTitle.count >= MusicMetadataConfig.minimumTitleLength
            && trimmedArtist.count >= MusicMetadataConfig.minimumArtistLength
    }
}

// MARK: - CustomStringConvertible

extension MusicMetadata: CustomStringConvertible {
    var description: String {
        "MusicMetadata(\"\(songTitle)\" by \(artist), confidence: \(String(format: "%.2f", confidenceScore)))"
    }
}
