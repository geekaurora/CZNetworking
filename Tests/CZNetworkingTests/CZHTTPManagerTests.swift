import XCTest
import CZUtils
import CZTestUtils
@testable import CZNetworking

final class CZHTTPManagerTests: XCTestCase {
  public typealias GetRequestSuccess = (Data?) -> Void
  
  private enum Constant {
    static let timeOut: TimeInterval = 10
  }
  private enum MockData {
    static let urlForGet = URL(string: "https://www.apple.com/newsroom/rss-feed-GET.rss")!
    static let urlForGetCodable = URL(string: "https://www.apple.com/newsroom/rss-feed-GETCodable.rss")!
    static let urlForGetDictionaryable = URL(string: "https://www.apple.com/newsroom/rss-feed-GetDictionaryable.rss")!
    static let urlForGetDictionaryableOneModel = URL(string: "https://www.apple.com/newsroom/rss-feed-GetDictionaryableOneModel.rss")!
    
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
    static let oneModel = TestModel(id: 1, name: "Model1")
  }
  
  static let queueLable = "com.tests.queue"
  @ThreadSafe
  private var executionSuccessCount = 0
  private var czHTTPManager: CZHTTPManager!
  
  override func setUp() {
    CZNetworkingConstants.shouldReuseOperation = false
    
    czHTTPManager = CZHTTPManager()
    executionSuccessCount = 0
  }
  
  // MARK: - GETCodable
  
  /**
   Test GET() method.
   */
  func testGET() {
    let (waitForExpectatation, expectation) = CZTestUtils.waitWithInterval(Constant.timeOut, testCase: self)
    
    // Create mockDataMap.
    let mockData = CZHTTPJsonSerializer.jsonData(with: MockData.dictionary)!
    let mockDataMap = [MockData.urlForGet: mockData]
    
    // Stub MockData.
    CZHTTPManager.stubMockData(dict: mockDataMap)
    
    // Get the data with `MockData.urlForGet`.
    CZHTTPManager.shared.GET(
      MockData.urlForGet.absoluteString,
      success: { (data) in
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
  func testGETWithCache1() {
    let (waitForExpectatation, expectation) = CZTestUtils.waitWithInterval(Constant.timeOut, testCase: self)
    
    // Create mockDataMap.
    let mockData = CZHTTPJsonSerializer.jsonData(with: MockData.dictionary)!
    let mockDataMap = [MockData.urlForGet: mockData]
    
    let success: GetRequestSuccess = { (data) in
      let res: [String: AnyHashable]? = CZHTTPJsonSerializer.deserializedObject(with: data)
      XCTAssert(res == MockData.dictionary, "Actual result = \(res), Expected result = \(MockData.dictionary)")
    }
    
    let cached: GetRequestSuccess = { (data) in
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
        cached: { (data) in
          cached(data)
          // Fullfill the expectatation.
          expectation.fulfill()
      })
    }
    
    // Wait for expectatation.
    waitForExpectatation()
  }
      
  /// [Written by the previous test] Test read from cache after relaunching App / ColdStart.
  /// It verifies both DiskCache and MemCache.
  ///
  /// - Note: MUST run `testGETWithCache1` first!
  ///
  /// As Swift doesn't support `testInvocations` override, so can only order tests by alphabet names
  /// to simulate relaunching App.
  func testGETWithCache2AfterRelaunchingApp() {
    let (waitForExpectatation, expectation) = CZTestUtils.waitWithInterval(Constant.timeOut, testCase: self)
        
    // Create mockDataMap.
    let mockData = CZHTTPJsonSerializer.jsonData(with: MockData.dictionary)!
    let mockDataMap = [MockData.urlForGet: mockData]
    
    let success: GetRequestSuccess = { (data) in
      let res: [String: AnyHashable]? = CZHTTPJsonSerializer.deserializedObject(with: data)
      XCTAssert(res == MockData.dictionary, "Actual result = \(res), Expected result = \(MockData.dictionary)")
    }
    let cached = success
    
    // 0. Stub MockData.
    CZHTTPManager.stubMockData(dict: mockDataMap)
    
    // 1. Fetch with stub URLSession.
    CZHTTPManager.shared.GET(
      MockData.urlForGet.absoluteString,
      success: success,
      cached: { (data) in
        // 2. Verify cache: read from disk after ColdLaunch.
        cached(data)
        expectation.fulfill()
      })
    
    // Wait for expectatation.
    waitForExpectatation()
  }

  /**
   Verify GET() method: without `cached` handler, it shouldn't cache data to disk.
   */
  func testGETWithoutCache() {
    let (waitForExpectatation, expectation) = CZTestUtils.waitWithInterval(Constant.timeOut, testCase: self)
    
    // Clear disk cache.
    czHTTPManager.httpCache.clearCache()

    // Create mockDataMap.
    let mockData = CZHTTPJsonSerializer.jsonData(with: MockData.dictionary)!
    let mockDataMap = [MockData.urlForGet: mockData]
    
    let success: GetRequestSuccess = { (data) in
      let res: [String: AnyHashable]? = CZHTTPJsonSerializer.deserializedObject(with: data)
      XCTAssert(res == MockData.dictionary, "Actual result = \(res), Expected result = \(MockData.dictionary)")
    }
    
    // 0. Stub MockData.
    CZHTTPManager.stubMockData(dict: mockDataMap)
    
    // 1. Fetch with stub URLSession: `cached` handler is nil.
    czHTTPManager.GET(
      MockData.urlForGet.absoluteString,
      success: success,
      cached: nil)
    
    // 2. Verify cache(shouldn't cache): fetch again.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      self.czHTTPManager.GET(
        MockData.urlForGet.absoluteString,
        success: { (data) in
          // Fullfill the expectatation.
          expectation.fulfill()
        },
        cached: { (data) in
          XCTFail("Second time `cached` shouldn't be called - because the first time `cached` wasn't set.")
      })
    }
    
    // Wait for expectatation.
    waitForExpectatation()
  }
    
