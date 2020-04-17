//
//  CZHTTPManager.swift
//  CZNetworking
//
//  Created by Cheng Zhang on 1/9/16.
//  Copyright © 2016 Cheng Zhang. All rights reserved.
//

import Foundation
import CZUtils

/**
 Asynchronous HTTP requests manager based on NSOperationQueue
 */
open class CZHTTPManager: NSObject {
  public static let shared = CZHTTPManager()
  private let queue: OperationQueue
  private let httpCache: CZHTTPCache
  public enum Constant {
    public static let maxConcurrencies = 5
  }
  
  public init(maxConcurrencies: Int = Constant.maxConcurrencies) {
    queue = OperationQueue()
    queue.maxConcurrentOperationCount = maxConcurrencies
    httpCache = CZHTTPCache()
    super.init()
  }
  
  public func maxConcurrencies(_ maxConcurrencies: Int) -> Self {
    queue.maxConcurrentOperationCount = maxConcurrencies
    return self
  }
  
  // MARK: - GET
  
  public func GET(_ urlStr: String,
                  headers: HTTPRequestWorker.Headers? = nil,
                  params: HTTPRequestWorker.Params? = nil,
                  success: HTTPRequestWorker.Success? = nil,
                  failure: HTTPRequestWorker.Failure? = nil,
                  cached: HTTPRequestWorker.Cached? = nil,
                  progress: HTTPRequestWorker.Progress? = nil) {
    startOperation(
      .GET,
      urlStr: urlStr,
      headers: headers,
      params: params,
      success: success,
      failure: failure,
      cached: cached,
      progress: progress)
  }
  
  // MARK: Codable
    
  /// Retrieves Codable models with specified paremeters `urlStr`/`params` etc.
  /// In `success` callback, it automatically decode json data to desired `Model` type if applicable.
  ///
  /// - Note: `Model` type can be inferred in `success` call site.
  public func GETCodableModel<Model: Codable>(_ urlStr: String,
                                              headers: HTTPRequestWorker.Headers? = nil,
                                              params: HTTPRequestWorker.Params? = nil,
                                              dataKey: String? = nil,
                                              success: @escaping (Model) -> Void,
                                              failure: HTTPRequestWorker.Failure? = nil,
                                              cached: ((Model) -> Void)? = nil,
                                              progress: HTTPRequestWorker.Progress? = nil) {
    
    typealias Completion = (Model) -> Void
    let modelingHandler = { (completion: Completion?, task: URLSessionDataTask?, data: Data?) in
      let retrievedData: Data? = {
        // With given dataKey, retrieve corresponding field from dictionary
        if let dataKey = dataKey,
          let dict: [AnyHashable : Any] = CZHTTPJsonSerializer.deserializedObject(with: data),
          let dataDict = dict[dataKey]  {
          return CZHTTPJsonSerializer.jsonData(with: dataDict)
        }
        // Othewise, return directly as data should be decodable
        return data
      }()
      
      guard let model: Model = CodableHelper.decode(retrievedData).assertIfNil else {
        failure?(task, CZNetError.parse)
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

private extension CZHTTPManager {
  
  func startOperation(_ requestType: HTTPRequestWorker.RequestType,
                      urlStr: String,
                      headers: HTTPRequestWorker.Headers? = nil,
                      params: HTTPRequestWorker.Params? = nil,
                      success: HTTPRequestWorker.Success? = nil,
                      failure: HTTPRequestWorker.Failure? = nil,
                      cached: HTTPRequestWorker.Cached? = nil,
                      progress: HTTPRequestWorker.Progress? = nil) {
    let op = HTTPRequestWorker(
      requestType,
      url: URL(string: urlStr)!,
      params: params,
      headers: headers,
      httpCache: self.httpCache,
      success: success,
      failure: failure,
      cached: cached,
      progress: progress)
    queue.addOperation(op)
  }
  
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
