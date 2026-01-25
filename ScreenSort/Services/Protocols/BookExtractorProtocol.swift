//
//  BookExtractorProtocol.swift
//  ScreenSort
//
//  Protocol for book metadata extraction services.
//

import Photos

protocol BookExtractorProtocol {
    /// Extract book metadata from a screenshot asset
    func extractBookMetadata(from asset: PHAsset) async throws -> BookMetadata

    /// Extract book metadata from pre-extracted OCR observations
    func extractBookMetadata(from observations: [TextObservation]) async throws -> BookMetadata
}
