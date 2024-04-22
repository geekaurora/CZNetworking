import Foundation
import CZUtils

/** Generic network services for Codable models.

 ### Usage
 ```
 CodableService.shared.fetchModels(
 Constant.feedsEndPoint,
 params: Constant.fetchFeedsParams) { (feeds: [Feed]?, error) in
 guard let feeds = feeds else { return }
 self.feeds = feeds
 }
 ```
 */
public class CodableService {
  public static let shared = CodableService()
  public typealias Params = HTTPRequestWorker.Params

  // MARK: - Fetch

  /// Fetches Codable models.
  ///
  /// - Parameters:
  ///   - dataKey: The key used to retrieve models array. e.g.  key of dictionary is "items".
  ///   - completion: (models, data, error, isFromCache)
  public func fetchModels<Model: Codable>(_ endPoint: String,
                                          headers: HTTPRequestWorker.Headers? = nil,
                                          params: Params? = nil,
                                          dataKey: String? = nil,
                                          shouldUseCache: Bool = true,
                                          completion: @escaping ([Model]?, Data?, Error?, Bool) -> Void) {
    let innerCompletion = { (feeds: [Model], data: Data?) in
      completion(feeds, data, nil, false)
    }
    let cachedCompletion = !shouldUseCache ? nil : { (feeds: [Model], data: Data?) in
      completion(feeds, data, nil, true)
    }

    CZHTTPManager.shared.GETCodableModels(
      endPoint,
      headers: headers,
      params: params,
      dataKey: dataKey,
      success: innerCompletion,
      failure: { (error) in
        assertionFailure("\(#function) - failed to fetch models. Error - \(error). \nendPoint = \(endPoint)")
        completion(nil, nil, error, false)
      }, cached: cachedCompletion)
  }

  /// Fetches Codable models without `Data` in `success` closure.
  ///
  ///   - completion: (models, error, isFromCache)
  public func fetchModels<Model: Codable>(_ endPoint: String,
                                          headers: HTTPRequestWorker.Headers? = nil,
                                          params: Params? = nil,
                                          dataKey: String? = nil,
                                          shouldUseCache: Bool = true,
                                          completion: @escaping ([Model]?, Error?, Bool) -> Void) {
    fetchModels(
      endPoint,
      headers: headers,
      params: params,
      dataKey: dataKey,
      shouldUseCache: shouldUseCache,
      completion: { (models: [Model]?, data: Data?, error: Error?, isFromCache: Bool) in
        completion(models, error, isFromCache)
      })
  }

}
