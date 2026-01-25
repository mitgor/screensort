//
//  GoogleDocsServiceProtocol.swift
//  ScreenSort
//
//  Created by Claude on 2026-01-25.
//

import Foundation

/// Content entry for logging to Google Docs
struct ContentLogEntry: Equatable, Hashable {
    let type: ContentType
    let title: String
    let creator: String  // artist, author, director
    let serviceLink: String?  // YouTube, TMDb, etc.
    let capturedAt: Date

    enum ContentType: String, CaseIterable {
        case music = "Music"
        case movie = "Movies"
        case book = "Books"
        case unknown = "Other"
    }

    var displayText: String {
        var text = "\(title) - \(creator)"
        if let link = serviceLink {
            text += " [\(link)]"
        }
        return text
    }
}

protocol GoogleDocsServiceProtocol {
    /// Append a content entry to the Google Doc, avoiding duplicates
    /// Returns true if entry was added (not a duplicate)
    func appendEntry(_ entry: ContentLogEntry) async throws -> Bool

    /// Get all existing entries (for duplicate checking)
    func getExistingEntries() async throws -> [ContentLogEntry]

    /// Get the Google Doc URL
    var documentURL: String? { get }
}
