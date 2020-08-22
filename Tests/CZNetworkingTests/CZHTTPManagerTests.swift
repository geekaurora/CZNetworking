import XCTest
import CZUtils
import CZTestUtils
@testable import CZNetworking

final class CZHTTPManagerTests: XCTestCase {
  private enum MockData {
    static let urlForGet = URL(string: "https://www.apple.com/newsroom/rss-feed-GET.rss")!
    static let urlForGetCodable = URL(string: "https://www.apple.com/newsroom/rss-feed-GETCodable.rss")!
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
    static let models = (0..<10).map { TestModel(id: $0, name: "Model\($0)") }
  }
  
  /**
   Test GET() method.
   */
  func testGET() {
    let (waitForExpectatation, expectation) = CZTestUtils.waitWithInterval(30, testCase: self)
    
    // Create mockDataMap.
    let mockData = CZHTTPJsonSerializer.jsonData(with: MockData.dictionary)!
    let mockDataMap = [MockData.urlForGet: mockData]
    
    // Fetch with stub URLSession.
    let sessionConfiguration = CZHTTPStub.stubURLSessionConfiguration(mockDataMap: mockDataMap)
    CZHTTPManager.urlSessionConfiguration = sessionConfiguration
    CZHTTPManager.shared.GET(MockData.urlForGet.absoluteString, success: { (_, data) in
      let res: [String: AnyHashable]? = CZHTTPJsonSerializer.deserializedObject(with: data)
      XCTAssert(res == MockData.dictionary, "Actual result = \(res), Expected result = \(MockData.dictionary)")
      expectation.fulfill()
    })
    
    // Wait for expectatation.
    waitForExpectatation()
  }
  
  /**
   Test GET() method with `cached` handler.
   */
  func testGETWithCache() {
    let (waitForExpectatation, expectation) = CZTestUtils.waitWithInterval(30, testCase: self)
    
    // Create mockDataMap.
    let mockData = CZHTTPJsonSerializer.jsonData(with: MockData.dictionary)!
    let mockDataMap = [MockData.urlForGet: mockData]
    
    let success: HTTPRequestWorker.Success = { (_, data) in
      let res: [String: AnyHashable]? = CZHTTPJsonSerializer.deserializedObject(with: data)
      XCTAssert(res == MockData.dictionary, "Actual result = \(res), Expected result = \(MockData.dictionary)")
    }
    
    let cached: HTTPRequestWorker.Success = { (_, data) in
      let res: [String: AnyHashable]? = CZHTTPJsonSerializer.deserializedObject(with: data)
      XCTAssert(res == MockData.dictionary, "Actual result = \(res), Expected result = \(MockData.dictionary)")
    }
    
    // 1. Fetch with stub URLSession.
    let sessionConfiguration = CZHTTPStub.stubURLSessionConfiguration(mockDataMap: mockDataMap)
    CZHTTPManager.urlSessionConfiguration = sessionConfiguration
    CZHTTPManager.shared.GET(
      MockData.urlForGet.absoluteString,
      success: success,
      cached: cached)
    
    // 2. Verify cache: fetch again.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      CZHTTPManager.shared.GET(
        MockData.urlForGet.absoluteString,
        success: success,
        cached: { (task, data) in
          cached(task, data)
          // Fullfill the expectatation.
          expectation.fulfill()
      })
    }
    
    // Wait for expectatation.
    waitForExpectatation()
  }
  
  /**
   Test GETCodable() method.
   */
  func testGETCodable() {
    let (waitForExpectatation, expectation) = CZTestUtils.waitWithInterval(30, testCase: self)
    
    // Create mockDataMap.
    let mockData = CodableHelper.encode(MockData.models)!
    let mockDataMap = [MockData.urlForGetCodable: mockData]
    
    // Fetch with stub URLSession.
    let sessionConfiguration = CZHTTPStub.stubURLSessionConfiguration(mockDataMap: mockDataMap)
    CZHTTPManager.urlSessionConfiguration = sessionConfiguration
    
    // Verify data.
    CZHTTPManager.shared.GETCodableModel(MockData.urlForGetCodable.absoluteString, success: { (models: [TestModel]) in
      XCTAssert(
        models.isEqual(toCodable: MockData.models),
        "Actual result = \n\(models) \n\nExpected result = \n\(MockData.models)")
      expectation.fulfill()
    })
    
    // Wait for expectatation.
    waitForExpectatation()
  }
  
}

struct TestModel: Codable {
  let id: Int
  let name: String
}
