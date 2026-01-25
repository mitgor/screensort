//
//  MovieExtractor.swift
//  ScreenSort
//
//  Extracts movie title and related info from streaming screenshots using Apple Intelligence.
//

import Photos
import Foundation
import FoundationModels

// MARK: - AI Response Model

/// Structured output for movie extraction using Apple Intelligence.
@Generable
struct ExtractedMovieResponse {
    @Guide(description: "The movie or TV show title without any UI elements or extra text")
    var title: String

    @Guide(description: "The year of release if visible, or 0 if not found")
    var year: Int

    @Guide(description: "The director's name if visible, or empty string if not found")
    var director: String

    @Guide(description: "Confidence from 0.0 to 1.0 that this is correct movie metadata")
    var confidence: Double
}

// MARK: - Movie Extraction Validation

/// Validates AI extraction results to filter out placeholder responses.
enum MovieExtractionValidator {

    /// Patterns that indicate invalid/placeholder responses.
    private static let invalidPatterns: Set<String> = [
        "extracted",
        "unknown",
        "n/a",
        "none",
        "null",
        "undefined",
        "movie title",
        "title here",
        "placeholder",
        "not found",
        "unable to",
        "cannot"
    ]

    /// Validates that extraction contains real data, not placeholders.
    static func validate(_ response: ExtractedMovieResponse) -> ValidationResult {
        let titleLower = response.title.lowercased()
        let directorLower = response.director.lowercased()

        // Check for placeholder patterns
        for pattern in invalidPatterns {
            if titleLower.contains(pattern) {
                return .invalid(reason: "Movie title contains placeholder text: '\(pattern)'")
            }
            if !directorLower.isEmpty && directorLower.contains(pattern) {
                return .invalid(reason: "Director name contains placeholder text: '\(pattern)'")
            }
        }

        // Must have meaningful title
        guard response.title.count >= MovieMetadataConfig.minimumTitleLength else {
            return .invalid(reason: "Movie title too short (\(response.title.count) chars)")
        }

        // Check for valid confidence range
        guard response.confidence >= 0.0 && response.confidence <= 1.0 else {
            return .invalid(reason: "Confidence score out of range: \(response.confidence)")
        }

        return .valid
    }

    enum ValidationResult {
        case valid
        case invalid(reason: String)

        var isValid: Bool {
            if case .valid = self { return true }
            return false
        }
    }
}

// MARK: - AI Prompt Builder

/// Builds prompts for the Apple Intelligence extraction.
enum MovieExtractionPrompt {

    static func build(from ocrText: String) -> String {
        """
        Extract the movie or TV show information from this streaming app screenshot text.

        IMPORTANT INSTRUCTIONS:
        - Extract the ACTUAL movie/show title shown in the text
        - Do NOT return placeholder text like "Movie Title" or "Unknown"
        - Look for year of release if visible (usually in parentheses or near the title)
        - Look for director name if visible
        - Ignore UI elements: ratings, duration, play buttons, app names
        - If you cannot identify the title clearly, set confidence below 0.5

        Screenshot text:
        \(ocrText)
        """
    }
}

// MARK: - Fallback Extractor

/// Fallback extraction using pattern matching when AI is unavailable.
enum MovieFallbackExtractor {

    /// UI elements and noise to filter out
    private static let noisePatterns: Set<String> = [
        "play", "watch", "trailer", "episodes", "season",
        "netflix", "prime video", "disney+", "hbo", "hulu",
        "continue watching", "my list", "trending", "top 10",
        "new", "popular", "because you watched", "more like this"
    ]

    /// Attempts to extract movie metadata using pattern matching.
    static func extract(from observations: [TextObservation]) -> MovieMetadata? {
        let cleanLines = observations
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { line in
                let lower = line.lowercased()
                guard line.count >= 2 else { return false }
                for noise in noisePatterns {
                    if lower == noise || lower.hasPrefix(noise + " ") { return false }
                }
                return true
            }

        guard !cleanLines.isEmpty else { return nil }

        // Strategy: Take the first substantial line as the title
        // (streaming apps typically show the title prominently)
        let substantialLines = cleanLines.filter { $0.count >= 3 }
        guard let title = substantialLines.first else { return nil }

        // Look for a year pattern (4 digits, usually 19xx or 20xx)
        var year: Int?
        for line in cleanLines {
            if let match = line.range(of: #"\b(19|20)\d{2}\b"#, options: .regularExpression) {
                year = Int(line[match])
                break
            }
        }

        return MovieMetadata(
            title: title,
            year: year,
            director: nil,
            actors: [],
            confidenceScore: 0.6,
            rawText: cleanLines
        )
    }
}

