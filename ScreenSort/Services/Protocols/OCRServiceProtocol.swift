//
//  OCRServiceProtocol.swift
//  ScreenSort
//
//  Created by Claude on 2026-01-25.
//

import UIKit
import Photos

/// Result of text recognition with confidence
struct TextObservation: Equatable {
    let text: String
    let confidence: Float
    let boundingBox: CGRect  // Normalized coordinates (0-1)
}

protocol OCRServiceProtocol {
    /// Extract all text from a UIImage
    /// - Parameters:
    ///   - image: The UIImage to extract text from
    ///   - minimumConfidence: Optional filter for low-confidence results (0.0-1.0, default 0.0)
    /// - Returns: Array of TextObservation sorted by vertical position (top to bottom)
    func recognizeText(in image: UIImage, minimumConfidence: Float) async throws -> [TextObservation]

    /// Extract all text from a PHAsset (loads full-resolution image)
    /// - Parameters:
    ///   - asset: The PHAsset to extract text from
    ///   - minimumConfidence: Optional filter for low-confidence results (0.0-1.0, default 0.0)
    /// - Returns: Array of TextObservation sorted by vertical position (top to bottom)
    func recognizeText(from asset: PHAsset, minimumConfidence: Float) async throws -> [TextObservation]
}
