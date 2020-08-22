import Foundation

/**
 Mock that be used to inject data into default`URLSession` with `URLSessionConfiguration`.
 */
class URLProtocolMock: URLProtocol {
  // TestData for url - [testURL: testData].
  static var mockDataMap = [URL: Data]()
  
  override func startLoading() {
    if let url = request.url {
      // Return mockData for `url` if exists.
      if let data = URLProtocolMock.mockDataMap[url] {
        self.client?.urlProtocol(self, didLoad: data)
      }
    }
    // Mark as finished.
    self.client?.urlProtocolDidFinishLoading(self)
  }
  
  override class func canInit(with request: URLRequest) -> Bool {
    // Handle all types of requests.
    return true
  }
  
  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    return request
  }
  
  override func stopLoading() {}
}