// MARK: - Movie Extractor

/// Extracts movie title and metadata from streaming screenshots using Apple Intelligence.
final class MovieExtractor: MovieExtractorProtocol {

    // MARK: - Dependencies

    private let ocrService: OCRServiceProtocol
    private let classifier: ScreenshotClassifierProtocol

    // MARK: - Initialization

    init(
        ocrService: OCRServiceProtocol = OCRService(),
        classifier: ScreenshotClassifierProtocol = ScreenshotClassifier()
    ) {
        self.ocrService = ocrService
        self.classifier = classifier
    }

    // MARK: - Public API

    func extractMovieMetadata(from asset: PHAsset) async throws -> MovieMetadata {
        let observations = try await ocrService.recognizeText(from: asset, minimumConfidence: 0.0)
        return try await extractMovieMetadata(from: observations)
    }

    func extractMovieMetadata(from observations: [TextObservation]) async throws -> MovieMetadata {
        // Step 1: Verify this is a movie screenshot
        try validateIsMovieScreenshot(observations)

        // Step 2: Prepare text for AI extraction
        let combinedText = prepareTextForExtraction(observations)
        guard !combinedText.isEmpty else {
            throw MovieExtractionError.movieTitleNotFound
        }

        // Step 3: Try Apple Intelligence first, fall back to pattern matching
        do {
            let aiResponse = try await performAIExtraction(text: combinedText)

            // Step 4: Validate the extraction result
            try validateExtractionResult(aiResponse)

            // Step 5: Build and validate final metadata
            let metadata = buildMetadata(from: aiResponse, rawText: observations.map { $0.text })
            try validateConfidence(metadata)

            return metadata

        } catch {
            // Check if this is a guardrail/safety error - use fallback
            let errorString = String(describing: error)
            if errorString.contains("unsafe") ||
               errorString.contains("guardrail") ||
               errorString.contains("Guardrail") ||
               errorString.contains("safety") {
                if let fallbackResult = MovieFallbackExtractor.extract(from: observations) {
                    return fallbackResult
                }
            }

            throw error
        }
    }

    // MARK: - Private: Validation Steps

    private func validateIsMovieScreenshot(_ observations: [TextObservation]) throws {
        let screenshotType = classifier.classify(textObservations: observations)
        guard screenshotType == .movie else {
            throw MovieExtractionError.notMovieScreenshot
        }
    }

    private func validateExtractionResult(_ response: ExtractedMovieResponse) throws {
        let validation = MovieExtractionValidator.validate(response)

        guard validation.isValid else {
            if case .invalid(let reason) = validation {
                throw MovieExtractionError.invalidExtractionResult(reason: reason)
            }
            throw MovieExtractionError.movieTitleNotFound
        }
    }

    private func validateConfidence(_ metadata: MovieMetadata) throws {
        guard metadata.isHighConfidence else {
            throw MovieExtractionError.confidenceTooLow(
                score: metadata.confidenceScore,
                threshold: MovieMetadataConfig.highConfidenceThreshold
            )
        }
    }

    // MARK: - Private: Text Preparation

    private func prepareTextForExtraction(_ observations: [TextObservation]) -> String {
        observations
            .sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y }
            .map { $0.text }
            .joined(separator: "\n")
    }

    // MARK: - Private: AI Extraction

    private func performAIExtraction(text: String) async throws -> ExtractedMovieResponse {
        let session = LanguageModelSession()
        let prompt = MovieExtractionPrompt.build(from: text)

        let response = try await session.respond(
            to: prompt,
            generating: ExtractedMovieResponse.self
        )

        return response.content
    }

    // MARK: - Private: Metadata Building

    private func buildMetadata(from response: ExtractedMovieResponse, rawText: [String]) -> MovieMetadata {
        MovieMetadata(
            title: response.title.trimmingCharacters(in: .whitespacesAndNewlines),
            year: response.year > 0 ? response.year : nil,
            director: response.director.isEmpty ? nil : response.director.trimmingCharacters(in: .whitespacesAndNewlines),
            actors: [],
            confidenceScore: Float(response.confidence),
            rawText: rawText
        )
    }
}