  /**
   Test GET() method with `cached` handler on multi threads.
   */
  func testGETWithCacheMultiThreads() {
    let (waitForExpectatation, expectation) = CZTestUtils.waitWithInterval(Constant.timeOut, testCase: self)
    
    // Create mockDataMap.
    let mockData = CZHTTPJsonSerializer.jsonData(with: MockData.dictionary)!
    let mockDataMap = [MockData.urlForGet: mockData]
    
    let success: GetRequestSuccess = { (data) in
      let res: [String: AnyHashable]? = CZHTTPJsonSerializer.deserializedObject(with: data)
      XCTAssert(res == MockData.dictionary, "Actual result = \(res), Expected result = \(MockData.dictionary)")
    }
    
    let cached: GetRequestSuccess = { (data) in
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
        success: { (data) in
          success(data)
          self._executionSuccessCount.threadLock {
            $0 = $0 + 1
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
  
  // MARK: - GETCodable
  
  /**
   Test GETCodable() method.
   */
  func testGETCodableModel() {
    let (waitForExpectatation, expectation) = CZTestUtils.waitWithInterval(Constant.timeOut, testCase: self)
    
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
    let (waitForExpectatation, expectation) = CZTestUtils.waitWithInterval(Constant.timeOut, testCase: self)
    
    // Create mockDataMap.
    let mockData = CodableHelper.encode(MockData.models)!
    let mockDataMap = [MockData.urlForGetCodable: mockData]    
    
    // Stub MockData.
    CZHTTPManager.stubMockData(dict: mockDataMap)
    
    // Verify data.
    CZHTTPManager.shared.GETCodableModels(MockData.urlForGetCodable.absoluteString, success: { (models: [TestModel], data) in
      XCTAssert(
        models.isEqual(toCodable: MockData.models),
        "Actual result = \n\(models) \n\nExpected result = \n\(MockData.models)")
      expectation.fulfill()
    })
    
    // Wait for expectatation.
    waitForExpectatation()
  }  
  
  /**
     Test GETCodableModels() method with `cached` handler.
     */
    func testGETCodableModelsWithCache() {
      let (waitForExpectatation, expectation) = CZTestUtils.waitWithInterval(Constant.timeOut, testCase: self)
      
      // Create mockDataMap.
      let mockData = CodableHelper.encode(MockData.models)!
      let mockDataMap = [MockData.urlForGetCodable: mockData]
      
      let success = { (models: [TestModel], data: Data?) in
        XCTAssert(
          models.isEqual(toCodable: MockData.models),
          "Actual result = \n\(models) \n\nExpected result = \n\(MockData.models)")
      }      
      let cached = success
      
      // 0. Stub MockData.
      CZHTTPManager.stubMockData(dict: mockDataMap)
      
      // 1. Fetch with stub URLSession.
      CZHTTPManager.shared.GETCodableModels(
        MockData.urlForGetCodable.absoluteString,
        success: success,
        cached: cached)
      
      // 2. Verify cache: fetch again.
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        CZHTTPManager.shared.GETCodableModels(
          MockData.urlForGetCodable.absoluteString,
          success: success,
          cached: { (models: [TestModel], data: Data?) in
            cached(models, data)
            // Fullfill the expectatation.
            expectation.fulfill()
        })
      }
      
      // Wait for expectatation.
      waitForExpectatation()
    }
  
  // MARK: - GetDictionaryable
  
  /**
   Test GetOneModel() method.
   */
  func testGetOneModel() {
    let (waitForExpectatation, expectation) = CZTestUtils.waitWithInterval(Constant.timeOut, testCase: self)
    
    // Create mockDataMap.
    let mockData = CodableHelper.encode(MockData.oneModel)!
    let mockDataMap = [MockData.urlForGetDictionaryableOneModel: mockData]
    
    // Stub MockData.
    CZHTTPManager.stubMockData(dict: mockDataMap)
    
    // Verify data.
    CZHTTPManager.shared.GetOneModel(MockData.urlForGetDictionaryableOneModel.absoluteString, success: { (model: TestModel) in
      XCTAssert(
        model.isEqual(toCodable: MockData.oneModel),
        "Actual result = \n\(model) \n\nExpected result = \n\(MockData.oneModel)")
      expectation.fulfill()
    })
    
    // Wait for expectatation.
    waitForExpectatation()
  }
  
  /**
   Test GetManyModels() method.
   */
  func testGetManyModels() {
    let (waitForExpectatation, expectation) = CZTestUtils.waitWithInterval(Constant.timeOut, testCase: self)
    
    // Create mockDataMap.
    let mockData = CodableHelper.encode(MockData.models)!
    let mockDataMap = [MockData.urlForGetDictionaryable: mockData]
    
    // Stub MockData.
    CZHTTPManager.stubMockData(dict: mockDataMap)
    
    // Verify data.
    CZHTTPManager.shared.GetManyModels(MockData.urlForGetDictionaryable.absoluteString, success: { (models: [TestModel]) in
      XCTAssert(
        models.isEqual(toCodable: MockData.models),
        "Actual result = \n\(models) \n\nExpected result = \n\(MockData.models)")
      expectation.fulfill()
    })
    
    // Wait for expectatation.
    waitForExpectatation()
  }
  
}

struct TestModel: Codable, CZDictionaryable {
  let id: Int
  let name: String
  
  init(id: Int, name: String) {
    self.id = id
    self.name = name
  }
  
  init(dictionary: CZDictionary) {
    self.id = dictionary["id"] as! Int
    self.name = dictionary["name"] as! String
  }
}
