//
//  GoogleBooksService.swift
//  ScreenSort
//
//  Google Books API integration for book search and linking.
//

import Foundation

/// Service for searching books on Google Books
final class GoogleBooksService: GoogleBooksServiceProtocol {

    // MARK: - Properties

    private let authService: AuthServiceProtocol
    private let apiClient: APIClient

    private let baseURL = "https://www.googleapis.com/books/v1/volumes"

    // MARK: - Initialization

    init(
        authService: AuthServiceProtocol = AuthService(),
        apiClient: APIClient = APIClient.shared
    ) {
        self.authService = authService
        self.apiClient = apiClient
    }

    // MARK: - GoogleBooksServiceProtocol

    func searchBook(title: String, author: String?) async throws -> GoogleBooksSearchResult {
        let accessToken = try await authService.getValidAccessToken()

        // Build search query
        var query = "intitle:\(title)"
        if let author = author, !author.isEmpty {
            query += "+inauthor:\(author)"
        }

        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "maxResults", value: "1"),
            URLQueryItem(name: "printType", value: "books")
        ]

        guard let url = components.url else {
            throw GoogleBooksError.searchFailed(reason: "Invalid URL")
        }

        // Make request
        let (data, response) = try await apiClient.get(
            url: url,
            headers: ["Authorization": "Bearer \(accessToken)"],
            cachePolicy: .returnCacheDataElseLoad
        )

        if response.statusCode == 401 || response.statusCode == 403 {
            throw GoogleBooksError.notAuthenticated
        }

        guard (200...299).contains(response.statusCode) else {
            let message = String(data: data, encoding: .utf8)
            throw GoogleBooksError.invalidResponse(statusCode: response.statusCode, message: message)
        }

        // Parse response
        let searchResponse = try JSONDecoder().decode(GoogleBooksResponse.self, from: data)

        guard let firstItem = searchResponse.items?.first else {
            throw GoogleBooksError.noResultsFound(query: title)
        }

        let volumeInfo = firstItem.volumeInfo

        return GoogleBooksSearchResult(
            id: firstItem.id,
            title: volumeInfo.title,
            authors: volumeInfo.authors ?? [],
            infoLink: volumeInfo.infoLink ?? getBookURL(id: firstItem.id),
            thumbnailURL: volumeInfo.imageLinks?.thumbnail
        )
    }

    func getBookURL(id: String) -> String {
        "https://books.google.com/books?id=\(id)"
    }
}

// MARK: - Response Models

private struct GoogleBooksResponse: Decodable {
    let kind: String
    let totalItems: Int
    let items: [GoogleBookItem]?
}

private struct GoogleBookItem: Decodable {
    let id: String
    let volumeInfo: VolumeInfo

    struct VolumeInfo: Decodable {
        let title: String
        let authors: [String]?
        let publisher: String?
        let publishedDate: String?
        let description: String?
        let industryIdentifiers: [IndustryIdentifier]?
        let imageLinks: ImageLinks?
        let infoLink: String?
    }

    struct IndustryIdentifier: Decodable {
        let type: String
        let identifier: String
    }

    struct ImageLinks: Decodable {
        let thumbnail: String?
        let smallThumbnail: String?
    }
}
