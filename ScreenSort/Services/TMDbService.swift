//
//  TMDbService.swift
//  ScreenSort
//
//  TMDb API integration for movie search and linking.
//

import Foundation

/// Service for searching movies on TMDb
final class TMDbService: TMDbServiceProtocol {

    // MARK: - Properties

    private let apiClient: APIClient
    private let apiKey: String?

    private let baseURL = "https://api.themoviedb.org/3"
    private let webBaseURL = "https://www.themoviedb.org/movie"

    // MARK: - Initialization

    init(apiClient: APIClient = APIClient.shared) {
        self.apiClient = apiClient
        // Load API key from bundle (set in xcconfig or Info.plist)
        self.apiKey = Bundle.main.object(forInfoDictionaryKey: "TMDB_API_KEY") as? String
    }

    // MARK: - TMDbServiceProtocol

    var isConfigured: Bool {
        guard let key = apiKey, !key.isEmpty else { return false }
        // Check it's not a placeholder
        return !key.contains("YOUR_") && key.count > 10
    }

    func searchMovie(title: String, year: Int?) async throws -> TMDbSearchResult {
        guard isConfigured, let apiKey = apiKey else {
            throw TMDbError.notConfigured
        }

        // Build search URL
        var components = URLComponents(string: "\(baseURL)/search/movie")!
        var queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: title),
            URLQueryItem(name: "language", value: "en-US"),
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "include_adult", value: "false")
        ]

        if let year = year {
            queryItems.append(URLQueryItem(name: "year", value: String(year)))
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw TMDbError.searchFailed(reason: "Invalid URL")
        }

        // Make request
        let (data, response) = try await apiClient.get(
            url: url,
            headers: [:],
            cachePolicy: .returnCacheDataElseLoad
        )

        guard (200...299).contains(response.statusCode) else {
            if response.statusCode == 401 {
                throw TMDbError.notConfigured
            }
            let message = String(data: data, encoding: .utf8)
            throw TMDbError.invalidResponse(statusCode: response.statusCode, message: message)
        }

        // Parse response
        let searchResponse = try JSONDecoder().decode(TMDbSearchResponse.self, from: data)

        guard let firstResult = searchResponse.results.first else {
            throw TMDbError.noResultsFound(query: title)
        }

        // Extract year from release date
        var movieYear: Int?
        if let releaseDate = firstResult.releaseDate, releaseDate.count >= 4 {
            movieYear = Int(String(releaseDate.prefix(4)))
        }

        return TMDbSearchResult(
            id: firstResult.id,
            title: firstResult.title,
            year: movieYear,
            tmdbURL: getMovieURL(id: firstResult.id),
            posterPath: firstResult.posterPath
        )
    }

    func getMovieURL(id: Int) -> String {
        "\(webBaseURL)/\(id)"
    }
}

// MARK: - Response Models

private struct TMDbSearchResponse: Decodable {
    let page: Int
    let results: [TMDbMovie]
    let totalResults: Int
    let totalPages: Int

    enum CodingKeys: String, CodingKey {
        case page
        case results
        case totalResults = "total_results"
        case totalPages = "total_pages"
    }
}

private struct TMDbMovie: Decodable {
    let id: Int
    let title: String
    let releaseDate: String?
    let posterPath: String?
    let overview: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case releaseDate = "release_date"
        case posterPath = "poster_path"
        case overview
    }
}
