//
//  NetworkService.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import Foundation
import os

/// Actor-isolated network service using URLSession
actor NetworkService: NetworkServiceProtocol {
    private static let logger = Logger(subsystem: "com.claudemeter", category: "NetworkService")
    private let session: URLSession

    init(configuration: URLSessionConfiguration = .default) {
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: configuration)
    }

    /// Perform a generic HTTP request
    func request<T: Decodable>(
        _ endpoint: String,
        method: HTTPMethod = .get,
        sessionKey: String
    ) async throws -> T {
        // Validate HTTPS
        guard endpoint.hasPrefix("https://") else {
            throw NetworkError.invalidURL
        }

        guard let url = URL(string: endpoint) else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue

        // Set proper headers to avoid Cloudflare bot detection
        request.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("https://claude.ai", forHTTPHeaderField: "Referer")
        request.setValue("claude.ai", forHTTPHeaderField: "Origin")
        request.setValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
        request.setValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
        request.setValue("empty", forHTTPHeaderField: "Sec-Fetch-Dest")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        // Handle HTTP status codes
        guard (200...299).contains(httpResponse.statusCode) else {
            let responseBody = String(data: data, encoding: .utf8) ?? "<unable to decode>"
            Self.logger.error("HTTP \(httpResponse.statusCode) from \(endpoint): \(responseBody)")

            if httpResponse.statusCode == 401 {
                throw NetworkError.authenticationFailed
            }
            if httpResponse.statusCode == 429 {
                throw NetworkError.rateLimitExceeded
            }
            throw NetworkError.httpError(statusCode: httpResponse.statusCode)
        }

        // Decode response
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let result = try decoder.decode(T.self, from: data)
            return result
        } catch {
            let responseBody = String(data: data, encoding: .utf8) ?? "<unable to decode>"
            Self.logger.error("Failed to decode response from \(endpoint): \(error.localizedDescription)\nResponse: \(responseBody)")
            throw NetworkError.decodingFailed(underlyingError: error)
        }
    }
}
