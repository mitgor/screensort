//
//  BookExtractor.swift
//  ScreenSort
//
//  Extracts book title and author from book app screenshots using Apple Intelligence.
//

import Photos
import Foundation
import FoundationModels

// MARK: - AI Response Model

/// Structured output for book extraction using Apple Intelligence.
@Generable
struct ExtractedBookResponse {
    @Guide(description: "The book title without any UI elements or extra text")
    var title: String

    @Guide(description: "The author's name")
    var author: String

    @Guide(description: "ISBN if visible, or empty string if not found")
    var isbn: String

    @Guide(description: "Confidence from 0.0 to 1.0 that this is correct book metadata")
    var confidence: Double
}

// MARK: - Book Extraction Validation

/// Validates AI extraction results to filter out placeholder responses.
enum BookExtractionValidator {

    /// Patterns that indicate invalid/placeholder responses.
    private static let invalidPatterns: Set<String> = [
        "extracted",
        "unknown",
        "n/a",
        "none",
        "null",
        "undefined",
        "book title",
        "author name",
        "title here",
        "placeholder",
        "not found",
        "unable to",
        "cannot"
    ]

    /// Validates that extraction contains real data, not placeholders.
    static func validate(_ response: ExtractedBookResponse) -> ValidationResult {
        let titleLower = response.title.lowercased()
        let authorLower = response.author.lowercased()

        // Check for placeholder patterns
        for pattern in invalidPatterns {
            if titleLower.contains(pattern) {
                return .invalid(reason: "Book title contains placeholder text: '\(pattern)'")
            }
            if authorLower.contains(pattern) {
                return .invalid(reason: "Author name contains placeholder text: '\(pattern)'")
            }
        }

        // Must have meaningful content
        guard response.title.count >= BookMetadataConfig.minimumTitleLength else {
            return .invalid(reason: "Book title too short (\(response.title.count) chars)")
        }

        guard response.author.count >= BookMetadataConfig.minimumAuthorLength else {
            return .invalid(reason: "Author name too short (\(response.author.count) chars)")
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
enum BookExtractionPrompt {

    static func build(from ocrText: String) -> String {
        """
        Extract the book information from this book app screenshot text.

        IMPORTANT INSTRUCTIONS:
        - Extract the ACTUAL book title shown in the text
        - Extract the ACTUAL author name shown in the text
        - Do NOT return placeholder text like "Book Title" or "Author Name"
        - Look for ISBN if visible (usually starts with 978 or 979)
        - Ignore UI elements: ratings, reviews count, page numbers, app names
        - If you cannot identify both title and author clearly, set confidence below 0.5

        Screenshot text:
        \(ocrText)
        """
    }
}

// MARK: - Fallback Extractor

/// Fallback extraction using pattern matching when AI is unavailable.
enum BookFallbackExtractor {

    /// UI elements and noise to filter out
    private static let noisePatterns: Set<String> = [
        "goodreads", "kindle", "apple books", "audible", "libby",
        "want to read", "currently reading", "read",
        "ratings", "reviews", "pages", "chapter",
        "buy", "sample", "download", "share"
    ]

    /// Attempts to extract book metadata using pattern matching.
    static func extract(from observations: [TextObservation]) -> BookMetadata? {
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

        guard cleanLines.count >= 2 else { return nil }

        // Strategy 1: Look for "by Author" pattern
        for (index, line) in cleanLines.enumerated() {
            if line.lowercased().hasPrefix("by ") && line.count > 4 {
                let author = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                // Title should be the line before
                if index > 0 {
                    return BookMetadata(
                        title: cleanLines[index - 1],
                        author: author,
                        isbn: nil,
                        confidenceScore: 0.7,
                        rawText: cleanLines
                    )
                }
            }
        }

        // Strategy 2: First two substantial lines are title and author
        let substantialLines = cleanLines.filter { $0.count >= 3 }
        guard substantialLines.count >= 2 else { return nil }

        return BookMetadata(
            title: substantialLines[0],
            author: substantialLines[1],
            isbn: nil,
            confidenceScore: 0.6,
            rawText: cleanLines
        )
    }
}

// MARK: - Book Extractor

/// Extracts book title and author from book app screenshots using Apple Intelligence.
final class BookExtractor: BookExtractorProtocol {

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

    func extractBookMetadata(from asset: PHAsset) async throws -> BookMetadata {
        let observations = try await ocrService.recognizeText(from: asset, minimumConfidence: 0.0)
        return try await extractBookMetadata(from: observations)
    }

    func extractBookMetadata(from observations: [TextObservation]) async throws -> BookMetadata {
        // Step 1: Verify this is a book screenshot
        try validateIsBookScreenshot(observations)

        // Step 2: Prepare text for AI extraction
        let combinedText = prepareTextForExtraction(observations)
        guard !combinedText.isEmpty else {
            throw BookExtractionError.bookTitleNotFound
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
                if let fallbackResult = BookFallbackExtractor.extract(from: observations) {
                    return fallbackResult
                }
            }

            throw error
        }
    }

    // MARK: - Private: Validation Steps

    private func validateIsBookScreenshot(_ observations: [TextObservation]) throws {
        let screenshotType = classifier.classify(textObservations: observations)
        guard screenshotType == .book else {
            throw BookExtractionError.notBookScreenshot
        }
    }

    private func validateExtractionResult(_ response: ExtractedBookResponse) throws {
        let validation = BookExtractionValidator.validate(response)

        guard validation.isValid else {
            if case .invalid(let reason) = validation {
                throw BookExtractionError.invalidExtractionResult(reason: reason)
            }
            throw BookExtractionError.bookTitleNotFound
        }
    }

    private func validateConfidence(_ metadata: BookMetadata) throws {
        guard metadata.isHighConfidence else {
            throw BookExtractionError.confidenceTooLow(
                score: metadata.confidenceScore,
                threshold: BookMetadataConfig.highConfidenceThreshold
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

    private func performAIExtraction(text: String) async throws -> ExtractedBookResponse {
        let session = LanguageModelSession()
        let prompt = BookExtractionPrompt.build(from: text)

        let response = try await session.respond(
            to: prompt,
            generating: ExtractedBookResponse.self
        )

        return response.content
    }

    // MARK: - Private: Metadata Building

    private func buildMetadata(from response: ExtractedBookResponse, rawText: [String]) -> BookMetadata {
        BookMetadata(
            title: response.title.trimmingCharacters(in: .whitespacesAndNewlines),
            author: response.author.trimmingCharacters(in: .whitespacesAndNewlines),
            isbn: response.isbn.isEmpty ? nil : response.isbn,
            confidenceScore: Float(response.confidence),
            rawText: rawText
        )
    }
}
