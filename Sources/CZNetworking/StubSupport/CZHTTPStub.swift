import Foundation
import CZUtils

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
    config.protocolClasses = [URLProtocolMock.self]
    
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
