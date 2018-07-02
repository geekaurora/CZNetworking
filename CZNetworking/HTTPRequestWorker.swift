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

    public enum RequestType: String {
        case GET = "GET"
        case POST = "POST"
        case PUT = "PUT"
        case HEAD = "HEAD"
        case DELETE = "DELETE"
        case PATCH = "PATCH"
        case OPTIONS = "OPTIONS"
        case TRACE = "TRACE"
        case CONNECT = "CONNECT"
        case UNKNOWN = "UNKNOWN"

        var hasSerializableUrl: Bool {
            return !(self == .POST || self == .DELETE)
        }
    }
    /// Progress closure: (currSize, expectedSize, downloadURL)
    public typealias Progress = (Int64, Int64, URL) -> Void
    public typealias Success = (URLSessionDataTask?, Any?) -> Void
    public typealias Failure = (URLSessionDataTask?, Error) -> Void
    public typealias Cached = (URLSessionDataTask?, Any?) -> Void
    let url: URL
    fileprivate var success: Success?
    fileprivate var failure: Failure?
    fileprivate var progress: Progress?
    fileprivate var cached: Cached?
    fileprivate let shouldSerializeJson: Bool
    fileprivate let requestType: RequestType
    fileprivate let params: Params?
    fileprivate let headers: Headers?

    fileprivate var urlSession: URLSession?
    fileprivate var dataTask: URLSessionDataTask?
    fileprivate var response: URLResponse?
    fileprivate lazy var expectedSize: Int64 = 0
    fileprivate lazy var receivedSize: Int64 = 0
    fileprivate lazy var receivedData = Data()
    fileprivate var httpCache: CZHTTPCache?
    fileprivate var httpCacheKey: String {
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
        dataTask = buildUrlSessionTask()
        dataTask?.resume()
        return self
    }

    @discardableResult
    open func cancel()-> HTTPRequestWorker {
        dataTask?.cancel()
        return self
    }

    private func buildUrlSessionTask() -> URLSessionDataTask? {
        urlSession = URLSession(configuration: .default,
                                delegate: self,
                                delegateQueue: nil)
        let paramsString: String? = CZHTTPJsonSerializer.string(with: params)
        let url = requestType.hasSerializableUrl ? CZHTTPJsonSerializer.url(baseURL: self.url, params: params) : self.url
        let request = NSMutableURLRequest(url: url)
        request.httpMethod = requestType.rawValue

        if let headers = headers {
            for (key, value) in headers {
                request.addValue(value, forHTTPHeaderField: key)
            }
        }

        var dataTask: URLSessionDataTask? = nil
        switch requestType {
        case .GET, .PUT, .HEAD, .PATCH, .OPTIONS, .TRACE, .CONNECT, .UNKNOWN:
            dataTask = urlSession?.dataTask(with: request as URLRequest)

        case .POST:
            let postData = paramsString?.data(using: .utf8)
            request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            let contentLength = postData?.count ?? 0
            request.addValue("\(contentLength)", forHTTPHeaderField: "Content-Length")
            request.httpBody = postData
            dataTask = urlSession?.uploadTask(withStreamedRequest: request as URLRequest)

        case .DELETE:
            dataTask = urlSession?.dataTask(with: request as URLRequest)
        }
        return dataTask
    }
}

extension HTTPRequestWorker: URLSessionDataDelegate {
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Swift.Void) {
        defer {
            self.response = response
            completionHandler(.allow)
        }
        guard let response = response as? HTTPURLResponse else {
            assertionFailure("response isn't HTTPURLResponse.")
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
                let serializedObject = CZHTTPJsonSerializer.deserializedObject(with: receivedData) {
                // Return [AnyHashable: Any] if available
                if requestType == .GET {
                    httpCache?.saveData(serializedObject, forKey: httpCacheKey)
                }
                CZMainQueueScheduler.async { [weak self] in
                    self?.success?(task as? URLSessionDataTask, serializedObject)
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
        let responseString = "Response: \(response)"
        errorDescription = responseString + "\n"
        if let receivedDict = CZHTTPJsonSerializer.deserializedObject(with: receivedData)  {
            errorDescription += "\nReceivedData: \(receivedDict)"
        }
        let errorRes = CZNetError(errorDescription)
        print("Failure of dataTask, error - \(errorRes)")
        CZMainQueueScheduler.async { [weak self] in
            self?.failure?(nil, errorRes)
        }
    }
}

extension HTTPRequestWorker: URLSessionDelegate {}

fileprivate enum config {
    static let timeOutInterval: TimeInterval = 60
}


