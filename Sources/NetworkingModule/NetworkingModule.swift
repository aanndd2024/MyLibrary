// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

public enum NetworkError: Error {
    case invalidURL
    case invalidResponse(statusCode: Int)
    case invalidData
    case decodingError(Error)
    case networkError(Error)

    public var localizedDescription: String {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse(let code): return "Invalid response (Status: \(code))"
        case .invalidData: return "Invalid data"
        case .decodingError(let error): return "Decoding error: \(error.localizedDescription)"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        }
    }
}

public struct Endpoint {
    public let path: String
    public let queryItems: [URLQueryItem]

    public init(path: String, queryItems: [URLQueryItem] = []) {
        self.path = path
        self.queryItems = queryItems
    }

    public var url: URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.coingecko.com"
        components.path = "/api/v3/" + path
        components.queryItems = queryItems
        return components.url
    }
}

public protocol NetworkServiceProtocol {
    func request<T: Decodable>(_ type: T.Type, endpoint: Endpoint) async -> Result<T, NetworkError>
}

public class NetworkService: NetworkServiceProtocol {
    private let urlSession: URLSession
    private let jsonDecoder: JSONDecoder

    public init(urlSession: URLSession = .shared, jsonDecoder: JSONDecoder = JSONDecoder()) {
        self.urlSession = urlSession
        self.jsonDecoder = jsonDecoder
    }

    public func request<T>(_ type: T.Type, endpoint: Endpoint) async -> Result<T, NetworkError> where T : Decodable {
        guard let url = endpoint.url else {
            return .failure(.invalidURL)
        }

        do {
            let (data, response) = try await urlSession.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.invalidResponse(statusCode: -1))
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                return .failure(.invalidResponse(statusCode: httpResponse.statusCode))
            }

            do {
                let decodedData = try jsonDecoder.decode(T.self, from: data)
                return .success(decodedData)
            } catch let error as DecodingError {
                return .failure(.decodingError(error))
            } catch {
                return .failure(.invalidData)
            }
        } catch {
            return .failure(.networkError(error))
        }
    }
}
