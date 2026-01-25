//
//  MemeDetector.swift
//  ScreenSort
//
//  Simple meme detection service. Memes are moved to album without extraction/logging.
//

import Photos
import Foundation

/// Service for detecting meme screenshots.
///
/// Unlike other content types, memes don't need metadata extraction or logging.
/// They are simply moved to the "ScreenSort - Memes" album.
final class MemeDetector {

    // MARK: - Dependencies

    private let classifier: ScreenshotClassifierProtocol

    // MARK: - Initialization

    init(classifier: ScreenshotClassifierProtocol = ScreenshotClassifier()) {
        self.classifier = classifier
    }

    // MARK: - Public API

    /// Check if the screenshot is a meme based on OCR text.
    ///
    /// - Parameter observations: Text observations from OCR.
    /// - Returns: `true` if the screenshot appears to be a meme.
    func isMeme(observations: [TextObservation]) -> Bool {
        let screenshotType = classifier.classify(textObservations: observations)
        return screenshotType == .meme
    }

    /// Check if the screenshot is a meme from a photo asset.
    ///
    /// - Parameters:
    ///   - asset: The photo asset to check.
    ///   - ocrService: OCR service to use for text recognition.
    /// - Returns: `true` if the screenshot appears to be a meme.
    func isMeme(asset: PHAsset, ocrService: OCRServiceProtocol) async -> Bool {
        do {
            let observations = try await ocrService.recognizeText(from: asset, minimumConfidence: 0.0)
            return isMeme(observations: observations)
        } catch {
            return false
        }
    }
}
