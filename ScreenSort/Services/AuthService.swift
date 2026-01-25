import Foundation
import AuthenticationServices
import CryptoKit

class AuthService: NSObject, AuthServiceProtocol, ASWebAuthenticationPresentationContextProviding {

    private let keychainService: KeychainService
    private let clientId: String
    private let redirectUri = "com.screensort:/oauth2callback"

    // PKCE state
    private var codeVerifier: String?

    init(keychainService: KeychainService = KeychainService()) {
        self.keychainService = keychainService
        // Load client ID from bundle (set in xcconfig)
        self.clientId = Bundle.main.object(forInfoDictionaryKey: "YOUTUBE_CLIENT_ID") as? String ?? ""
        super.init()
    }

    var isAuthenticated: Bool {
        guard let tokens = try? keychainService.loadTokens() else { return false }
        // Has refresh token means we can always get new access token
        return !tokens.refreshToken.isEmpty
    }

    // MARK: - PKCE Helpers

    private func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Authentication

    func authenticate() async throws {
        codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier!)

        let scope = "https://www.googleapis.com/auth/youtube"
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "access_type", value: "offline"),  // Get refresh token
            URLQueryItem(name: "prompt", value: "consent")  // Force consent to get refresh token
        ]

        guard let authURL = components.url else {
            throw YouTubeError.notAuthenticated
        }

        let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "com.screensort"
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let callbackURL = callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: YouTubeError.notAuthenticated)
                }
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false

            DispatchQueue.main.async {
                session.start()
            }
        }

        // Extract authorization code
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw YouTubeError.notAuthenticated
        }

        // Exchange code for tokens
        try await exchangeCodeForTokens(code: code)
    }

    private func exchangeCodeForTokens(code: String) async throws {
        guard let verifier = codeVerifier else {
            throw YouTubeError.notAuthenticated
        }

        let url = URL(string: "https://oauth2.googleapis.com/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "client_id": clientId,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectUri
        ]

        request.httpBody = body.map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw YouTubeError.notAuthenticated
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

        try keychainService.saveTokens(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken ?? "",
            expiresIn: tokenResponse.expiresIn
        )

        codeVerifier = nil
    }

    // MARK: - Token Refresh

    func getValidAccessToken() async throws -> String {
        guard let tokens = try keychainService.loadTokens() else {
            throw YouTubeError.notAuthenticated
        }

        // If not expired, return current token
        if tokens.expiry > Date() {
            return tokens.accessToken
        }

        // Refresh the token
        return try await refreshAccessToken(refreshToken: tokens.refreshToken)
    }

    private func refreshAccessToken(refreshToken: String) async throws -> String {
        let url = URL(string: "https://oauth2.googleapis.com/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "client_id": clientId,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ]

        request.httpBody = body.map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw YouTubeError.tokenExpired
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 400 {
            // Refresh token expired - user must re-authenticate
            try? keychainService.clearAll()
            throw YouTubeError.tokenExpired
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw YouTubeError.tokenExpired
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

        // Save new access token (refresh token may not be returned)
        try keychainService.saveTokens(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken ?? refreshToken,
            expiresIn: tokenResponse.expiresIn
        )

        return tokenResponse.accessToken
    }

    // MARK: - Sign Out

    func signOut() throws {
        try keychainService.clearAll()
    }

    // MARK: - ASWebAuthenticationPresentationContextProviding

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
}

// MARK: - Token Response

private struct TokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}
