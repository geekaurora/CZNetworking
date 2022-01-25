import Foundation
import CZUtils

/**
 Asynchronous HTTP requests manager based on NSOperationQueue.
 
 - Note: It automatically cancels the previous task with the same URL.
 */
open class CZHTTPManager: NSObject {
  public static let shared = CZHTTPManager()
  
  public enum Config {
    public static var maxConcurrencies = 5
    public static var downloadQueueName = "CZHTTPManager.downloadQueue"
  }
  /// URL session configuration, that can be repaced with test stubing.
  public static var urlSessionConfiguration = URLSessionConfiguration.default
  public static var isUnderUnitTest = false
  
  let downloadQueue: OperationQueue
  let httpCache: CZHTTPCache

  public init(maxConcurrencies: Int = Config.maxConcurrencies) {
    downloadQueue = OperationQueue()
    downloadQueue.name = Config.downloadQueueName
    downloadQueue.maxConcurrentOperationCount = maxConcurrencies
    // *Updated.
    downloadQueue.qualityOfService = .userInitiated

    httpCache = CZHTTPCache()
    super.init()
  }
  
  public func maxConcurrencies(_ maxConcurrencies: Int) -> Self {
    downloadQueue.maxConcurrentOperationCount = maxConcurrencies
    return self
  }
  
  public func cancelTask(with url: URL?) {
    guard let url = url else { return }
    
    let cancelIfNeeded = { (operation: Operation) in
      if let operation = operation as? HTTPRequestWorker,
         operation.url == url {
        operation.cancel()
      }
    }
    downloadQueue.operations.forEach(cancelIfNeeded)
  }
  
  // MARK: - GET
  
  public func GET(_ urlStr: String,
                  headers: HTTPRequestWorker.Headers? = nil,
                  params: HTTPRequestWorker.Params? = nil,
                  shouldSerializeJson: Bool = true,
                  queuePriority: Operation.QueuePriority = .normal,
                  success: ((Data?) -> Void)? = nil,
                  failure: HTTPRequestWorker.Failure? = nil,
                  cached: ((Data?) -> Void)? = nil,
                  progress: HTTPRequestWorker.Progress? = nil) {
    _GET(urlStr,
         headers: headers,
         params: params,
         shouldSerializeJson: shouldSerializeJson,
         queuePriority: queuePriority,
         success: { (_: Data?, metaData) in
          success?(metaData)
         },
         failure: failure,
         cached: cached == nil ? nil : { (_, metaData) in
          cached?(metaData)
         },
         progress: progress)
  }
  
  // MARK: Codable
  
  /// Retrieves Codable model with specified paremeters `urlStr`/`params` etc.
  /// In `success` callback, it automatically decode json data to desired `Model` type if applicable.
  ///
  /// - Note: `Model` type can be inferred in `success` call site.
  ///
  /// - Parameters:
  ///   - dataKey: The key used to retrieve models array. e.g.  key of dictionary is "items".
  public func GETCodableModel<Model: Codable>(_ urlStr: String,
                                              headers: HTTPRequestWorker.Headers? = nil,
                                              params: HTTPRequestWorker.Params? = nil,
                                              dataKey: String? = nil,
                                              success: @escaping (Model, Data?) -> Void,
                                              failure: HTTPRequestWorker.Failure? = nil,
                                              cached: ((Model, Data?) -> Void)? = nil,
                                              progress: HTTPRequestWorker.Progress? = nil) {
    _GET(urlStr,
        headers: headers,
        params: params,
        decodeClosure: DataDecodeHelper.codableDecodeClosure(dataKey: dataKey, inferringModel: urlStr as? Model),
        success: success,
        failure: failure,
        cached: cached == nil ? nil : { (model, data) in
          cached?(model, data)
        },
        progress: progress)
  }
  
  /// Retrieves Codable models with specified paremeters `urlStr`/`params` etc.
  /// In `success` callback, it automatically decode json data to desired `Model` type if applicable.
  ///
  /// ### Note
  /// - `Data` in `success` callback is the original response data.
  /// - The reason to use `GETCodableModels` instead of `GETCodableModel` is to assert the exact failed decoding model.
  /// `Model` type can be inferred in `success` call site.
  ///
  /// - Parameters:
  ///   - dataKey: The key used to retrieve models array. e.g.  key of dictionary is "items".
  public func GETCodableModels<Model: Codable>(_ urlStr: String,
                                              headers: HTTPRequestWorker.Headers? = nil,
                                              params: HTTPRequestWorker.Params? = nil,
                                              dataKey: String? = nil,
                                              success: @escaping ([Model], Data?) -> Void,
                                              failure: HTTPRequestWorker.Failure? = nil,
                                              cached: (([Model], Data?) -> Void)? = nil,
                                              progress: HTTPRequestWorker.Progress? = nil) {
    // Calling `GETCodableModel()` will infer `[Model]` as Model type.
    GETCodableModel(urlStr,
                    headers: headers,
                    params: params,
                    dataKey: dataKey,
                    success: success,
                    failure: failure,
                    cached: cached,
                    progress: progress)
  }
  
