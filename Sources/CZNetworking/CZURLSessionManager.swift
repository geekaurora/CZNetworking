import Foundation

/// Manager that manages URLSession for CZNetworking.
class CZURLSessionManager: NSObject {
  let urlSession: URLSession
  
  override init() {
    urlSession = URLSession(
      configuration: CZHTTPManager.urlSessionConfiguration,
      delegate: nil,
      delegateQueue: nil)
    super.init()
  }  
  
}

// MARK: - URLSessionDataDelegate

extension CZURLSessionManager: URLSessionDataDelegate {
  public func urlSession(_ session: URLSession,
                         dataTask: URLSessionDataTask,
                         didReceive response: URLResponse,
                         completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
    
  }
  
  public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    
  }
  
  public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        
  }
}
