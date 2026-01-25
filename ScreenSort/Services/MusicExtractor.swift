//
//  MusicExtractor.swift
//  ScreenSort
//
//  Extracts song title and artist from music screenshots using Apple Intelligence.
//

import Photos
import Foundation
import FoundationModels

// MARK: - AI Response Model

/// Structured output for music extraction using Apple Intelligence.
///
/// This model is used with the Foundation Models framework to get
/// structured responses from the on-device AI.
@Generable
struct ExtractedMusicResponse {
    @Guide(description: "The song title without any UI elements, timestamps, or extra text")
    var songTitle: String

    @Guide(description: "The artist or band name")
    var artist: String

    @Guide(description: "Confidence from 0.0 to 1.0 that this is correct music metadata")
    var confidence: Double
}

// MARK: - Extraction Validation

/// Validates AI extraction results to filter out placeholder responses.
///
/// The AI model sometimes returns placeholder text when it can't extract
/// meaningful data. This validator catches those cases.
enum ExtractionValidator {

    /// Patterns that indicate invalid/placeholder responses.
    private static let invalidPatterns: Set<String> = [
        "extracted",
        "unknown",
        "n/a",
        "none",
        "null",
        "undefined",
        "song title",
        "artist name",
        "placeholder",
        "not found",
        "unable to",
        "cannot"
    ]

    /// Validates that extraction contains real data, not placeholders.
    ///
    /// - Parameter response: The AI extraction response.
    /// - Returns: A validation result with error details if invalid.
    static func validate(_ response: ExtractedMusicResponse) -> ValidationResult {
        let titleLower = response.songTitle.lowercased()
        let artistLower = response.artist.lowercased()

        // Check for placeholder patterns
        for pattern in invalidPatterns {
            if titleLower.contains(pattern) {
                return .invalid(reason: "Song title contains placeholder text: '\(pattern)'")
            }
            if artistLower.contains(pattern) {
                return .invalid(reason: "Artist name contains placeholder text: '\(pattern)'")
            }
        }

        // Must have meaningful content
        guard response.songTitle.count >= MusicMetadataConfig.minimumTitleLength else {
            return .invalid(reason: "Song title too short (\(response.songTitle.count) chars)")
        }

        guard response.artist.count >= MusicMetadataConfig.minimumArtistLength else {
            return .invalid(reason: "Artist name too short (\(response.artist.count) chars)")
        }

        // Check for valid confidence range
        guard response.confidence >= 0.0 && response.confidence <= 1.0 else {
            return .invalid(reason: "Confidence score out of range: \(response.confidence)")
        }

        return .valid
    }

    /// Result of extraction validation.
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
enum MusicExtractionPrompt {

    /// Builds the extraction prompt for the given OCR text.
    ///
    /// - Parameter ocrText: The combined text from OCR recognition.
    /// - Returns: A formatted prompt for the AI model.
    static func build(from ocrText: String) -> String {
        """
        Extract the song name and artist from this music player screenshot text.

        IMPORTANT INSTRUCTIONS:
        - Extract the ACTUAL song title and artist shown in the text
        - Do NOT return placeholder text like "Song Title" or "Artist Name"
        - Ignore UI elements: timestamps, battery percentage, playback controls, app names
        - If you cannot identify both song and artist clearly, set confidence below 0.5

        Screenshot text:
        \(ocrText)
        """
    }
}

// MARK: - Music Extractor

/// Extracts song title and artist from music screenshots using Apple Intelligence.
///
/// This service combines OCR text recognition with on-device AI to accurately
/// identify music information from screenshots of various music apps.
///
/// ## Usage
/// ```swift
/// let extractor = MusicExtractor()
///
/// // From a photo asset
/// let metadata = try await extractor.extractMusicMetadata(from: asset)
///
/// // From pre-extracted OCR text
/// let metadata = try await extractor.extractMusicMetadata(from: observations)
/// ```
///
/// ## Error Handling
/// The extractor throws `MusicExtractionError` for various failure cases:
/// - `.notMusicScreenshot` - Screenshot doesn't appear to be from a music app
/// - `.songTitleNotFound` - AI couldn't extract a valid song title
/// - `.confidenceTooLow` - Extraction confidence below threshold
/// - `.modelUnavailable` - Apple Intelligence not available on device
final class MusicExtractor: MusicExtractorProtocol {

    // MARK: - Dependencies

    private let ocrService: OCRServiceProtocol
    private let classifier: ScreenshotClassifierProtocol

    // MARK: - Initialization

