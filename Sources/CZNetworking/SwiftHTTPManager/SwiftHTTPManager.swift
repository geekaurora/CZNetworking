import Foundation
import CZUtils

public enum HTTPClientError: Error {
  case invalidRequest
  case invalidResponse
  case custom(status: String, message: String)
  case unknown
}

/// Swifty concurrent HTTP requests manager supporting async / await.
public class SwiftHTTPManager {
  public static let shared = SwiftHTTPManager()

  // MARK: Fetch data

  /// Fetches the data with the `urlString`.
  ///
  /// - Parameter urlString: The urlString for the request.
  public func fetchData(urlString: String) async throws -> Data {
    let request = try self.request(for: urlString)
    return try await fetchData(request: request)
  }

  /// Fetches the data with the `request`.
  ///
  /// - Parameter request: The request to fetch.
  public func fetchData(request: URLRequest) async throws -> Data {
    let (data, _) = try await URLSession.shared.data(for: request)
    return data
  }

  // MARK: Fetch decodable model

  /// Fetches the decodable model with the `urlString`.
  ///
  /// - Parameter urlString: The urlString for the request.
  public func fetchDecodableModel<Model: Decodable>(
    urlString: String
  ) async throws -> Model {
    return try await fetchDecodableModel(
      urlString: urlString,
      dataFieldName: nil)
  }

  /// Fetches the decodable model with the `urlString` and `dataFieldName`.
  ///
  /// - Parameters:
  ///   - urlString: The urlString for the request.
  ///   - dataFieldName: The data field name of the response dictionary.
  public func fetchDecodableModel<Model: Decodable>(
    urlString: String,
    dataFieldName: String?
  ) async throws -> Model {
    let request = try self.request(for: urlString)
    return try await fetchDecodableModel(request: request, dataFieldName: dataFieldName)
  }

  /// Fetches the decodable model with the `request`.
  ///
  /// - Parameter request: The request to fetch.
  public func fetchDecodableModel<Model: Decodable>(
    request: URLRequest
  ) async throws -> Model {
    return try await fetchDecodableModel(
      request: request,
      dataFieldName: nil)
  }

  /// Fetches the decodable model with the `request` and `dataFieldName`.
  ///
  /// - Parameters:
  ///   - request: The request to fetch.
  ///   - dataFieldName: The data field name of the response dictionary.
  public func fetchDecodableModel<Model: Decodable>(
    request: URLRequest,
    dataFieldName: String?
  ) async throws -> Model {
    let data = try await fetchData(request: request)

    // Decode the `modelData` to the corresponding decodable `Model`.
    guard let modelData = try? self.extractDataIfNeeded(from: data, dataFieldName: dataFieldName),
      let model = try? JSONDecoder().decode(Model?.self, from: modelData)
    else {
      throw HTTPClientError.invalidResponse
    }
    return model
  }

  // MARK: - Private

  /// Returns an URLRequest for `urlString`.
  private func request(for urlString: String) throws -> URLRequest {
    guard let url = URL(string: urlString) else {
      throw HTTPClientError.invalidRequest
    }
    return URLRequest(url: url)
  }

  // Extracts the data from the `dataFieldName` of the `responseData` if applicable.
  func extractDataIfNeeded(
    from responseData: Data,
    dataFieldName: String?
  ) throws -> Data {
    guard let dataFieldName = dataFieldName else {
      return responseData
    }
    guard
      let dict = try? JSONSerialization.jsonObject(with: responseData, options: [])
        as? [String: Any],
      let object = dict[dataFieldName],
      JSONSerialization.isValidJSONObject(object),
      let dataForField = try? JSONSerialization.data(withJSONObject: object)
    else {
      throw HTTPClientError.invalidResponse
    }
    return dataForField
  }
}
