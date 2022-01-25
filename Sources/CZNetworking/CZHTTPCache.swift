import Foundation
import CZUtils

/// Thread safe local cache for HTTP response.
open class CZHTTPCache: NSObject {
  public static let shared = CZHTTPCache()
  
  typealias ClearCacheCompletion = (Bool, Error?) -> Void
  
  private let ioQueue: DispatchQueue
    
  override init() {
    ioQueue = DispatchQueue(
      label: "com.czhttpCache.ioQueue",
      qos: .default,
      attributes: .concurrent,
      autoreleaseFrequency: .inherit,
      target: nil)
    super.init()
  }
  
  private let folder: URL = {
    var documentPath = try! FileManager.default.url(for:.documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
    let cacheFolder = documentPath.appendingPathComponent("CZHTTPCache")
    CZFileHelper.createDirectoryIfNeeded(at: cacheFolder)
    return cacheFolder
  }()
  
  static func cacheKey(url: URL, params: [AnyHashable: Any]?) -> String {
    return CZHTTPJsonSerializer.url(baseURL: url, params: params).absoluteString
  }
  
  /// Save data to the cache - supports to save NSData and JSON object.
  ///
  /// - Note: `data` can be NSData or JSON object. If it's JSON object, will be serialized automatically/
  ///
  /// - Parameters:
  ///   - data: NSData or JSONObject to be saved.
  ///   - key: the key for `data`.
  public func saveData(_ input: Any, forKey key: String) {
    ioQueue.async(flags: .barrier) { [weak self] in
      guard let `self` = self else { return }
      
      let url = self.fileURL(forKey: key)
      guard let data = (input as? Data)
              ?? CZHTTPJsonSerializer.jsonData(with: input).assertIfNil else {
        return
      }
      let success = (data as NSData).write(to: url, atomically: true)
      assert(success, "\(#function) - failed to write file. key = \(key)")
    }
  }
  
  /// Read data from the cache - supports NSData and JSON object.
  ///
  /// - Note: If saved data is JSON object, will be deserialized automatically.
  ///
  /// - Parameters:
  ///   - key: the key for `data`.
  ///   - shouldDeserializeJsonData: indicates whether deserialize Data to JsonObject automatically.
  public func readData(forKey key: String,
                       shouldDeserializeJsonData: Bool = true) -> Any? {
    return ioQueue.sync { [weak self] () -> Any? in
      guard let `self` = self else { return nil }
      
      let url = self.fileURL(forKey: key)
      if let dict = NSDictionary(contentsOf: url) {
        return dict
      }
      if let array = NSArray(contentsOf: url) {
        return array
      }
      do {
        let data = try Data(contentsOf: url)
        if shouldDeserializeJsonData,
           let jsonObject: Any = CZHTTPJsonSerializer.deserializedObject(with: data) {
          return jsonObject
        }
        return data
      } catch {
        dbgPrint("Failed to read data. Error - \(error.localizedDescription)")
      }
      return nil
    }
  }
  
  public func removeData(key: String) {
    ioQueue.async(flags: .barrier) { [weak self] in
      guard let `self` = self else { return }
      let path = self.fileURL(forKey: key)
      CZFileHelper.removeFile(path)
    }
  }
  
  /// Force to clear all disk cache.
  func clearCache(shouldAsync: Bool = false,
                  completion: ClearCacheCompletion? = nil) {
    let execute = {
      // Delete the cache directory.
      CZFileHelper.removeDirectory(url: self.folder, createDirectoryAfterDeletion: true)
      completion?(true, nil)
    }
    
    if (shouldAsync) {
      ioQueue.async(execute: execute)
    } else {
      ioQueue.sync(execute: execute)
    }
  }
}

private extension CZHTTPCache {
  func fileURL(forKey key: String) -> URL {
    return folder.appendingPathComponent(key.MD5)
  }
}

protocol FileWritable {
  func write(toFile: String, atomically: Bool) -> Bool
}



