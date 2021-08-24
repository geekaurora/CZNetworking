import Foundation
import CZUtils

/**
 Mock that be used to inject data into default`URLSession` with `URLSessionConfiguration`.
 
 - Note: All fetchings will use`URLProtocolMock`, instead of normal `URLProtocol`.
 If no mockData is for `url`, response data will be nil.
 */
public class URLProtocolMock: URLProtocol {
  // TestData for url - [testURL: testData].
  public typealias MockDataMap = [URL: Data]
  static var mockDataMap = MockDataMap()
  
  // MARK: - Whether to handle request
  
  public override class func canInit(with request: URLRequest) -> Bool {
    // Only handle `url` if it's in `mockDataMap`.
    if let url = request.url,
       Self.mockDataMap[url] != nil {
      return true
    }
    return false
  }
  
  // MARK: - Load data
  
  /** Return mockData for `url` if exists,  otherwise call `super.startLoading()`. */
  public override func startLoading() {
    // Return mockData for `url` if exists.
    if let url = request.url,
       let data = Self.mockDataMap[url] {
      self.client?.urlProtocol(self, didLoad: data)
      
      // Mark as finished.
      self.client?.urlProtocolDidFinishLoading(self)
      return
    }
    
    // Otherwise call `super.startLoading()` to handle it.
    super.startLoading()
  }
  
  public override func stopLoading() {}
    
  public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    return request
  }
}
