//
//  MovieMetadata.swift
//  ScreenSort
//
//  Represents extracted movie information from a screenshot.
//

import Foundation

/// Configuration constants for movie metadata validation.
enum MovieMetadataConfig {
    /// Minimum confidence score (0.0-1.0) required for high-confidence extraction.
    static let highConfidenceThreshold: Float = 0.7

    /// Minimum character count for valid movie titles.
    static let minimumTitleLength = 2

    /// Minimum character count for valid director names.
    static let minimumDirectorLength = 2
}

/// Extracted movie information from a screenshot.
///
/// This struct holds the results of AI-powered movie extraction from
/// screenshots of streaming apps (Netflix, Prime Video, etc.).
struct MovieMetadata: Equatable, Hashable {

    // MARK: - Properties

    /// The extracted movie title.
    let title: String

    /// The year of release (optional).
    let year: Int?

    /// The director's name (optional).
    let director: String?

    /// Main cast members (optional).
    let actors: [String]

    /// AI confidence score for the extraction (0.0 to 1.0).
    let confidenceScore: Float

    /// Raw OCR text from the screenshot for debugging and logging.
    let rawText: [String]

    // MARK: - Computed Properties

    /// Whether the extraction confidence meets the required threshold.
    var isHighConfidence: Bool {
        confidenceScore >= MovieMetadataConfig.highConfidenceThreshold
    }

    /// Formatted query string optimized for TMDb search.
    var searchQuery: String {
        if let year = year {
            return "\(title) \(year)"
        }
        return title
    }

    /// A display-friendly string showing movie info.
    var displayTitle: String {
        var display = title
        if let year = year {
            display += " (\(year))"
        }
        if let director = director {
            display += " - \(director)"
        }
        return display
    }

    /// The creator field for logging (director or "Unknown Director").
    var creator: String {
        director ?? "Unknown Director"
    }

    // MARK: - Validation

    /// Validates that the metadata contains meaningful content.
    var isValid: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.count >= MovieMetadataConfig.minimumTitleLength
    }
}

// MARK: - CustomStringConvertible

extension MovieMetadata: CustomStringConvertible {
    var description: String {
        var desc = "MovieMetadata(\"\(title)\""
        if let year = year {
            desc += " (\(year))"
        }
        if let director = director {
            desc += " by \(director)"
        }
        desc += ", confidence: \(String(format: "%.2f", confidenceScore)))"
        return desc
    }
}
