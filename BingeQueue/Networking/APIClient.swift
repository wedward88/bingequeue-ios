import Foundation

enum APIError: LocalizedError, Equatable {
    case invalidURL
    case unauthorized
    case http(status: Int, message: String)
    case decoding(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid request URL."
        case .unauthorized:
            return "Your session expired. Please sign in again."
        case .http(let status, let message):
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Server error (\(status))." : trimmed
        case .decoding(let message):
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty
                ? "Failed to read server response."
                : "Failed to read server response: \(trimmed)"
        case .transport(let message):
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty
                || trimmed.localizedCaseInsensitiveContains("cancel")
            {
                return "Could not reach the BingeQueue server."
            }
            if trimmed.localizedCaseInsensitiveContains("connect")
                || trimmed.localizedCaseInsensitiveContains("offline")
                || trimmed.localizedCaseInsensitiveContains("network")
            {
                return "Could not reach the BingeQueue server."
            }
            return trimmed
        }
    }
}

enum UserFacingError {
    static func message(from error: Error) -> String? {
        if error is CancellationError {
            return nil
        }
        if let urlError = error as? URLError, urlError.code == .cancelled {
            return nil
        }
        let raw = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Something went wrong." : trimmed
    }
}

protocol APIClientProtocol: Sendable {
    func request<T: Decodable>(
        _ method: String,
        path: String,
        query: [URLQueryItem],
        body: Data?,
        authorized: Bool
    ) async throws -> T
}

final class APIClient: APIClientProtocol, @unchecked Sendable {
    static let shared = APIClient()

    private let session: URLSession
    private let baseURL: URL
    var onUnauthorized: (() -> Void)?

    init(baseURL: URL = AppConfig.apiBaseURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func request<T: Decodable>(
        _ method: String,
        path: String,
        query: [URLQueryItem] = [],
        body: Data? = nil,
        authorized: Bool = true
    ) async throws -> T {
        var url = baseURL
        for segment in path.split(separator: "/") where !segment.isEmpty {
            url = url.appendingPathComponent(String(segment))
        }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        if !query.isEmpty {
            components.queryItems = query
        }
        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        if authorized, let token = KeychainStore.loadToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            throw APIError.transport(
                message.isEmpty
                    ? "Could not reach the BingeQueue server."
                    : message
            )
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.transport("Invalid response.")
        }

        if http.statusCode == 401 {
            // Only treat as a session expiry for authenticated requests. Login
            // failures (e.g. audience mismatch) must surface their API message.
            if authorized {
                await MainActor.run {
                    onUnauthorized?()
                }
                throw APIError.unauthorized
            }
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data),
               !apiError.error.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                throw APIError.http(status: 401, message: apiError.error)
            }
            throw APIError.http(status: 401, message: "Unauthorized.")
        }

        guard (200..<300).contains(http.statusCode) else {
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data),
               !apiError.error.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                throw APIError.http(status: http.statusCode, message: apiError.error)
            }
            let body = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw APIError.http(
                status: http.statusCode,
                message: body.isEmpty ? "Server error (\(http.statusCode))." : body
            )
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }
}

extension APIClient {
    func exchangeGoogleToken(_ idToken: String) async throws -> MobileAuthResponse {
        let body = try JSONEncoder().encode(["idToken": idToken])
        return try await request(
            "POST",
            path: "api/auth/mobile",
            body: body,
            authorized: false
        )
    }

    func fetchSubscriptions() async throws -> [Subscription] {
        let response: SubscriptionsResponse = try await request("GET", path: "api/subscriptions")
        return response.subscriptions
    }

    func createSubscription(streamingProviderId: Int, cost: String?) async throws -> Subscription {
        var payload: [String: Any] = ["streamingProviderId": streamingProviderId]
        if let cost { payload["cost"] = cost }
        let body = try JSONSerialization.data(withJSONObject: payload)
        let response: SubscriptionResponse = try await request(
            "POST",
            path: "api/subscriptions",
            body: body
        )
        return response.subscription
    }

    func updateSubscription(id: Int, streamingProviderId: Int, cost: String?) async throws -> Subscription {
        var payload: [String: Any] = ["streamingProviderId": streamingProviderId]
        if let cost { payload["cost"] = cost }
        let body = try JSONSerialization.data(withJSONObject: payload)
        let response: SubscriptionResponse = try await request(
            "PATCH",
            path: "api/subscriptions/\(id)",
            body: body
        )
        return response.subscription
    }

    func deleteSubscription(id: Int) async throws {
        let _: SubscriptionResponse = try await request("DELETE", path: "api/subscriptions/\(id)")
    }

    func fetchProviders(query: String? = nil) async throws -> [StreamingProvider] {
        var items: [URLQueryItem] = []
        if let query, !query.isEmpty {
            items.append(URLQueryItem(name: "q", value: query))
        }
        let response: ProvidersResponse = try await request(
            "GET",
            path: "api/providers",
            query: items,
            authorized: false
        )
        return response.providers
    }

    func searchTitles(query: String, mediaType: MediaTypeFilter) async throws -> [SearchResult] {
        let response: SearchResponse = try await request(
            "GET",
            path: "api/search",
            query: [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "mediaType", value: mediaType.rawValue),
            ],
            authorized: false
        )
        return response.results
    }

    func discoverByProvider(providerId: Int, mediaType: MediaTypeFilter) async throws -> [SearchResult] {
        let response: SearchResponse = try await request(
            "GET",
            path: "api/search",
            query: [
                URLQueryItem(name: "providerId", value: String(providerId)),
                URLQueryItem(name: "mediaType", value: mediaType.rawValue),
            ],
            authorized: false
        )
        return response.results
    }

    func fetchTitleProviders(type: String, id: Int) async throws -> [TitleWatchProvider] {
        let response: TitleProvidersResponse = try await request(
            "GET",
            path: "api/titles/\(type)/\(id)/providers",
            authorized: false
        )
        return Array(response.providers.values).sorted { $0.providerName < $1.providerName }
    }

    func fetchWatchList() async throws -> [WatchListItem] {
        let response: WatchListResponse = try await request("GET", path: "api/watch-list")
        return response.items
    }

    func addToWatchList(_ result: SearchResult) async throws -> WatchListItem {
        let payload: [String: Any?] = [
            "id": result.mediaId,
            "mediaId": result.mediaId,
            "mediaType": result.mediaType,
            "originalTitle": result.originalTitle,
            "originalName": result.originalName,
            "posterPath": result.posterPath ?? "",
            "overview": result.overview ?? "",
            "streamingProviders": [],
        ]
        let body = try JSONSerialization.data(withJSONObject: payload.compactMapValues { $0 })
        let response: WatchListItemResponse = try await request(
            "POST",
            path: "api/watch-list",
            body: body
        )
        return response.item
    }

    func removeFromWatchList(id: Int) async throws -> [WatchListItem] {
        let response: WatchListResponse = try await request(
            "DELETE",
            path: "api/watch-list/\(id)"
        )
        return response.items
    }

    func reorderWatchList(orderedItemIds: [Int]) async throws {
        let body = try JSONEncoder().encode(["orderedItemIds": orderedItemIds])
        let _: ReorderResponse = try await request(
            "PUT",
            path: "api/watch-list/reorder",
            body: body
        )
    }
}
