import Foundation
import CZUtils

@objc
open class HTTPRequestWorker: ConcurrentBlockOperation {
  public typealias Params = [AnyHashable: Any]
  public typealias ParamList = [AnyHashable]
  public typealias Headers = [String: String]

  /// The content-type for the request.
  public enum ContentType {
    case textPlain
    case json
    case formUrlencoded
  }

  private enum config {
    static let timeOutInterval: TimeInterval = 60
  }

  private enum Constant {
    static let kContentType = "Content-Type"
  }

  public typealias Success = (Data?) -> Void
  public typealias Failure = (Error) -> Void
  /// Progress closure: (currSize, totalSize, downloadURL)
  public typealias Progress = (Int64, Int64, URL) -> Void
  public typealias Cached = Success
  /// Decode closure: return type can't define as generic<T>, because URLSessionDataDelegate requires the conformance to be @objc compatible.
  public typealias DecodeClosure = (Data?) -> Any?

  /// - Note: Internal Only! For external usage, please refer to `Success` / `Cached`.
  /// Internal Success closure: (model, data).
  /// `model` is decoded with `decodeClosure` if `decodeClosure` isn't nil.
  public typealias InternalSuccess = (Any?, Data?) -> Void
  public typealias InternalCached = InternalSuccess

  internal var success: InternalSuccess?
  internal var failure: Failure?
  internal var progress: Progress?
  internal var cached: InternalCached?
  internal var decodeClosure: DecodeClosure?

  let url: URL
  private let shouldSerializeJson: Bool
  private let requestType: RequestType
  private let params: Params?
  private let headers: Headers?

  private var urlSession: URLSession?

  private static var urlSession: URLSession? = URLSession(
    configuration: CZHTTPManager.urlSessionConfiguration,
    delegate: nil,
    delegateQueue: nil)

  private(set) var dataTask: URLSessionDataTask?
  @ThreadSafe private var response: URLResponse?
  @ThreadSafe private var expectedSize: Int64 = 0
  @ThreadSafe private var receivedSize: Int64 = 0
  @ThreadSafe private var receivedData = Data()

  private let httpCache: CZHTTPCache?
  private var httpCacheKey: String {
    return CZHTTPCache.cacheKey(url: url, params: params)
  }

  required public init(_ requestType: RequestType,
                       url: URL,
                       params: Params? = nil,
                       headers: Headers? = nil,
                       shouldSerializeJson: Bool = true,
                       httpCache: CZHTTPCache? = nil,
                       decodeClosure: DecodeClosure? = nil,
                       success: InternalSuccess? = nil,
                       failure: Failure? = nil,
                       cached: InternalCached? = nil,
                       progress: Progress? = nil) {
    self.requestType = requestType
    self.url = url
    self.params = params
    self.headers = headers

    self.httpCache = httpCache
    self.shouldSerializeJson = shouldSerializeJson
    self.decodeClosure = decodeClosure
    self.progress = progress
    self.cached = cached
    self.success = success
    self.failure = failure
    super.init()

    self.props["url"] = url
    // Build urlSessionTask
    dataTask = buildUrlSessionTask()
  }

  open override func _execute() {
    // Fetch from cache
    if  requestType == .GET,
        let cached = cached,
        let cachedData = httpCache?.readData(forKey: httpCacheKey, shouldDeserializeJsonData: false) as? Data {
      decodeDataAndCallCompletion(data: cachedData, completion: cached)
    }

    // Fetch from network
    dataTask?.resume()
  }

  open override func cancel() {
    dataTask?.cancel()
    super.cancel()
  }

  open override func finish() {
    // Note:
    // Should invalidate URLSession after task completes, to avoid a retain cycle that causes leaks and crash.
    // Because URLSession retains strong reference to URLSessionDelegate.
    urlSession?.finishTasksAndInvalidate()
    super.finish()
  }

