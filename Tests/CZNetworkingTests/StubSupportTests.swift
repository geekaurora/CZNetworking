import XCTest
import CZUtils
@testable import CZNetworking

/**
 Verify StubSupport.
 */
final class StubSupportTests: XCTestCase {
  private enum MockData {
    static let dictionary: [String: AnyHashable] = [
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
  
  func testStubData() {
    let (waitForExpectatation, expectation) = CZTestUtils.waitWithInterval(3, testCase: self)

    // Create mockDataMap.
    let url = URL(string: "https://www.apple.com/newsroom/rss-feed.rss")!
    let mockData = CZHTTPJsonSerializer.jsonData(with: MockData.dictionary)!
    let mockDataMap = [url: mockData]
    
    // Fetch with stub URLSession.
    let session = CZHTTPStub.stubURLSession(mockDataMap: mockDataMap)
    session.dataTask(with: url) {  (data, response, error) in
      guard let data = data.assertIfNil else {
        return
      }
      let res: [String: AnyHashable]? = CZHTTPJsonSerializer.deserializedObject(with: data)
      XCTAssert(res == MockData.dictionary, "Actual result \(res), Expected result = \(MockData.dictionary)")
      expectation.fulfill()
    }.resume()
    
    // Wait for expectation.
    waitForExpectatation()
  }
}
