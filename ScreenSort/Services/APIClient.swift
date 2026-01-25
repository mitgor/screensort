import Foundation

class APIClient {

    static let shared = APIClient()

    private let session: URLSession
    private let cache: URLCache

    private init() {
        // Configure cache: 20MB memory, 100MB disk
        cache = URLCache(
            memoryCapacity: 20 * 1024 * 1024,
            diskCapacity: 100 * 1024 * 1024,
            diskPath: "youtube_api_cache"
        )

        let configuration = URLSessionConfiguration.default
        configuration.urlCache = cache
        configuration.requestCachePolicy = .returnCacheDataElseLoad

        self.session = URLSession(configuration: configuration)
    }

    // MARK: - GET Request

    func get(
        url: URL,
        headers: [String: String] = [:],
        cachePolicy: URLRequest.CachePolicy = .returnCacheDataElseLoad
    ) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = cachePolicy

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw YouTubeError.networkError(reason: "Invalid response type")
        }

        return (data, httpResponse)
    }

    // MARK: - POST Request (no caching)

    func post(
        url: URL,
        body: Data,
        headers: [String: String] = [:]
    ) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.cachePolicy = .reloadIgnoringLocalCacheData  // Don't cache POST

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw YouTubeError.networkError(reason: "Invalid response type")
        }

        return (data, httpResponse)
    }

    // MARK: - Cache Management

    /// Check if a URL response is cached
    func isCached(url: URL) -> Bool {
        let request = URLRequest(url: url)
        return cache.cachedResponse(for: request) != nil
    }

    /// Clear all cached responses
    func clearCache() {
        cache.removeAllCachedResponses()
    }

    /// Get cache statistics
    var cacheStats: (memoryUsage: Int, diskUsage: Int) {
        return (cache.currentMemoryUsage, cache.currentDiskUsage)
    }
}
