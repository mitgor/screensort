//
//  AIScreenshotClassifier.swift
//  ScreenSort
//
//  Uses Apple Intelligence to classify screenshots with higher accuracy than keyword matching.
//

import Foundation
import FoundationModels

// MARK: - AI Response Model

/// Structured output for screenshot classification using Apple Intelligence.
@Generable
struct ClassificationResponse {
    @Guide(description: "The content type: music, movie, book, meme, or unknown")
    var contentType: String

    @Guide(description: "Confidence from 0.0 to 1.0")
    var confidence: Double

    @Guide(description: "Brief reason for this classification")
    var reasoning: String
}

// MARK: - AI Classification Configuration

enum AIClassificationConfig {
    /// Minimum confidence required to accept AI classification
    static let minimumConfidence: Double = 0.6

    /// Valid content type strings that map to ScreenshotType
    static let validContentTypes: Set<String> = ["music", "movie", "book", "meme", "unknown"]
}

// MARK: - AI Classification Result

/// Result from AI classification with full details
struct AIClassificationResult: Sendable {
    let type: ScreenshotType
    let confidence: Double
    let reasoning: String

    /// Whether this classification is confident enough to use
    var isConfident: Bool {
        confidence >= AIClassificationConfig.minimumConfidence
    }
}

// MARK: - AI Classification Prompt

enum ClassificationPrompt {

    /// Builds the classification prompt for the given OCR text.
    static func build(from ocrText: String) -> String {
        """
        Analyze this screenshot text and classify what type of content it shows.

        CLASSIFICATION RULES:
        - "music": Screenshots from music apps (Spotify, Apple Music, Shazam, etc.)
          showing song titles, artists, album art, playback controls, lyrics, playlists
        - "movie": Screenshots from streaming apps (Netflix, Disney+, Prime Video, etc.)
          or movie review sites (IMDb, Rotten Tomatoes) showing movie/TV show information
        - "book": Screenshots from book/reading apps (Kindle, Apple Books, Goodreads, etc.)
          showing book titles, authors, reviews, reading progress
        - "meme": Screenshots containing meme text, captions, or from meme apps
          (Reddit, 9gag, imgflip, etc.)
        - "unknown": If none of the above categories clearly apply

        IMPORTANT:
        - Base your classification on the TEXT content, not assumptions
        - Set confidence low (below 0.5) if the content is ambiguous
        - Consider app-specific UI text patterns (e.g., "Now Playing" for music)

        Screenshot text:
        \(ocrText)
        """
    }
}

// MARK: - AI Screenshot Classifier

/// Classifies screenshots using Apple Intelligence for higher accuracy.
///
/// This classifier uses the on-device Foundation Models framework to analyze
/// OCR text and determine the screenshot type with semantic understanding.
///
/// ## Usage
/// ```swift
/// let classifier = AIScreenshotClassifier()
/// let result = try await classifier.classify(textObservations: observations)
/// if result.isConfident {
///     // Use AI classification
/// }
/// ```
///
/// ## Availability
/// Requires iPhone 15 Pro or later with iOS 18.1+
final class AIScreenshotClassifier: Sendable {

    // MARK: - Public API

    /// Classify a screenshot using Apple Intelligence.
    ///
    /// - Parameter textObservations: Array of text detected in the screenshot.
    /// - Returns: Classification result with type, confidence, and reasoning.
    /// - Throws: If AI classification fails.
    func classify(textObservations: [TextObservation]) async throws -> AIClassificationResult {

        // Prepare text for classification
        let combinedText = prepareText(from: textObservations)

        guard !combinedText.isEmpty else {
            return AIClassificationResult(
                type: .unknown,
                confidence: 0.0,
                reasoning: "No text detected in screenshot"
            )
        }

        // Perform AI classification
        let response = try await performClassification(text: combinedText)

        // Convert response to result
        return convertToResult(response)
    }

    /// Classify with fallback to keyword-based classification.
    ///
    /// Uses AI classification if available and confident, otherwise falls back
    /// to the provided keyword-based classifier.
    ///
    /// - Parameters:
    ///   - textObservations: Array of text detected in the screenshot.
    ///   - fallbackClassifier: Keyword-based classifier for fallback.
    /// - Returns: The most confident classification.
    func classifyWithFallback(
        textObservations: [TextObservation],
        fallbackClassifier: ScreenshotClassifierProtocol
    ) async -> ScreenshotType {
        // Try AI classification first
        do {
            let aiResult = try await classify(textObservations: textObservations)
            print("🤖 [AIClassifier] AI result: \(aiResult.type) (confidence: \(aiResult.confidence))")
            print("🤖 [AIClassifier] Reasoning: \(aiResult.reasoning)")

            if aiResult.isConfident {
                return aiResult.type
            }
        } catch {
            print("⚠️ [AIClassifier] AI classification failed: \(error)")
        }

        // Fall back to keyword-based classification
        let keywordResult = fallbackClassifier.classify(textObservations: textObservations)
        print("🔤 [AIClassifier] Fallback keyword result: \(keywordResult)")
        return keywordResult
    }

    // MARK: - Private Methods

    /// Prepares OCR observations for classification.
    private func prepareText(from observations: [TextObservation]) -> String {
        observations
            .sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y }
            .map { $0.text }
            .joined(separator: "\n")
    }

    /// Performs AI classification using Apple Intelligence.
    private func performClassification(text: String) async throws -> ClassificationResponse {
        let session = LanguageModelSession()
        let prompt = ClassificationPrompt.build(from: text)

        let response = try await session.respond(
            to: prompt,
            generating: ClassificationResponse.self
        )

        return response.content
    }

    /// Converts AI response to classification result.
    private func convertToResult(_ response: ClassificationResponse) -> AIClassificationResult {
        // Parse content type string to enum
        let contentType = response.contentType.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let type: ScreenshotType

        switch contentType {
        case "music":
            type = .music
        case "movie", "movies", "tv", "show", "tv show":
            type = .movie
        case "book", "books", "reading":
            type = .book
        case "meme", "memes":
            type = .meme
        default:
            type = .unknown
        }

        // Clamp confidence to valid range
        let confidence = min(max(response.confidence, 0.0), 1.0)

        return AIClassificationResult(
            type: type,
            confidence: confidence,
            reasoning: response.reasoning
        )
    }
}

// MARK: - AI Classification Errors

enum AIClassificationError: Error, LocalizedError {
    case modelUnavailable
    case classificationFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelUnavailable:
            return "Apple Intelligence is not available on this device"
        case .classificationFailed(let reason):
            return "Classification failed: \(reason)"
        }
    }
}
