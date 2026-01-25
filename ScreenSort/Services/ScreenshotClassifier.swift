//
//  ScreenshotClassifier.swift
//  ScreenSort
//
//  Classifies screenshots by analyzing OCR text to detect content type.
//

import Foundation

// MARK: - Protocol

/// Protocol for screenshot classification services.
///
/// Enables dependency injection and testing of classification logic.
protocol ScreenshotClassifierProtocol {
    /// Classify a screenshot based on OCR text observations.
    /// - Parameter textObservations: Array of text detected in the screenshot.
    /// - Returns: The detected screenshot type.
    func classify(textObservations: [TextObservation]) -> ScreenshotType

    /// Check if the screenshot has UI patterns typical of music players.
    /// - Parameter textObservations: Array of text detected in the screenshot.
    /// - Returns: `true` if music UI patterns are detected.
    func hasMusicUIPattern(textObservations: [TextObservation]) -> Bool
}

// MARK: - Classification Configuration

/// Configuration for screenshot classification keywords and thresholds.
///
/// Centralizes all classification rules for easier maintenance and testing.
enum ClassificationConfig {

    /// Minimum keyword matches required to classify a screenshot.
    static let minimumMatchThreshold = 1

    /// High-confidence observations have confidence above this value.
    static let highConfidenceThreshold: Float = 0.8

    /// Minimum high-confidence text items needed for music UI pattern detection.
    static let minimumHighConfidenceItems = 2

    /// Keywords indicating music app screenshots.
    static let musicKeywords: Set<String> = [
        // App names
        "now playing",
        "apple music",
        "spotify",
        "shazam",
        "soundcloud",
        "youtube music",
        "amazon music",
        "tidal",
        "deezer",
        "pandora",

        // Common UI elements
        "playing from",
        "pause",
        "play",
        "shuffle",
        "repeat",
        "add to library",
        "share song",
        "lyrics",
        "up next",
        "queue"
    ]

    /// Keywords indicating movie/TV streaming screenshots.
    static let movieKeywords: Set<String> = [
        // Streaming services
        "netflix",
        "prime video",
        "disney+",
        "hbo max",
        "hulu",
        "peacock",
        "paramount+",
        "apple tv+",

        // Review sites
        "imdb",
        "rotten tomatoes",
        "metacritic",

        // UI elements
        "watch now",
        "play movie",
        "episodes",
        "season",
        "trailer",
        "cast & crew"
    ]

    /// Keywords indicating book/reading screenshots.
    static let bookKeywords: Set<String> = [
        // Apps and services
        "goodreads",
        "kindle",
        "apple books",
        "audible",
        "libby",
        "kobo",
        "scribd",

        // UI elements
        "reading",
        "want to read",
        "currently reading",
        "pages",
        "chapter",
        "author",
        "publisher",
        "isbn"
    ]

    /// Keywords indicating meme screenshots.
    static let memeKeywords: Set<String> = [
        // Meme generators and platforms
        "imgflip",
        "mematic",
        "made with mematic",
        "9gag",
        "reddit",
        "ifunny",
        "memedroid",
        "kapwing",

        // Common meme elements
        "nobody:",
        "me:",
        "when you",
        "pov:",
        "be like",
        "change my mind"
    ]
}

// MARK: - Screenshot Classifier

/// Classifies screenshots by detecting content type based on OCR text.
///
/// The classifier analyzes text extracted from screenshots to determine
/// if they're from music apps, streaming services, or book apps.
///
/// ## Usage
/// ```swift
/// let classifier = ScreenshotClassifier()
/// let type = classifier.classify(textObservations: observations)
///
/// switch type {
/// case .music:
///     // Process as music screenshot
/// case .movie, .book, .unknown:
///     // Handle other types
/// }
/// ```
final class ScreenshotClassifier: ScreenshotClassifierProtocol, Sendable {

    // MARK: - Public API

