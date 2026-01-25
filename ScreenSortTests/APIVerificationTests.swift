import XCTest

final class APIVerificationTests: XCTestCase {

    // MARK: - YouTube Data API v3

    func testYouTubeAPIAccess() async throws {
        // Verify API key is configured
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "YOUTUBE_API_KEY") as? String,
              !apiKey.isEmpty,
              apiKey != "YOUR_YOUTUBE_API_KEY_HERE" else {
            XCTFail("YOUTUBE_API_KEY not configured in Secrets.xcconfig")
            return
        }

        // Use videos.list with a known video ID (costs 1 quota unit)
        // Rick Astley - Never Gonna Give You Up (always available)
        let videoId = "dQw4w9WgXcQ"
        let urlString = "https://www.googleapis.com/youtube/v3/videos?part=snippet&id=\(videoId)&key=\(apiKey)"
        let url = URL(string: urlString)!

        let (data, response) = try await URLSession.shared.data(from: url)
        let httpResponse = response as! HTTPURLResponse

        // Verify success
        XCTAssertEqual(httpResponse.statusCode, 200, "YouTube API returned \(httpResponse.statusCode)")

        // Verify response contains video data
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let items = json["items"] as? [[String: Any]]
        XCTAssertNotNil(items, "Response missing 'items' array")
        XCTAssertFalse(items!.isEmpty, "No video found for ID \(videoId)")

        // Log quota info
        print("YouTube API: SUCCESS - Quota cost: 1 unit (videos.list)")
        print("Daily quota: 10,000 units default")
    }

    // MARK: - TMDb API

    func testTMDbAPIAccess() async throws {
        // Verify Bearer token is configured
        guard let bearerToken = Bundle.main.object(forInfoDictionaryKey: "TMDB_BEARER_TOKEN") as? String,
              !bearerToken.isEmpty,
              bearerToken != "YOUR_TMDB_BEARER_TOKEN_HERE" else {
            XCTFail("TMDB_BEARER_TOKEN not configured in Secrets.xcconfig")
            return
        }

        // Use configuration endpoint (lightweight, no rate limit concern)
        var request = URLRequest(url: URL(string: "https://api.themoviedb.org/3/configuration")!)
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse

        // Verify success
        XCTAssertEqual(httpResponse.statusCode, 200, "TMDb API returned \(httpResponse.statusCode)")

        // Verify response contains configuration data
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let images = json["images"] as? [String: Any]
        XCTAssertNotNil(images, "Response missing 'images' configuration")

        // Log rate limit info
        print("TMDb API: SUCCESS - Rate limit: ~40 requests/second")
        print("No daily quota limit")
    }

    // MARK: - Hardcover API

    func testHardcoverAPIAccess() async throws {
        // Verify token is configured
        guard let token = Bundle.main.object(forInfoDictionaryKey: "HARDCOVER_TOKEN") as? String,
              !token.isEmpty,
              token != "YOUR_HARDCOVER_TOKEN_HERE" else {
            XCTFail("HARDCOVER_TOKEN not configured in Secrets.xcconfig")
            return
        }

        // Use simple GraphQL query (ilike operator not permitted, so just query first book)
        let query = """
        {
          books(limit: 1) {
            title
          }
        }
        """

        var request = URLRequest(url: URL(string: "https://api.hardcover.app/v1/graphql")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["query": query])

        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse

        // Verify success
        XCTAssertEqual(httpResponse.statusCode, 200, "Hardcover API returned \(httpResponse.statusCode)")

        // Verify response contains data (not just errors)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // Check for GraphQL errors
        if let errors = json["errors"] as? [[String: Any]] {
            let errorMessages = errors.compactMap { $0["message"] as? String }
            XCTFail("Hardcover API errors: \(errorMessages.joined(separator: ", "))")
            return
        }

        let dataObj = json["data"] as? [String: Any]
        XCTAssertNotNil(dataObj, "Response missing 'data' object")

        // Log rate limit info
        print("Hardcover API: SUCCESS - Rate limit: 60 requests/minute")
        print("Token expires: January 1st annually")
    }
}