    /// Creates a new music extractor with the specified dependencies.
    ///
    /// - Parameters:
    ///   - ocrService: Service for text recognition. Defaults to `OCRService()`.
    ///   - classifier: Service for screenshot classification. Defaults to `ScreenshotClassifier()`.
    init(
        ocrService: OCRServiceProtocol = OCRService(),
        classifier: ScreenshotClassifierProtocol = ScreenshotClassifier()
    ) {
        self.ocrService = ocrService
        self.classifier = classifier
    }

    // MARK: - Public API

    /// Extract music metadata from a photo asset.
    ///
    /// This method performs OCR on the asset and then extracts music information.
    ///
    /// - Parameter asset: The photo asset to extract from.
    /// - Returns: Extracted music metadata.
    /// - Throws: `MusicExtractionError` or `OCRError` if extraction fails.
    func extractMusicMetadata(from asset: PHAsset) async throws -> MusicMetadata {
        // Perform OCR with no minimum confidence filter (we'll handle confidence later)
        let observations = try await ocrService.recognizeText(from: asset, minimumConfidence: 0.0)
        return try await extractMusicMetadata(from: observations)
    }

    /// Extract music metadata from pre-extracted OCR observations.
    ///
    /// Use this method when you already have OCR results and want to
    /// skip the OCR step.
    ///
    /// - Parameter observations: Array of text observations from OCR.
    /// - Returns: Extracted music metadata.
    /// - Throws: `MusicExtractionError` if extraction fails.
    func extractMusicMetadata(from observations: [TextObservation]) async throws -> MusicMetadata {
        // Step 1: Verify this is a music screenshot
        try validateIsMusicScreenshot(observations)

        // Step 2: Prepare text for AI extraction
        let combinedText = prepareTextForExtraction(observations)
        guard !combinedText.isEmpty else {
            throw MusicExtractionError.songTitleNotFound
        }

        // Step 3: Extract with Apple Intelligence
        let aiResponse = try await performAIExtraction(text: combinedText)

        // Step 4: Validate the extraction result
        try validateExtractionResult(aiResponse)

        // Step 5: Build and validate final metadata
        let metadata = buildMetadata(from: aiResponse, rawText: observations.map { $0.text })
        try validateConfidence(metadata)

        return metadata
    }

    // MARK: - Private: Validation Steps

    /// Validates that the observations are from a music screenshot.
    private func validateIsMusicScreenshot(_ observations: [TextObservation]) throws {
        let screenshotType = classifier.classify(textObservations: observations)
        let hasMusicPattern = classifier.hasMusicUIPattern(textObservations: observations)

        guard screenshotType == .music || hasMusicPattern else {
            throw MusicExtractionError.notMusicScreenshot
        }
    }

    /// Validates the AI extraction result.
    private func validateExtractionResult(_ response: ExtractedMusicResponse) throws {
        let validation = ExtractionValidator.validate(response)

        guard validation.isValid else {
            if case .invalid(let reason) = validation {
                throw MusicExtractionError.invalidExtractionResult(reason: reason)
            }
            throw MusicExtractionError.songTitleNotFound
        }
    }

    /// Validates the confidence threshold.
    private func validateConfidence(_ metadata: MusicMetadata) throws {
        guard metadata.isHighConfidence else {
            throw MusicExtractionError.confidenceTooLow(
                score: metadata.confidenceScore,
                threshold: MusicMetadataConfig.highConfidenceThreshold
            )
        }
    }

    // MARK: - Private: Text Preparation

    /// Prepares OCR observations for AI extraction.
    ///
    /// Sorts text by vertical position (top to bottom on screen) and
    /// joins into a single string.
    private func prepareTextForExtraction(_ observations: [TextObservation]) -> String {
        observations
            // Sort by Y position (Vision uses bottom-left origin, so higher Y = higher on screen)
            .sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y }
            .map { $0.text }
            .joined(separator: "\n")
    }

    // MARK: - Private: AI Extraction

    /// Performs AI extraction using Apple Intelligence.
    private func performAIExtraction(text: String) async throws -> ExtractedMusicResponse {
        let session = LanguageModelSession()
        let prompt = MusicExtractionPrompt.build(from: text)

        let response = try await session.respond(
            to: prompt,
            generating: ExtractedMusicResponse.self
        )

        return response.content
    }

    // MARK: - Private: Metadata Building

    /// Builds MusicMetadata from the AI response.
    private func buildMetadata(from response: ExtractedMusicResponse, rawText: [String]) -> MusicMetadata {
        MusicMetadata(
            songTitle: response.songTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            artist: response.artist.trimmingCharacters(in: .whitespacesAndNewlines),
            confidenceScore: Float(response.confidence),
            rawText: rawText
        )
    }
}
