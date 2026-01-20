//
//  NetworkServiceProtocol.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import Foundation

/// HTTP methods supported by the network service
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
}

/// Protocol for network operations
protocol NetworkServiceProtocol: Sendable {
    /// Perform a generic HTTP request
    func request<T: Decodable>(
        _ endpoint: String,
        method: HTTPMethod,
        sessionKey: String
    ) async throws -> T
}
