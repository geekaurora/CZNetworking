import Foundation
import CZUtils

/**
 Stub mock data to CZHTTPManager. This stub can be utilized by any networking frameworks built unpon CZHTTPManager.
 
 ### Usage
 ```
 let mockData = CZHTTPJsonSerializer.jsonData(with: MockData.dictionary)!
 let mockDataDict = [MockData.urlForGet: mockData]
 CZHTTPManager.stubMockData(dict: mockDataDict)
 
 httpFileManager.downloadFile(url: MockData.urlForGet) { (data: Data?, error: Error?, fromCache: Bool) in
   let res: [String: AnyHashable]? = CZHTTPJsonSerializer.deserializedObject(with: data)
   XCTAssert(res == MockData.dictionary, "Actual result = \(res), Expected result = \(MockData.dictionary)")
 }
 ```
 */
public extension CZHTTPManager {
  /**
   Stub mock data to CZHTTPManager.   
   - Note: run app twice to make stubbing effective.
   
    - Parameter mockDataDict: [URL: Data] dictionary that maps `url` to its corresponding mocked data.
   */
  static func stubMockData(dict mockDataDict: URLProtocolMock.MockDataMap) {
    // Note: `task.response` will be nil, should set `CZTestHelper.isInUnitTest` to true to avoid assertion.
    CZTestHelper.isInUnitTest = true
    
    // Fetch with stub URLSession.
    let sessionConfiguration = CZHTTPStub.stubURLSessionConfiguration(mockDataMap: mockDataDict)
    // Replace urlSessionConfiguration of CZHTTPManager to stub data.
    CZHTTPManager.urlSessionConfiguration = sessionConfiguration
  }
}

public class CZHTTPStub {
  /**
   Returns URLSession configuration for stubbing data.
   */
  public static func stubURLSessionConfiguration(mockDataMap: URLProtocolMock.MockDataMap) -> URLSessionConfiguration {
    // Insert `mockDataMap` into URLProtocolMock.
    URLProtocolMock.mockDataMap.insert(mockDataMap)
    
    // Set up URLSessionConfiguration to use mock.
//    let config = URLSessionConfiguration.ephemeral
    let config = URLSessionConfiguration.default
    
    /*
     - 0 : _NSURLHTTPProtocol
     - 1 : _NSURLDataProtocol
     - 2 : _NSURLFTPProtocol
     - 3 : _NSURLFileProtocol
     - 4 : NSAboutURLProtocol
     */
    // config.protocolClasses = [URLProtocolMock.self]
    config.protocolClasses = [URLProtocolMock.self] + (config.protocolClasses ?? [])
    
    // Return config.
    return config
  }
  
  /**
   Returns URLSession for stubbing data.
   */
  public static func stubURLSession(mockDataMap: URLProtocolMock.MockDataMap) -> URLSession {
    // Insert `mockDataMap` into URLProtocolMock.
    URLProtocolMock.mockDataMap.insert(mockDataMap)
    
    // Set up URLSessionConfiguration to use mock.
    let config = Self.stubURLSessionConfiguration(mockDataMap: mockDataMap)
    
    // Return URLSession.
    return URLSession(configuration: config)
  }
}
