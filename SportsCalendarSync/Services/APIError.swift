import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case badResponse(status: Int)
    case decoding(Error)
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL."
        case .badResponse(let status): return "Bad response (HTTP \(status))."
        case .decoding(let err): return "Decoding failed: \(err.localizedDescription)"
        case .network(let err): return "Network error: \(err.localizedDescription)"
        }
    }
}
