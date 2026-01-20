//
//  NetworkError.swift
//  ClaudeMeter
//
//  Created by Edd on 2025-11-14.
//

import Foundation

/// Errors that can occur during network operations
enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case authenticationFailed
    case rateLimitExceeded
    case httpError(statusCode: Int)
    case decodingFailed(underlyingError: Error)
    case networkUnavailable
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API endpoint URL"
        case .invalidResponse:
            return "Server returned invalid response"
        case .authenticationFailed:
            return "Session key is invalid or expired"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please wait before retrying."
        case .httpError(let code):
            return "Server error (status \(code))"
        case .decodingFailed:
            return "Failed to parse server response"
        case .networkUnavailable:
            return "No internet connection"
        case .timeout:
            return "Request timed out"
        }
    }
}
