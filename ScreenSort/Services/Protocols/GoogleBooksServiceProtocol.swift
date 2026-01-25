//
//  GoogleBooksServiceProtocol.swift
//  ScreenSort
//
//  Protocol for Google Books API services.
//

import Foundation

/// Result from Google Books search
struct GoogleBooksSearchResult: Equatable {
    let id: String
    let title: String
    let authors: [String]
    let infoLink: String
    let thumbnailURL: String?
}

protocol GoogleBooksServiceProtocol {
    /// Search for a book on Google Books
    /// - Parameters:
    ///   - title: The book title to search for
    ///   - author: Optional author name to narrow the search
    /// - Returns: The best matching book result
    func searchBook(title: String, author: String?) async throws -> GoogleBooksSearchResult

    /// Get the Google Books info URL for a book
    func getBookURL(id: String) -> String
}
