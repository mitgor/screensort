//
//  OCRService.swift
//  ScreenSort
//
//  Created by Claude on 2026-01-25.
//

import UIKit
import Vision
import Photos

/// Service for extracting text from images using Apple's Vision Framework
/// All processing is on-device with no network calls (except iCloud photo fetch)
final class OCRService: OCRServiceProtocol, Sendable {

    // MARK: - Public API

    /// Extract all text from a UIImage using Vision Framework
    /// - Parameters:
    ///   - image: The UIImage to extract text from
    ///   - minimumConfidence: Optional filter for low-confidence results (0.0-1.0, default 0.0)
    /// - Returns: Array of TextObservation sorted by vertical position (top to bottom)
    /// - Throws: OCRError if image is invalid or text recognition fails
    func recognizeText(in image: UIImage, minimumConfidence: Float = 0.0) async throws -> [TextObservation] {
        // Validate we have a CGImage
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        // Create text recognition request with optimal settings
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate  // 98-99% accuracy
        request.usesLanguageCorrection = true  // Better accuracy for real words
        request.recognitionLanguages = ["en-US"]  // English primary

        // Create image handler with correct orientation
        let orientation = cgImageOrientation(from: image.imageOrientation)
        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: orientation,
            options: [:]
        )

        // Perform recognition (synchronous but CPU-intensive)
        do {
            try handler.perform([request])
        } catch {
            throw OCRError.recognitionFailed(reason: error.localizedDescription)
        }

        // Extract results
        guard let results = request.results, !results.isEmpty else {
            throw OCRError.noTextFound
        }

        // Map Vision results to TextObservation
        let observations = results.compactMap { observation -> TextObservation? in
            guard let candidate = observation.topCandidates(1).first else {
                return nil
            }

            // Skip empty text
            guard !candidate.string.trimmingCharacters(in: .whitespaces).isEmpty else {
                return nil
            }

            // Filter by minimum confidence
            guard candidate.confidence >= minimumConfidence else {
                return nil
            }

            return TextObservation(
                text: candidate.string,
                confidence: candidate.confidence,
                boundingBox: observation.boundingBox
            )
        }

        guard !observations.isEmpty else {
            throw OCRError.noTextFound
        }

        // Log warning if all observations have very low confidence
        let maxConfidence = observations.map { $0.confidence }.max() ?? 0.0
        if maxConfidence < 0.3 {
            print("[OCRService] Warning: All text observations have confidence < 0.3. Image quality may be poor.")
        }

        // Sort by vertical position (top to bottom on screen)
        // Vision coordinates have origin at bottom-left, so sort by descending y
        return observations.sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y }
    }

    /// Extract all text from a PHAsset by loading full-resolution image
    /// - Parameters:
    ///   - asset: The PHAsset to extract text from
    ///   - minimumConfidence: Optional filter for low-confidence results (0.0-1.0, default 0.0)
    /// - Returns: Array of TextObservation sorted by vertical position (top to bottom)
    /// - Throws: OCRError if asset cannot be loaded or text recognition fails
    func recognizeText(from asset: PHAsset, minimumConfidence: Float = 0.0) async throws -> [TextObservation] {
        // Configure image request options
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true  // For iCloud photos
        options.isSynchronous = false

        // Load full-resolution image asynchronously
        let image = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UIImage, Error>) in
            var hasResumed = false  // Prevent multiple resume calls

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                // Ignore degraded images (PHImageManager may call handler multiple times)
                if let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool, isDegraded {
                    return
                }

                // Prevent multiple resume calls
                guard !hasResumed else { return }
                hasResumed = true

                // Check for errors
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }

                // Return the image
                if let image = image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: OCRError.invalidImage)
                }
            }
        }

        // Perform OCR on loaded image
        return try await recognizeText(in: image, minimumConfidence: minimumConfidence)
    }

    // MARK: - Helper Methods

    /// Convert UIImage.Orientation to CGImagePropertyOrientation for Vision Framework
    private func cgImageOrientation(from uiOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch uiOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
