import XCTest
import CZUtils
import CZTestUtils
@testable import CZNetworking

final class CZHTTPManagerTests: XCTestCase {
  public typealias GetRequestSuccess = (URLSessionDataTask?, Data?) -> Void
  
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
  static let queueLable = "com.tests.queue"
  @ThreadSafe
  private var executionSuccessCount = 0
  
  override func setUp() {
    executionSuccessCount = 0
  }
  
  /**
   Test GET() method.
   */
  func testGET() {
    let (waitForExpectatation, expectation) = CZTestUtils.waitWithInterval(30, testCase: self)
    
    // Create mockDataMap.
    let mockData = CZHTTPJsonSerializer.jsonData(with: MockData.dictionary)!
    let mockDataMap = [MockData.urlForGet: mockData]
    
    // Stub MockData.
    CZHTTPManager.stubMockData(dict: mockDataMap)
    
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
    
    let success: GetRequestSuccess = { (_, data) in
      let res: [String: AnyHashable]? = CZHTTPJsonSerializer.deserializedObject(with: data)
      XCTAssert(res == MockData.dictionary, "Actual result = \(res), Expected result = \(MockData.dictionary)")
    }
    
    let cached: GetRequestSuccess = { (_, data) in
      let res: [String: AnyHashable]? = CZHTTPJsonSerializer.deserializedObject(with: data)
      XCTAssert(res == MockData.dictionary, "Actual result = \(res), Expected result = \(MockData.dictionary)")
    }
    
    // 0. Stub MockData.
    CZHTTPManager.stubMockData(dict: mockDataMap)
    
    // 1. Fetch with stub URLSession.
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
   Test GET() method with `cached` handler on multi threads.
   */
  func testGETWithCacheMultiThreads() {
    let (waitForExpectatation, expectation) = CZTestUtils.waitWithInterval(30, testCase: self)
    
    // Create mockDataMap.
    let mockData = CZHTTPJsonSerializer.jsonData(with: MockData.dictionary)!
    let mockDataMap = [MockData.urlForGet: mockData]
    
    let success: GetRequestSuccess = { (_, data) in
      let res: [String: AnyHashable]? = CZHTTPJsonSerializer.deserializedObject(with: data)
      XCTAssert(res == MockData.dictionary, "Actual result = \(res), Expected result = \(MockData.dictionary)")
    }
    
    let cached: GetRequestSuccess = { (_, data) in
      let res: [String: AnyHashable]? = CZHTTPJsonSerializer.deserializedObject(with: data)
      XCTAssert(res == MockData.dictionary, "Actual result = \(res), Expected result = \(MockData.dictionary)")
    }
    
    // 1. Stub MockData.
    CZHTTPManager.stubMockData(dict: mockDataMap)
    
    // 2. Fetch with stub URLSession on multi threads.
    let totalCount = 1000
    let dispatchGroup = DispatchGroup()
    (0..<totalCount).forEach { _ in
      dispatchGroup.enter()
      CZHTTPManager.shared.GET(
        MockData.urlForGet.absoluteString,
        success: { (task, data) in
          success(task, data)
          self._executionSuccessCount.threadLock { $0 = $0 + 1
            print("Success count = \($0)")
          }
          dispatchGroup.leave()
      }, cached: cached)
    }
    
    // 3. Wait till group multi thread tasks complete.
    dispatchGroup.notify(queue: .main) {
      let successCount = self._executionSuccessCount.threadLock { $0 }
      // Verify success `count` with the expected value.
      XCTAssert(
        successCount == totalCount,
        "Not all executions succeed! Actual result = \(successCount), Expected result = \(totalCount)")
      expectation.fulfill()
    }
    
    // 4. Wait for expectatation.
    waitForExpectatation()
  }
  
  /**
   Test GETCodable() method.
   */
  func testGETCodableModel() {
    let (waitForExpectatation, expectation) = CZTestUtils.waitWithInterval(30, testCase: self)
    
    // Create mockDataMap.
    let mockData = CodableHelper.encode(MockData.models)!
    let mockDataMap = [MockData.urlForGetCodable: mockData]
    
    // Stub MockData.
    CZHTTPManager.stubMockData(dict: mockDataMap)
    
    // Verify data.
    CZHTTPManager.shared.GETCodableModel(MockData.urlForGetCodable.absoluteString, success: { (models: [TestModel], _) in
      XCTAssert(
        models.isEqual(toCodable: MockData.models),
        "Actual result = \n\(models) \n\nExpected result = \n\(MockData.models)")
      expectation.fulfill()
    })
    
    // Wait for expectatation.
    waitForExpectatation()
  }
  
  /**
   Test GETCodableModels() method.
   */
  func testGETCodableModels() {
    let (waitForExpectatation, expectation) = CZTestUtils.waitWithInterval(30, testCase: self)
    
    // Create mockDataMap.
    let mockData = CodableHelper.encode(MockData.models)!
    let mockDataMap = [MockData.urlForGetCodable: mockData]    
    
    // Stub MockData.
    CZHTTPManager.stubMockData(dict: mockDataMap)
    
    // Verify data.
    CZHTTPManager.shared.GETCodableModels(MockData.urlForGetCodable.absoluteString, success: { (models: [TestModel]) in
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
