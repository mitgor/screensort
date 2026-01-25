//
//  MovieExtractorProtocol.swift
//  ScreenSort
//
//  Protocol for movie metadata extraction services.
//

import Photos

protocol MovieExtractorProtocol {
    /// Extract movie metadata from a screenshot asset
    func extractMovieMetadata(from asset: PHAsset) async throws -> MovieMetadata

    /// Extract movie metadata from pre-extracted OCR observations
    func extractMovieMetadata(from observations: [TextObservation]) async throws -> MovieMetadata
}
