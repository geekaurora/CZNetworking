import Foundation
import CZUtils

public class CZHTTPStub {
  /**
   Returns URLSession for stubbing data.
   */
  public static func stubURLSession(mockDataMap: URLProtocolMock.MockDataMap) -> URLSession {
    // Insert `mockDataMap` into URLProtocolMock.
    URLProtocolMock.mockDataMap.insert(mockDataMap)
    
    // Set up URLSessionConfiguration to use mock.
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [URLProtocolMock.self]
    
    // Return URLSession.
    return URLSession(configuration: config)
  }
}
