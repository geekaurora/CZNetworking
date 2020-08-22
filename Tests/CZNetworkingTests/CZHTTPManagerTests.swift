import XCTest
import CZUtils
@testable import CZNetworking

final class CZHTTPManagerTests: XCTestCase {
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
  
  func testGET() {
    let (waitForExpectatation, expectation) = CZTestUtils.waitWithInterval(3, testCase: self)

    // Create mockDataMap.
    let url = URL(string: "https://www.apple.com/newsroom/rss-feed.rss")!
    let mockData = CZHTTPJsonSerializer.jsonData(with: MockData.dictionary)!
    let mockDataMap = [url: mockData]
    
    // Fetch with stub URLSession.
    let sessionConfiguration = CZHTTPStub.stubURLSessionConfiguration(mockDataMap: mockDataMap)
    CZHTTPManager.urlSessionConfiguration = sessionConfiguration
    
//    CZHTTPManager.shared.GetOneModel(url.absoluteString, success: { data in
//
//    })
    
    CZHTTPManager.shared.GET(url.absoluteString, success: { (_, data) in
      
    })
    
//
//    let innerCompletion = { (feeds: [Model]) in
//      print("\(#function) Fetched feeds: \(feeds)")
//      completion(feeds, nil)
//    }
//    let cachedCompletion = shouldUseCache ? innerCompletion : nil
//
//    CZHTTPManager.shared.GETCodableModel(
//      endPoint,
//      headers: headers,
//      params: params,
//      dataKey: dataKey,
//      success: innerCompletion,
//      failure: { (task, error) in
//        assertionFailure("\(#function) - failed to fetch models. Error - \(error)")
//        completion(nil, error)
//    }, cached: cachedCompletion)
    
//
//    session.dataTask(with: url) {  (data, response, error) in
//      guard let data = data.assertIfNil else {
//        return
//      }
//      let res: [String: AnyHashable]? = CZHTTPJsonSerializer.deserializedObject(with: data)
//      XCTAssert(res == MockData.dictionary, "Actual result \(res), Expected result = \(MockData.dictionary)")
//      expectation.fulfill()
//    }.resume()
    
//    waitForExpectatation()
    
    sleep(3)
  }
}
