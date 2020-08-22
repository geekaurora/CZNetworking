import Foundation

/**
 Mock that be used to inject data into default`URLSession` with `URLSessionConfiguration`.
 */
public class URLProtocolMock: URLProtocol {
  // TestData for url - [testURL: testData].
  public typealias MockDataMap = [URL: Data]
  static var mockDataMap = MockDataMap()
  
  public override func startLoading() {
    if let url = request.url {
      // Return mockData for `url` if exists.
      if let data = URLProtocolMock.mockDataMap[url] {
        self.client?.urlProtocol(self, didLoad: data)
      }
    }
    // Mark as finished.
    self.client?.urlProtocolDidFinishLoading(self)
  }
  
  public override class func canInit(with request: URLRequest) -> Bool {
    // Handle all types of requests.
    return true
  }
  
  public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    return request
  }
  
  public override func stopLoading() {}
}
