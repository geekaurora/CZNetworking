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
  
  /** Return mock data for `url`.  */
  public override func startLoading() {
    if let url = request.url {
      // Return mockData for `url` if exists, nil otherwise.
      if let data = Self.mockDataMap[url] {
        self.client?.urlProtocol(self, didLoad: data)
        
        // Mark as finished.
        self.client?.urlProtocolDidFinishLoading(self)
        return
      }
    }
//    // Mark as finished.
//    self.client?.urlProtocolDidFinishLoading(self)
    
    super.startLoading()
  }
  
  public override class func canInit(with request: URLRequest) -> Bool {
    // dbgPrintWithFunc(self, "request.url = \(request.url)")
    
    // Only handle `url` that is in `mockDataMap`.
    if let url = request.url,
       Self.mockDataMap[url] != nil {
      return true
    }
    return false
  }
  
  public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    return request
  }
  
  public override func stopLoading() {}
}
