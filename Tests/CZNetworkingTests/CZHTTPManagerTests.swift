import XCTest
import CZUtils
@testable import CZNetworking

final class CZHTTPManagerTests: XCTestCase {
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

  }
  
  func testFetchData() {
    
  }
  
}
