#!/usr/bin/env swift

import Foundation

// Read API keys from Secrets.xcconfig
func loadAPIKeys() -> (youtubeKey: String, tmdbToken: String, hardcoverToken: String)? {
    guard let content = try? String(contentsOfFile: "Config/Secrets.xcconfig", encoding: .utf8) else {
        print("ERROR: Could not read Config/Secrets.xcconfig")
        return nil
    }

    var youtubeKey = ""
    var tmdbToken = ""
    var hardcoverToken = ""

    for line in content.components(separatedBy: .newlines) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("YOUTUBE_API_KEY") {
            youtubeKey = trimmed.components(separatedBy: "=").last?.trimmingCharacters(in: .whitespaces) ?? ""
        } else if trimmed.hasPrefix("TMDB_BEARER_TOKEN") {
            tmdbToken = trimmed.components(separatedBy: "=").last?.trimmingCharacters(in: .whitespaces) ?? ""
        } else if trimmed.hasPrefix("HARDCOVER_TOKEN") {
            hardcoverToken = trimmed.components(separatedBy: "=").last?.trimmingCharacters(in: .whitespaces) ?? ""
        }
    }

    guard !youtubeKey.isEmpty, !tmdbToken.isEmpty, !hardcoverToken.isEmpty else {
        print("ERROR: One or more API keys are missing")
        return nil
    }

    return (youtubeKey, tmdbToken, hardcoverToken)
}

// Test YouTube API
func testYouTubeAPI(apiKey: String) async -> Bool {
    print("\n--- Testing YouTube Data API v3 ---")

    let videoId = "dQw4w9WgXcQ"
    let urlString = "https://www.googleapis.com/youtube/v3/videos?part=snippet&id=\(videoId)&key=\(apiKey)"

    guard let url = URL(string: urlString) else {
        print("❌ Invalid URL")
        return false
    }

    do {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid response type")
            return false
        }

        print("Status code: \(httpResponse.statusCode)")

        if httpResponse.statusCode == 200 {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let items = json?["items"] as? [[String: Any]]

            if let items = items, !items.isEmpty {
                print("✅ YouTube API: SUCCESS - Quota cost: 1 unit (videos.list)")
                print("   Daily quota: 10,000 units default")
                return true
            } else {
                print("❌ No video data returned")
                return false
            }
        } else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error body"
            print("❌ YouTube API returned \(httpResponse.statusCode)")
            print("   Response: \(errorBody)")
            return false
        }
    } catch {
        print("❌ Error: \(error.localizedDescription)")
        return false
    }
}

// Test TMDb API
func testTMDbAPI(bearerToken: String) async -> Bool {
    print("\n--- Testing TMDb API ---")

    guard let url = URL(string: "https://api.themoviedb.org/3/configuration") else {
        print("❌ Invalid URL")
        return false
    }

    var request = URLRequest(url: url)
    request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")

    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid response type")
            return false
        }

        print("Status code: \(httpResponse.statusCode)")

        if httpResponse.statusCode == 200 {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let images = json?["images"] as? [String: Any]

            if images != nil {
                print("✅ TMDb API: SUCCESS - Rate limit: ~40 requests/second")
                print("   No daily quota limit")
                return true
            } else {
                print("❌ No configuration data returned")
                return false
            }
        } else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error body"
            print("❌ TMDb API returned \(httpResponse.statusCode)")
            print("   Response: \(errorBody)")
            return false
        }
    } catch {
        print("❌ Error: \(error.localizedDescription)")
        return false
    }
}

// Test Hardcover API
func testHardcoverAPI(token: String) async -> Bool {
    print("\n--- Testing Hardcover API ---")

    guard let url = URL(string: "https://api.hardcover.app/v1/graphql") else {
        print("❌ Invalid URL")
        return false
    }

    let query = """
    {
      books(limit: 1) {
        title
      }
    }
    """

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: ["query": query])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid response type")
            return false
        }

        print("Status code: \(httpResponse.statusCode)")

        if httpResponse.statusCode == 200 {
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            // Check for GraphQL errors
            if let errors = json?["errors"] as? [[String: Any]] {
                let errorMessages = errors.compactMap { $0["message"] as? String }
                print("❌ Hardcover API errors: \(errorMessages.joined(separator: ", "))")
                return false
            }

            let dataObj = json?["data"] as? [String: Any]

            if dataObj != nil {
                print("✅ Hardcover API: SUCCESS - Rate limit: 60 requests/minute")
                print("   Token expires: January 1st annually")
                return true
            } else {
                print("❌ No data object in response")
                return false
            }
        } else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error body"
            print("❌ Hardcover API returned \(httpResponse.statusCode)")
            print("   Response: \(errorBody)")
            return false
        }
    } catch {
        print("❌ Error: \(error.localizedDescription)")
        return false
    }
}

// Main execution
Task {
    print("==========================================")
    print("  ScreenSort API Verification Tests")
    print("==========================================")

    guard let keys = loadAPIKeys() else {
        print("\n❌ Failed to load API keys from Config/Secrets.xcconfig")
        exit(1)
    }

    print("✓ API keys loaded successfully")

    let youtubeResult = await testYouTubeAPI(apiKey: keys.youtubeKey)
    let tmdbResult = await testTMDbAPI(bearerToken: keys.tmdbToken)
    let hardcoverResult = await testHardcoverAPI(token: keys.hardcoverToken)

    print("\n==========================================")
    print("  Test Results Summary")
    print("==========================================")
    print("YouTube API:   \(youtubeResult ? "✅ PASS" : "❌ FAIL")")
    print("TMDb API:      \(tmdbResult ? "✅ PASS" : "❌ FAIL")")
    print("Hardcover API: \(hardcoverResult ? "✅ PASS" : "❌ FAIL")")
    print("==========================================")

    if youtubeResult && tmdbResult && hardcoverResult {
        print("\n✅ All API verification tests passed!")
        exit(0)
    } else {
        print("\n❌ One or more tests failed")
        exit(1)
    }
}

RunLoop.main.run()