  /**
   Build urlSessionTask based on settings
   */
  private func buildUrlSessionTask() -> URLSessionDataTask? {
    urlSession = URLSession(configuration: CZHTTPManager.urlSessionConfiguration,
                            delegate: self,
                            delegateQueue: nil)

    let paramsString: String? = CZHTTPJsonSerializer.string(with: params)
    let url = requestType.hasSerializableUrl ? CZHTTPJsonSerializer.url(baseURL: self.url, params: params) : self.url
    let request = NSMutableURLRequest(url: url)
    request.httpMethod = requestType.stringValue

    if let headers = headers {
      for (key, value) in headers {
        assert(key != Constant.kContentType, "`\(Constant.kContentType)` should only be set with `.POST(contentType, data)`")
        request.setValue(value, forHTTPHeaderField: key)
      }
    }

    assert(urlSession != nil, "urlSession shouldn't be nil.")
    var dataTask: URLSessionDataTask? = nil
    switch requestType {
    case .GET, .PUT:
      dataTask = urlSession?.dataTask(with: request as URLRequest)

    case let .POST(contentType, data):
      // Set postData as input data if non nil.
      guard let postData = (data ?? paramsString?.data(using: .utf8)).assertIfNil else {
        return nil
      }
      let contentTypeValue: String = {
        switch contentType {
        case .textPlain:
          return "text/plain"
        case .json:
          return "application/json"
        case .formUrlencoded:
          return "application/x-www-form-urlencoded"
        }
      }()
      // Set the content-type of the request.
      request.setValue(contentTypeValue, forHTTPHeaderField: Constant.kContentType)
      // Set the content-type of the response.
      request.setValue("application/json", forHTTPHeaderField: "Accept")
      let contentLength = postData.count
      request.setValue("\(contentLength)", forHTTPHeaderField: "Content-Length")
      dataTask = urlSession?.uploadTask(with: request as URLRequest, from: postData)

    case .DELETE:
      dataTask = urlSession?.dataTask(with: request as URLRequest)

    case let .UPLOAD(fileName, data):
      do {
        let request = try Upload.buildRequest(
          url,
          params: params,
          fileName: fileName,
          data: data)
        dataTask = urlSession?.dataTask(with: request)
      } catch {
        dbgPrint("Failed to build upload request. Error - \(error.localizedDescription)")
      }
    default:
      assertionFailure("Unsupported request type.")
    }
    return dataTask
  }
}

// MARK: - URLSessionDataDelegate

extension HTTPRequestWorker: URLSessionDataDelegate {
  public func urlSession(_ session: URLSession,
                         dataTask: URLSessionDataTask,
                         didReceive response: URLResponse,
                         completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
    defer {
      self.response = response
      completionHandler(.allow)
      finish()
    }
    guard let response = (response as? HTTPURLResponse).assertIfNil else {
      return
    }
    expectedSize = response.expectedContentLength
  }

  public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    // receivedSize += Int64(data.count)
    // receivedData.append(data)
    _receivedSize.threadLock { (_receivedSize) -> Void in
      _receivedSize += Int64(data.count)
    }
    _receivedData.threadLock { (_receivedData) -> Void in
      _receivedData.append(data)
    }
    MainQueueScheduler.async { [weak self] in
      guard let `self` = self else {return}
      self.progress?(self.receivedSize, self.expectedSize, self.url)
    }
  }

  public func urlSession(_ session: URLSession,
                         task: URLSessionTask,
                         didCompleteWithError error: Error?) {
    defer { finish() }

    if true || !CZTestHelper.isInUnitTest {
      guard self.response == task.response else { return }

      guard error == nil,
            let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200 else {
        if error?.retrievedCode != NSURLErrorCancelled {
          // Failure completion
          var errorDescription = error?.localizedDescription ?? ""
          let responseString = "Response: \(String(describing: response))"
          errorDescription = responseString + "\n"
          if let receivedDict: Any = CZHTTPJsonSerializer.deserializedObject(with: receivedData)  {
            errorDescription += "\nReceivedData: \(receivedDict)"
          }
          let errorRes = error ?? CZNetError(errorDescription)
          dbgPrint("Failure of dataTask, error - \(errorRes)")
          failOnMainThreadIfNeeded(error: errorRes)
        }
        return
      }
    }

    // Success completion
    if cached != nil {
      httpCache?.saveData(receivedData, forKey: httpCacheKey)
    }

    decodeDataAndCallCompletion(data: self.receivedData, completion: self.success)
  }

}

// MARK: - URLSessionDelegate

extension HTTPRequestWorker: URLSessionDelegate {}

// MARK: - Private methods

private extension HTTPRequestWorker {
  func decodeDataAndCallCompletion(data metaData: Data,
                                   completion: InternalSuccess?) {
    var dataOrModel: Any? = metaData

    if self.decodeClosure != nil {
      // Decode data to model if decodeClosure isn't nil.
      dataOrModel = self.decodeClosure?(metaData)

      guard dataOrModel.assertIfNil != nil else {
        failOnMainThreadIfNeeded(error: CZNetError.parse)
        return
      }
    }

    MainQueueScheduler.async {
      completion?(dataOrModel, metaData)
    }
  }

  func failOnMainThreadIfNeeded(error: Error) {
    guard failure != nil else {
      return
    }
    MainQueueScheduler.async { [weak self] in
      self?.failure?(error)
    }
  }
}
