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
  
  override func setUp() {    
  }
  
  func testStubData() {
    let url = URL(string: "https://www.apple.com/newsroom/rss-feed.rss")!
    let mockData = CZHTTPJsonSerializer.jsonData(with: MockData.dictionary)
    URLProtocolMock.mockDataMap[url] = mockData
    
    // Set up URLSessionConfiguration to use mock.
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [URLProtocolMock.self]
    
    // Fetch with URLSession.
    let (waitForExpectatation, expectation) = CZTestUtils.waitWithInterval(30, testCase: self)
    let session = URLSession(configuration: config)
    session.dataTask(with: url) {  (data, response, error) in
      guard let data = data.assertIfNil else {
        return
      }
      let res: [String: AnyHashable]? = CZHTTPJsonSerializer.deserializedObject(with: data)
      XCTAssert(res == MockData.dictionary, "Actual result \(res), Expected result = \(MockData.dictionary)")
      expectation.fulfill()
    }.resume()
    
    waitForExpectatation()
  }
  
}
