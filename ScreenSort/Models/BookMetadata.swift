//
//  BookMetadata.swift
//  ScreenSort
//
//  Represents extracted book information from a screenshot.
//

import Foundation

/// Configuration constants for book metadata validation.
enum BookMetadataConfig {
    /// Minimum confidence score (0.0-1.0) required for high-confidence extraction.
    static let highConfidenceThreshold: Float = 0.7

    /// Minimum character count for valid book titles.
    static let minimumTitleLength = 2

    /// Minimum character count for valid author names.
    static let minimumAuthorLength = 2
}

/// Extracted book information from a screenshot.
///
/// This struct holds the results of AI-powered book extraction from
/// screenshots of book apps (Kindle, Apple Books, Goodreads, etc.).
struct BookMetadata: Equatable, Hashable {

    // MARK: - Properties

    /// The extracted book title.
    let title: String

    /// The author's name.
    let author: String

    /// ISBN if visible (optional).
    let isbn: String?

    /// AI confidence score for the extraction (0.0 to 1.0).
    let confidenceScore: Float

    /// Raw OCR text from the screenshot for debugging and logging.
    let rawText: [String]

    // MARK: - Computed Properties

    /// Whether the extraction confidence meets the required threshold.
    var isHighConfidence: Bool {
        confidenceScore >= BookMetadataConfig.highConfidenceThreshold
    }

    /// Formatted query string optimized for Google Books search.
    var searchQuery: String {
        "\(title) \(author)"
    }

    /// A display-friendly string showing book info.
    var displayTitle: String {
        "\(title) - \(author)"
    }

    /// The creator field for logging (author name).
    var creator: String {
        author
    }

    // MARK: - Validation

    /// Validates that the metadata contains meaningful content.
    var isValid: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAuthor = author.trimmingCharacters(in: .whitespacesAndNewlines)

        return trimmedTitle.count >= BookMetadataConfig.minimumTitleLength
            && trimmedAuthor.count >= BookMetadataConfig.minimumAuthorLength
    }
}

// MARK: - CustomStringConvertible

extension BookMetadata: CustomStringConvertible {
    var description: String {
        "BookMetadata(\"\(title)\" by \(author), confidence: \(String(format: "%.2f", confidenceScore)))"
    }
}
