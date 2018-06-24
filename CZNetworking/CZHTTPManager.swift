//
//  CZHTTPManager.swift
//  CZNetworking
//
//  Created by Cheng Zhang on 1/9/16.
//  Copyright © 2016 Cheng Zhang. All rights reserved.
//

import UIKit

/**
 Asynchronous HTTP requests manager based on NSOperationQueue
 */
open class CZHTTPManager: NSObject {
    fileprivate var queue: OperationQueue
    public static var shared = CZHTTPManager()
    fileprivate(set) var httpCache: CZHTTPCache

    public override init() {
        queue = OperationQueue()
        queue.maxConcurrentOperationCount = 5
        httpCache = CZHTTPCache()
        super.init()
    }

    public func GET(_ urlStr: String,
                    parameters: CZHTTPRequester.Parameters? = nil,
                    headers: CZHTTPRequester.Headers? = nil,
                    success: @escaping CZHTTPRequester.Success,
                    failure: @escaping CZHTTPRequester.Failure,
                    cached: CZHTTPRequester.Cached? = nil,
                    progress: CZHTTPRequester.Progress? = nil) {
        startRequester(
            .GET,
            urlStr: urlStr,
            parameters: parameters,
            headers: headers,
            success: success,
            failure: failure,
            cached: cached,
            progress: progress)
    }

    public func POST(_ urlStr: String,
                     parameters: CZHTTPRequester.Parameters? = nil,
                     headers: CZHTTPRequester.Headers? = nil,
                     success: @escaping CZHTTPRequester.Success,
                     failure: @escaping CZHTTPRequester.Failure,
                     progress: CZHTTPRequester.Progress? = nil) {
        startRequester(
            .POST,
            urlStr: urlStr,
            parameters: parameters,
            headers: headers,
            success: success,
            failure: failure,
            progress: progress)
    }

    public func DELETE(_ urlStr: String,
                       parameters: CZHTTPRequester.Parameters? = nil,
                       headers: CZHTTPRequester.Headers? = nil,
                       success: @escaping CZHTTPRequester.Success,
                       failure: @escaping CZHTTPRequester.Failure) {
        startRequester(
            .DELETE,
            urlStr: urlStr,
            parameters: parameters,
            headers: headers,
            success: success,
            failure: failure)
    }
}

fileprivate extension CZHTTPManager {
    func startRequester(_ requestType: CZHTTPRequester.RequestType,
                        urlStr: String,
                        parameters: CZHTTPRequester.Parameters? = nil,
                        headers: CZHTTPRequester.Headers? = nil,
                        success: @escaping CZHTTPRequester.Success,
                        failure: @escaping CZHTTPRequester.Failure,
                        cached: CZHTTPRequester.Cached? = nil,
                        progress: CZHTTPRequester.Progress? = nil) {
        let op = BlockOperation {
            CZHTTPRequester(
                requestType,
                url: URL(string: urlStr)!,
                parameters: parameters,
                headers: headers,
                httpCache: self.httpCache,
                success: success,
                failure: failure,
                cached: cached,
                progress: progress).start()
        }
        queue.addOperation(op)
    }
}
