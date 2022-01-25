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
    public static var decodeQueueName = "CZHTTPManager.decodeQueue"
  }
  /// URL session configuration, that can be repaced with test stubing.
  public static var urlSessionConfiguration = URLSessionConfiguration.default
  public static var isUnderUnitTest = false
  
  let downloadQueue: OperationQueue
  let decodeQueue: OperationQueue
  let httpCache: CZHTTPCache

  public init(maxConcurrencies: Int = Config.maxConcurrencies) {
    downloadQueue = OperationQueue()
    downloadQueue.name = Config.downloadQueueName
    downloadQueue.maxConcurrentOperationCount = maxConcurrencies
    // *Updated.
    downloadQueue.qualityOfService = .userInitiated

    decodeQueue = OperationQueue()
    decodeQueue.name = Config.decodeQueueName
    decodeQueue.maxConcurrentOperationCount = maxConcurrencies
    decodeQueue.qualityOfService = .userInitiated
    
    httpCache = CZHTTPCache()
    super.init()
  }
  
  public func maxConcurrencies(_ maxConcurrencies: Int) -> Self {
    downloadQueue.maxConcurrentOperationCount = maxConcurrencies
    decodeQueue.maxConcurrentOperationCount = maxConcurrencies
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
                  success: ((URLSessionDataTask?, Data?) -> Void)? = nil,
                  failure: HTTPRequestWorker.Failure? = nil,
                  cached: ((URLSessionDataTask?, Data?) -> Void)? = nil,
                  progress: HTTPRequestWorker.Progress? = nil) {
    let cachedClosure: HTTPRequestWorker.Cached? = {
      guard let cached = cached else { return nil }
      return { (task, data, originalData) in
        cached(task, originalData)
      }
    }()
    
    _GET(urlStr,
         headers: headers,
         params: params,
         shouldSerializeJson: shouldSerializeJson,
         queuePriority: queuePriority,
         success: { (task, data, _) in
          success?(task, data as? Data)
         },
         failure: failure,
         cached: cachedClosure,
         progress: progress)
  }
  
  private func _GET(_ urlStr: String,
                  headers: HTTPRequestWorker.Headers? = nil,
                  params: HTTPRequestWorker.Params? = nil,
                  shouldSerializeJson: Bool = true,
                  queuePriority: Operation.QueuePriority = .normal,
                  decodeClosure: HTTPRequestWorker.DecodeClosure? = nil,
                  success: HTTPRequestWorker.Success? = nil,
                  failure: HTTPRequestWorker.Failure? = nil,
                  cached: HTTPRequestWorker.Cached? = nil,
                  progress: HTTPRequestWorker.Progress? = nil) {        
    startOperation(
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
    typealias Completion = (Model, Data?) -> Void
    let completionHandler = { (completion: Completion?, task: URLSessionDataTask?, model: Any?, data: Data?) in
      guard let model = (model as? Model).assertIfNil else {
        failure?(nil, CZNetError.parse)
        return
      }
      completion?(model, data)
    }
    
    let cachedClosure: ((URLSessionDataTask?, Any?, Data?) -> Void)? = {
      guard let cached = cached else { return nil }
      return { (task, model, data) in
        completionHandler(cached, task, model, data)
      }
    }()
        
    _GET(urlStr,
        headers: headers,
        params: params,
        decodeClosure: DataDecodeHelper.codableDecodeClosure(dataKey: dataKey, inferringModel: urlStr as? Model),
        success: { (task, model, data) in
          completionHandler(success, task, model, data)
    },
        failure: failure,
        cached: cachedClosure,
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
    let cachedClosure: (([Model], Data?) -> Void)? = {
      guard let cached = cached else { return nil }
      return { (models, data) in
        cached(models)
      }
    }()
    
    GETCodableModels(
      urlStr,
      headers: headers,
      params: params,
      dataKey: dataKey,
      success: { (models, data) in
        success(models)
    },
      failure: failure,
      cached: cachedClosure,
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
    
    typealias Completion = (Model) -> Void
    let modelingHandler = { (completion: (Completion)?, task: URLSessionDataTask?, data: Any?) in
      guard let data = data as? Data,
        let receivedObject: Any = CZHTTPJsonSerializer.deserializedObject(with: data) else {
          assertionFailure("Failed to deserialize data to object.")
          return
      }
      guard let model: Model = self.model(with: receivedObject, dataKey: dataKey).assertIfNil else {
        failure?(nil, CZNetError.returnType)
        return
      }
      completion?(model)
    }
    
    GET(urlStr,
        headers: headers,
        params: params,
        success: { (task, data) in
          modelingHandler(success, task, data)
    },
        failure: failure,
        cached: { (task, data) in
          modelingHandler(cached, task, data)
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
    
    typealias Completion = ([Model]) -> Void
    let modelingHandler = { (completion: Completion?, task: URLSessionDataTask?, data: Any?) in
      guard let data = data as? Data,
        let receivedObject: Any = CZHTTPJsonSerializer.deserializedObject(with: data) else {
          assertionFailure("Failed to deserialize data to object.")
          return
      }
      guard let models: [Model] = self.models(with: receivedObject, dataKey: dataKey).assertIfNil else {
        failure?(nil, CZNetError.returnType)
        return
      }
      completion?(models)
    }
    
    GET(urlStr,
        headers: headers,
        params: params,
        success: { (task, data) in
          modelingHandler(success, task, data)
    },
        failure: failure,
        cached: { (task, data) in
          modelingHandler(cached, task, data)
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
      success: success,
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
      success: success,
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
      success: success,
      failure: failure,
      progress: progress)
  }
}

// MARK: - Utils

public extension CZHTTPManager {
  
  func model<Model: CZDictionaryable>(with object: Any, dataKey: String? = nil) -> Model? {
    guard let dict: CZDictionary = {
      if let dataKey = dataKey {
        return (object as? CZDictionary)?[dataKey] as? CZDictionary
      } else {
        return object as? CZDictionary
      }
      }() else {
        return nil
    }
    return Model(dictionary: dict)
  }
  
  func models<Model: CZDictionaryable>(with object: Any, dataKey: String? = nil) -> [Model]? {
    let dicts: [CZDictionary]? = {
      if let dataKey = dataKey {
        return (object as? CZDictionary)?[dataKey] as? [CZDictionary]
      } else {
        return object as? [CZDictionary]
      }
    }()
    return dicts?.compactMap { Model(dictionary: $0) }
  }
  
}

private extension CZHTTPManager {
  
  func startOperation(_ requestType: HTTPRequestWorker.RequestType,
                      urlStr: String,
                      headers: HTTPRequestWorker.Headers? = nil,
                      params: HTTPRequestWorker.Params? = nil,
                      shouldSerializeJson: Bool = true,
                      queuePriority: Operation.QueuePriority = .normal,
                      decodeClosure: HTTPRequestWorker.DecodeClosure? = nil,
                      success: HTTPRequestWorker.Success? = nil,
                      failure: HTTPRequestWorker.Failure? = nil,
                      cached: HTTPRequestWorker.Cached? = nil,
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
                                    success: ((URLSessionDataTask?, Model, Data?) -> Void)? = nil,
                                    failure: HTTPRequestWorker.Failure? = nil,
                                    cached: ((URLSessionDataTask?, Model, Data?) -> Void)? = nil,
                                    progress: HTTPRequestWorker.Progress? = nil) {
    typealias Completion = (URLSessionDataTask?, Model, Data?) -> Void
    let completionHandler = { (completion: Completion?, task: URLSessionDataTask?, model: Any?, data: Data?) in
      guard let model = (model as? Model).assertIfNil else {
        failure?(nil, CZNetError.parse)
        return
      }
      completion?(task, model, data)
    }
    
    let cachedClosure: ((URLSessionDataTask?, Any?, Data?) -> Void)? = {
      guard let cached = cached else { return nil }
      return { (task, model, data) in
        completionHandler(cached, task, model, data)
      }
    }()

    startOperation(
      requestType,
      urlStr: urlStr,
      headers: headers,
      params: params,
      shouldSerializeJson: shouldSerializeJson,
      queuePriority: queuePriority,
      decodeClosure:decodeClosure,
      success: { (task, model, data) in
        completionHandler(success, task, model, data)
      },
      failure: failure,
      cached: cachedClosure,
      progress: progress)
  }
  
}