  /// Get Codable models without `Data` in `success` closure.
  public func GETCodableModels<Model: Codable>(_ urlStr: String,
                                               headers: HTTPRequestWorker.Headers? = nil,
                                               params: HTTPRequestWorker.Params? = nil,
                                               dataKey: String? = nil,
                                               success: @escaping ([Model]) -> Void,
                                               failure: HTTPRequestWorker.Failure? = nil,
                                               cached: (([Model]) -> Void)? = nil,
                                               progress: HTTPRequestWorker.Progress? = nil) {
    GETCodableModels(
      urlStr,
      headers: headers,
      params: params,
      dataKey: dataKey,
      success: { (models, data) in
        success(models)
    },
      failure: failure,
      cached: cached == nil ? nil : { (models, data) in
        cached?(models)
      },
      progress: progress)
  }
  
  // MARK: CZDictionaryable
  
  public func GetOneModel<Model: CZDictionaryable>(_ urlStr: String,
                                                   params: HTTPRequestWorker.Params? = nil,
                                                   headers: HTTPRequestWorker.Headers? = nil,
                                                   dataKey: String? = nil,
                                                   success: @escaping (Model) -> Void,
                                                   failure: HTTPRequestWorker.Failure? = nil,
                                                   cached: ((Model) -> Void)? = nil,
                                                   progress: HTTPRequestWorker.Progress? = nil) {
    _GET(urlStr,
        headers: headers,
        params: params,
        decodeClosure: DataDecodeHelper.oneDictionaryableDecodeClosure(dataKey: dataKey, inferringModel: urlStr as? Model),
        success: { (model, data) in
          success(model)
        },
        failure: failure,
        cached: cached == nil ? nil : { (model, data) in
          cached?(model)
        },
        progress: progress)
  }
  
  public func GetManyModels<Model: CZDictionaryable>(_ urlStr: String,
                                                     params: HTTPRequestWorker.Params? = nil,
                                                     headers: HTTPRequestWorker.Headers? = nil,
                                                     dataKey: String? = nil,
                                                     success: @escaping ([Model]) -> Void,
                                                     failure: HTTPRequestWorker.Failure? = nil,
                                                     cached: (([Model]) -> Void)? = nil,
                                                     progress: HTTPRequestWorker.Progress? = nil) {
    _GET(urlStr,
        headers: headers,
        params: params,
        decodeClosure: DataDecodeHelper.manyDictionaryableDecodeClosure(dataKey: dataKey, inferringModel: urlStr as? Model),
        success: { (models, data) in
          success(models)
        },
        failure: failure,
        cached: cached == nil ? nil : { (models, data) in
          cached?(models)
        },
        progress: progress)
  }
  
  // MARK: - POST
  
  public func POST(_ urlStr: String,
                   contentType: HTTPRequestWorker.ContentType = .formUrlencoded,
                   headers: HTTPRequestWorker.Headers? = nil,
                   params: HTTPRequestWorker.Params? = nil,
                   data: Data? = nil,
                   success: HTTPRequestWorker.Success? = nil,
                   failure: HTTPRequestWorker.Failure? = nil,
                   progress: HTTPRequestWorker.Progress? = nil) {
    startOperation(
      .POST(contentType, data),
      urlStr: urlStr,
      headers: headers,
      params: params,
      success: { (_, data) in
        success?(data)
      },
      failure: failure,
      progress: progress)
  }
  
  // MARK: - DELETE
  
  public func DELETE(_ urlStr: String,
                     headers: HTTPRequestWorker.Headers? = nil,
                     params: HTTPRequestWorker.Params? = nil,
                     success: HTTPRequestWorker.Success? = nil,
                     failure: HTTPRequestWorker.Failure? = nil) {
    startOperation(
      .DELETE,
      urlStr: urlStr,
      headers: headers,
      params: params,
      success: { (_, data) in
        success?(data)
      },
      failure: failure)
  }
  
