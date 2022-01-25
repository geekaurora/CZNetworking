import Foundation
import CZUtils

class DataDecodeHelper {
  
  /// Returns  decodeClosure for Codable Model.
  ///
  /// - Parameters:
  ///   - dataKey: The dataKey to retrive value from dictionary. If nil, parse the complete dictionary.
  ///   - inferringModel: A workaround to pass in `Model` type to method signature.
  static func codableDecodeClosure<Model: Codable>(dataKey: String?,
                                                   inferringModel: Model? = nil) -> HTTPRequestWorker.DecodeClosure {
    let decodeClosure: HTTPRequestWorker.DecodeClosure = { (data) in
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
        return nil
      }
      return model
    }
    
    return decodeClosure
  }
  
  /// Returns  decodeClosure for one CZDictionaryable Model.
  ///
  /// - Parameters:
  ///   - dataKey: The dataKey to retrive value from dictionary. If nil, parse the complete dictionary.
  ///   - inferringModel: A workaround to pass in `Model` type to method signature.
  static func oneDictionaryableDecodeClosure<Model: CZDictionaryable>(dataKey: String?,
                                                   inferringModel: Model? = nil) -> HTTPRequestWorker.DecodeClosure {

    let decodeClosure: HTTPRequestWorker.DecodeClosure = { (data) in
      guard let data = data,
        let receivedObject: Any = CZHTTPJsonSerializer.deserializedObject(with: data) else {
          assertionFailure("Failed to deserialize data to object.")
          return nil
      }
      guard let model: Model = self.model(with: receivedObject, dataKey: dataKey).assertIfNil else {
        return nil
      }
      return model
    }
    
    return decodeClosure
  }
  
  /// Returns  decodeClosure for many CZDictionaryable Models.
  ///
  /// - Parameters:
  ///   - dataKey: The dataKey to retrive value from dictionary. If nil, parse the complete dictionary.
  ///   - inferringModel: A workaround to pass in `Model` type to method signature.
  static func manyDictionaryablesDecodeClosure<Model: CZDictionaryable>(dataKey: String?,
                                                   inferringModel: Model? = nil) -> HTTPRequestWorker.DecodeClosure {
    
    let decodeClosure: HTTPRequestWorker.DecodeClosure = { (data) in
      guard let data = data,
        let receivedObject: Any = CZHTTPJsonSerializer.deserializedObject(with: data) else {
          assertionFailure("Failed to deserialize data to object.")
          return nil
      }
      guard let models: [Model] = self.models(with: receivedObject, dataKey: dataKey).assertIfNil else {
        return nil
      }
      return models
    }
    
    return decodeClosure
  }
  
}


// MARK: - Utils

private extension DataDecodeHelper {
  
  static func model<Model: CZDictionaryable>(with object: Any, dataKey: String? = nil) -> Model? {
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
  
  static func models<Model: CZDictionaryable>(with object: Any, dataKey: String? = nil) -> [Model]? {
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
