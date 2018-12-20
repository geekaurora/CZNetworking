//
//  HTTPRequestWorker.swift
//  CZNetworking
//
//  Created by Cheng Zhang on 1/3/16.
//  Copyright © 2016 Cheng Zhang. All rights reserved.
//

import Foundation
import CZUtils

@objc open class HTTPRequestWorker: NSObject {
    public typealias Params = [AnyHashable: Any]
    public typealias ParamList = [AnyHashable]
    public typealias Headers = [String: String]
    private enum config {
        static let timeOutInterval: TimeInterval = 60
    }

    public enum RequestType: Equatable {
        case GET
        case POST(ContentType, Data?)
        case PUT
        case DELETE
        case HEAD
        case PATCH
        case OPTIONS
        case TRACE
        case CONNECT
        case UNKNOWN

        var stringValue: String {
            switch self {
            case .GET: return "GET"
            case .POST: return "POST"
            case .PUT: return "PUT"
            case .DELETE: return "DELETE"
            default:
                assertionFailure("Unsupported type")
                return ""
            }
        }

        var hasSerializableUrl: Bool {
            switch self {
            case .DELETE, .POST:
                return false
            default:
                return true
            }
        }

        public static func ==(lhs: RequestType, rhs: RequestType) -> Bool {
            switch (lhs, rhs) {
            case (.GET, .GET):
                return true
            case (.POST, .POST):
                return true
            case (.PUT, .PUT):
                return true
            case (.DELETE, .DELETE):
                return true
            default:
                return false
            }
        }
    }

    public enum ContentType {
        case textPlain
        case formUrlencoded
    }

    /// Progress closure: (currSize, expectedSize, downloadURL)
    public typealias Progress = (Int64, Int64, URL) -> Void
    public typealias Success = (URLSessionDataTask?, Any?) -> Void
    public typealias Failure = (URLSessionDataTask?, Error) -> Void
    public typealias Cached = (URLSessionDataTask?, Any?) -> Void
    let url: URL
    private var success: Success?
    private var failure: Failure?
    private var progress: Progress?
    private var cached: Cached?
    private let shouldSerializeJson: Bool
    private let requestType: RequestType
    private let params: Params?
    private let headers: Headers?

    private var urlSession: URLSession?
    private var dataTask: URLSessionDataTask?
    private var response: URLResponse?
    private lazy var expectedSize: Int64 = 0
    private lazy var receivedSize: Int64 = 0
    private lazy var receivedData = Data()
    private var httpCache: CZHTTPCache?
    private var httpCacheKey: String {
        return CZHTTPCache.cacheKey(url: url, params: params)
    }

    required public init(_ requestType: RequestType,
                         url: URL,
                         params: Params? = nil,
                         headers: Headers? = nil,
                         shouldSerializeJson: Bool = true,
                         httpCache: CZHTTPCache? = nil,
                         success: @escaping Success,
                         failure: @escaping Failure,
                         cached: Cached? = nil,
                         progress: Progress? = nil) {
        self.requestType = requestType
        self.url = url
        self.params = params
        self.headers = headers
        self.httpCache = httpCache
        self.shouldSerializeJson = shouldSerializeJson
        self.progress = progress
        self.cached = cached
        self.success = success
        self.failure = failure
        super.init()

        // Build urlSessionTask
        dataTask = buildUrlSessionTask()
    }

    @discardableResult
    open func start() -> HTTPRequestWorker {
        // Fetch from cache
        if  requestType == .GET,
            let cached = cached,
            let cachedData = httpCache?.readData(forKey: httpCacheKey)  {
            CZMainQueueScheduler.async {[weak self] in
                cached(self?.dataTask, cachedData)
            }
        }

        // Fetch from network
        dataTask?.resume()
        return self
    }

    @discardableResult
    open func cancel()-> HTTPRequestWorker {
        dataTask?.cancel()
        return self
    }

    /**
     Build urlSessionTask based on settings
     */
    private func buildUrlSessionTask() -> URLSessionDataTask? {
        urlSession = URLSession(configuration: .default,
                                delegate: self,
                                delegateQueue: nil)
        let paramsString: String? = CZHTTPJsonSerializer.string(with: params)
        let url = requestType.hasSerializableUrl ? CZHTTPJsonSerializer.url(baseURL: self.url, params: params) : self.url
        let request = NSMutableURLRequest(url: url)
        request.httpMethod = requestType.stringValue

        if let headers = headers {
            for (key, value) in headers {
                request.addValue(value, forHTTPHeaderField: key)
            }
        }

        var dataTask: URLSessionDataTask? = nil
        switch requestType {
        case .GET, .PUT:
            dataTask = urlSession?.dataTask(with: request as URLRequest)

        case let .POST(contentType, data):
            // Set postData as input data if non-nil
            let postData = data ?? paramsString?.data(using: .utf8)
            let contentTypeValue: String = {
                switch contentType {
                case .formUrlencoded:
                    return "application/x-www-form-urlencoded"
                case .textPlain:
                    return "text/plain"
                }
            }()
            request.addValue(contentTypeValue, forHTTPHeaderField: "Content-Type")
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            let contentLength = postData?.count ?? 0
            request.addValue("\(contentLength)", forHTTPHeaderField: "Content-Length")
            request.httpBody = postData
            dataTask = urlSession?.uploadTask(withStreamedRequest: request as URLRequest)

        case .DELETE:
            dataTask = urlSession?.dataTask(with: request as URLRequest)
        default:
            assertionFailure("Unsupported request type.")
        }
        return dataTask
    }
}

extension HTTPRequestWorker: URLSessionDataDelegate {
    public func urlSession(_ session: URLSession,
                           dataTask: URLSessionDataTask,
                           didReceive response: URLResponse,
                           completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        defer {
            self.response = response
            completionHandler(.allow)
        }
        guard let response = (response as? HTTPURLResponse).assertIfNil else {
            return
        }
        expectedSize = response.expectedContentLength
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        receivedSize += Int64(data.count)
        receivedData.append(data)
        CZMainQueueScheduler.async { [weak self] in
            guard let `self` = self else {return}
            self.progress?(self.receivedSize, self.expectedSize, self.url)
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard self.response == task.response else {return}
        if error == nil,
            let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200 {
            if shouldSerializeJson,
                let deserializedObject = CZHTTPJsonSerializer.deserializedObject(with: receivedData) {
                // Return [AnyHashable: Any] if available
                if requestType == .GET {
                    httpCache?.saveData(deserializedObject, forKey: httpCacheKey)
                }
                CZMainQueueScheduler.async { [weak self] in
                    self?.success?(task as? URLSessionDataTask, deserializedObject)
                }
            } else {
                // Otherwise return `Data`
                CZMainQueueScheduler.sync { [weak self] in
                    guard let `self` = self else {return}
                    self.success?(task as? URLSessionDataTask, self.receivedData)
                }
            }
            return
        }
        var errorDescription = error?.localizedDescription ?? ""
        let responseString = "Response: \(String(describing: response))"
        errorDescription = responseString + "\n"
        if let receivedDict = CZHTTPJsonSerializer.deserializedObject(with: receivedData)  {
            errorDescription += "\nReceivedData: \(receivedDict)"
        }
        let errorRes = CZNetError(errorDescription)
        dbgPrint("Failure of dataTask, error - \(errorRes)")
        CZMainQueueScheduler.async { [weak self] in
            self?.failure?(nil, errorRes)
        }
    }
}

extension HTTPRequestWorker: URLSessionDelegate {}