    /// Classify a screenshot based on OCR text observations.
    ///
    /// Analyzes all detected text against known keywords for each category
    /// and returns the best-matching type.
    ///
    /// - Parameter textObservations: Array of text detected in the screenshot.
    /// - Returns: The detected screenshot type, or `.unknown` if no match.
    func classify(textObservations: [TextObservation]) -> ScreenshotType {
        let combinedText = combineObservationsToLowercase(textObservations)

        // Score each category
        let scores: [(ScreenshotType, Int)] = [
            (.music, countKeywordMatches(in: combinedText, keywords: ClassificationConfig.musicKeywords)),
            (.movie, countKeywordMatches(in: combinedText, keywords: ClassificationConfig.movieKeywords)),
            (.book, countKeywordMatches(in: combinedText, keywords: ClassificationConfig.bookKeywords)),
            (.meme, countKeywordMatches(in: combinedText, keywords: ClassificationConfig.memeKeywords))
        ]

        // Find the highest-scoring category
        guard let bestMatch = scores.max(by: { $0.1 < $1.1 }),
              bestMatch.1 >= ClassificationConfig.minimumMatchThreshold else {
            return .unknown
        }

        return bestMatch.0
    }

    /// Check if the screenshot has UI patterns typical of music player lock screens.
    ///
    /// Music lock screens typically have:
    /// - Song title (large, high confidence) in the upper portion
    /// - Artist name (below title)
    /// - Playback controls (may not be text)
    ///
    /// - Parameter textObservations: Array of text detected in the screenshot.
    /// - Returns: `true` if the layout matches music player patterns.
    func hasMusicUIPattern(textObservations: [TextObservation]) -> Bool {
        // Filter for observations in the top half of the screen
        // Vision coordinates have origin at bottom-left, so y > 0.5 means top half
        let topHalfObservations = textObservations.filter { observation in
            observation.boundingBox.origin.y > 0.5
        }

        // Count high-confidence observations in the top portion
        let highConfidenceCount = topHalfObservations.filter { observation in
            observation.confidence > ClassificationConfig.highConfidenceThreshold
        }.count

        // Music player typically shows song title and artist prominently
        return highConfidenceCount >= ClassificationConfig.minimumHighConfidenceItems
    }

    // MARK: - Private Helpers

    /// Combine all text observations into a single lowercase string.
    private func combineObservationsToLowercase(_ observations: [TextObservation]) -> String {
        observations
            .map { $0.text.lowercased() }
            .joined(separator: " ")
    }

    /// Count how many keywords from the set appear in the text.
    private func countKeywordMatches(in text: String, keywords: Set<String>) -> Int {
        keywords.reduce(0) { count, keyword in
            text.contains(keyword) ? count + 1 : count
        }
    }
}

// MARK: - Classification Result (for advanced usage)

/// Detailed classification result with confidence scores.
///
/// Use this for debugging or when you need more information about
/// the classification decision.
struct ClassificationResult: Sendable {
    /// The detected screenshot type.
    let type: ScreenshotType

    /// Number of keyword matches for each category.
    let scores: [ScreenshotType: Int]

    /// Whether the result is confident (clear winner).
    var isConfident: Bool {
        guard let topScore = scores.values.max(), topScore > 0 else {
            return false
        }

        // Check if there's a clear winner (no ties)
        let topScorers = scores.filter { $0.value == topScore }
        return topScorers.count == 1 && topScore >= 2
    }
}

extension ScreenshotClassifier {
    /// Classify with detailed results for debugging.
    ///
    /// - Parameter textObservations: Array of text detected in the screenshot.
    /// - Returns: Detailed classification result with scores.
    func classifyWithDetails(textObservations: [TextObservation]) -> ClassificationResult {
        let combinedText = combineObservationsToLowercase(textObservations)

        let scores: [ScreenshotType: Int] = [
            .music: countKeywordMatches(in: combinedText, keywords: ClassificationConfig.musicKeywords),
            .movie: countKeywordMatches(in: combinedText, keywords: ClassificationConfig.movieKeywords),
            .book: countKeywordMatches(in: combinedText, keywords: ClassificationConfig.bookKeywords),
            .meme: countKeywordMatches(in: combinedText, keywords: ClassificationConfig.memeKeywords),
            .unknown: 0
        ]

        let type = classify(textObservations: textObservations)

        return ClassificationResult(type: type, scores: scores)
    }
}
