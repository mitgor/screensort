//
//  MusicExtractorProtocol.swift
//  ScreenSort
//
//  Created by Claude on 2026-01-25.
//

import Photos

protocol MusicExtractorProtocol {
    /// Extract music metadata from a screenshot asset
    func extractMusicMetadata(from asset: PHAsset) async throws -> MusicMetadata

    /// Extract music metadata from pre-extracted OCR observations
    func extractMusicMetadata(from observations: [TextObservation]) async throws -> MusicMetadata
}
