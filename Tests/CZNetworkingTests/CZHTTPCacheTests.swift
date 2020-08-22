import XCTest
import CZUtils
@testable import CZNetworking

final class CZHTTPCacheTests: XCTestCase {
  private enum MockData {
    static let key = "929832737212"
    static let dict: [String: AnyHashable] = [
      "a": "sdlfjas",
      "c": "sdlksdf",
      "b": "239823sd",
      "d": 189298723,
    ]
    static let array: [AnyHashable] = [
      "sdlfjas",
      "sdlksdf",
      "239823sd",
      189298723,
    ]
  }
  var httpCache: CZHTTPCache!
  
  override func setUp() {
    httpCache = CZHTTPCache()
    httpCache.removeData(key: MockData.key)
    Thread.sleep(forTimeInterval: 0.01)
  }
  
  func testReadWriteData() {
    let data = CZHTTPJsonSerializer.jsonData(with: MockData.dict)!
    httpCache.saveData(data, forKey: MockData.key)
    Thread.sleep(forTimeInterval: 0.01)

    let readData = httpCache.readData(forKey: MockData.key) as? Data
    XCTAssert(data == readData, "Actual result \(readData), Expected result = \(data)")
  }
  
  func testReadWriteDictionary() {
    let dictionary = MockData.dict
    httpCache.saveData(dictionary, forKey: MockData.key)
    Thread.sleep(forTimeInterval: 0.01)
    
    let readDictionary = httpCache.readData(forKey: MockData.key) as? [String: AnyHashable]
    XCTAssert(dictionary == readDictionary, "Actual result \(readDictionary), Expected result = \(dictionary)")
  }
  
  func testReadWriteArray() {
    let array = MockData.array
    httpCache.saveData(array, forKey: MockData.key)
    Thread.sleep(forTimeInterval: 0.01)
    
    let readArray = httpCache.readData(forKey: MockData.key) as? [AnyHashable]
    XCTAssert(array == readArray, "Actual result \(readArray), Expected result = \(array)")
  }
}
