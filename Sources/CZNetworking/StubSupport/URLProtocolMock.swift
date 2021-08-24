import Foundation
import CZUtils

/**
 Mock that be used to inject data into default`URLSession` with `URLSessionConfiguration`.
 
 - Note: Return mockData for `url` if exists,  otherwise it will let other URLProtocols to handle.
 */
public class URLProtocolMock: URLProtocol {
  // TestData for url - [testURL: testData].
  public typealias MockDataMap = [URL: Data]
  static var mockDataMap = MockDataMap()
  
  // MARK: - Whether to handle request
  
  public override class func canInit(with request: URLRequest) -> Bool {
    // Only handle `url` if exists in `mockDataMap`.
    if let url = request.url,
       Self.mockDataMap[url] != nil {
      return true
    }
    return false
  }
  
  // MARK: - Load data
  
  /** Return mockData for `url` if exists,  otherwise call `super.startLoading()`.  */
  public override func startLoading() {
    //  Check whether `url` exists in `mockDataMap`.
    if let url = request.url,
       let data = Self.mockDataMap[url] {
      
      // Return mockData for `url`.
      self.client?.urlProtocol(self, didLoad: data)
      
      // let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
      // self.client?.urlProtocol(self, didReceive: response)
      
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
  
  // TODO: Check url of URLSessionTask.
  // public override class func canInit(with task: URLSessionTask) -> Bool {}
}
