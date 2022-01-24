import Foundation
import CZUtils

class DataDecodeHelper {
  
  static func codableDecodeClosure<Model: Codable>(dataKey: String?,
                                                   tmpModel: Model? = nil) -> HTTPRequestWorker.DecodeClosure {
    
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
  
}