  // MARK: - UPLOAD
  
  public func UPLOAD(_ urlStr: String,
                     headers: HTTPRequestWorker.Headers? = nil,
                     params: HTTPRequestWorker.Params? = nil,
                     fileName: String? = nil,
                     data: Data,
                     success: HTTPRequestWorker.Success? = nil,
                     failure: HTTPRequestWorker.Failure? = nil,
                     progress: HTTPRequestWorker.Progress? = nil) {
    let fileName = fileName ?? UUID.generate()
    startOperation(
      .UPLOAD(fileName, data),
      urlStr: urlStr,
      headers: headers,
      params: params,
      success: { (model, data) in
        success?(data)
      },
      failure: failure,
      progress: progress)
  }
}

// MARK: - Private methods

private extension CZHTTPManager {
  
  func _GET<Model>(_ urlStr: String,
                           headers: HTTPRequestWorker.Headers? = nil,
                           params: HTTPRequestWorker.Params? = nil,
                           shouldSerializeJson: Bool = true,
                           queuePriority: Operation.QueuePriority = .normal,
                           decodeClosure: HTTPRequestWorker.DecodeClosure? = nil,
                           success: ((Model, Data?) -> Void)? = nil,
                           failure: HTTPRequestWorker.Failure? = nil,
                           cached: ((Model, Data?) -> Void)? = nil,
                           progress: HTTPRequestWorker.Progress? = nil) {
    startOperationGeneric(
      .GET,
      urlStr: urlStr,
      headers: headers,
      params: params,
      shouldSerializeJson: shouldSerializeJson,
      queuePriority: queuePriority,
      decodeClosure:decodeClosure,
      success: success,
      failure: failure,
      cached: cached,
      progress: progress)
  }
  
  func startOperation(_ requestType: HTTPRequestWorker.RequestType,
                      urlStr: String,
                      headers: HTTPRequestWorker.Headers? = nil,
                      params: HTTPRequestWorker.Params? = nil,
                      shouldSerializeJson: Bool = true,
                      queuePriority: Operation.QueuePriority = .normal,
                      decodeClosure: HTTPRequestWorker.DecodeClosure? = nil,
                      success: HTTPRequestWorker.InternalSuccess? = nil,
                      failure: HTTPRequestWorker.Failure? = nil,
                      cached: HTTPRequestWorker.InternalSuccess? = nil,
                      progress: HTTPRequestWorker.Progress? = nil) {
    guard let url = URL(string: urlStr).assertIfNil else {
      return
    }
    let reqestWorkerOperation = HTTPRequestWorker(
      requestType,
      url: url,
      params: params,
      headers: headers,
      shouldSerializeJson: shouldSerializeJson,
      httpCache: self.httpCache,
      decodeClosure:decodeClosure,
      success: success,
      failure: failure,
      cached: cached,
      progress: progress)
    reqestWorkerOperation.queuePriority = queuePriority
    downloadQueue.addOperation(reqestWorkerOperation)
  }
  
  func startOperationGeneric<Model>(_ requestType: HTTPRequestWorker.RequestType,
                                    urlStr: String,
                                    headers: HTTPRequestWorker.Headers? = nil,
                                    params: HTTPRequestWorker.Params? = nil,
                                    shouldSerializeJson: Bool = true,
                                    queuePriority: Operation.QueuePriority = .normal,
                                    decodeClosure: HTTPRequestWorker.DecodeClosure? = nil,
                                    success: ((Model, Data?) -> Void)? = nil,
                                    failure: HTTPRequestWorker.Failure? = nil,
                                    cached: ((Model, Data?) -> Void)? = nil,
                                    progress: HTTPRequestWorker.Progress? = nil) {
    typealias Completion = (Model, Data?) -> Void
    let completionHandler = { (completion: Completion?, model: Any?, data: Data?) in
      guard let model = (model as? Model).assertIfNil else {
        failure?(CZNetError.parse)
        return
      }
      completion?(model, data)
    }

    startOperation(
      requestType,
      urlStr: urlStr,
      headers: headers,
      params: params,
      shouldSerializeJson: shouldSerializeJson,
      queuePriority: queuePriority,
      decodeClosure:decodeClosure,
      success: { (model, data) in
        completionHandler(success, model, data)
      },
      failure: failure,
      cached: cached == nil ? nil : { (model, data) in
        completionHandler(cached, model, data)
      },
      progress: progress)
  }
  
}
