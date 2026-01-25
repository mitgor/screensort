//
//  TMDbServiceProtocol.swift
//  ScreenSort
//
//  Protocol for TMDb API services.
//

import Foundation

/// Result from TMDb movie search
struct TMDbSearchResult: Equatable {
    let id: Int
    let title: String
    let year: Int?
    let tmdbURL: String
    let posterPath: String?
}

protocol TMDbServiceProtocol {
    /// Whether TMDb API is configured (API key present)
    var isConfigured: Bool { get }

    /// Search for a movie on TMDb
    /// - Parameters:
    ///   - title: The movie title to search for
    ///   - year: Optional year to narrow the search
    /// - Returns: The best matching movie result
    func searchMovie(title: String, year: Int?) async throws -> TMDbSearchResult

    /// Get the TMDb URL for a movie
    func getMovieURL(id: Int) -> String
}
