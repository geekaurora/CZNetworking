import Foundation
import CZUtils

/// Manager that manages URLSession for CZNetworking.
public class CZURLSessionManager: NSObject {
  private(set) var urlSession: URLSession!
  
  weak var coordinator: CZHTTPManager?
  
  override init() {
    super.init()
    
    self.urlSession = URLSession(
      configuration: CZHTTPManager.urlSessionConfiguration,
      delegate: self,
      delegateQueue: nil)
  }
}

// MARK: - URLSessionDataDelegate

extension CZURLSessionManager: URLSessionDataDelegate {
  public func urlSession(_ session: URLSession,
                         dataTask: URLSessionDataTask,
                         didReceive response: URLResponse,
                         completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
    guard let httpWorker = self.httpWorker(for: dataTask).assertIfNil else {
      return
    }
    httpWorker.urlSession(
      session,
      dataTask: dataTask,
      didReceive: response,
      completionHandler: completionHandler)
  }
  
  public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    guard let httpWorker = self.httpWorker(for: dataTask).assertIfNil else {
      return
    }
    httpWorker.urlSession(
      session,
      dataTask: dataTask,
      didReceive: data)
  }
  
  public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    guard let httpWorker = self.httpWorker(for: task).assertIfNil else {
      return
    }
    httpWorker.urlSession(
      session,
      task: task,
      didCompleteWithError: error)
  }
}

// MARK: - Private methods

private extension CZURLSessionManager {
  func httpWorker(for dataTask: URLSessionTask) -> HTTPRequestWorker? {
    guard let coordinator = coordinator.assertIfNil else {
      return nil
    }    
//    let operations = coordinator.workQueue.operations
//    let requestWorkers = operations.compactMap { $0 as? HTTPRequestWorker }
    let requestWorkers = coordinator.weakHTTPRequestWorkers.allObjects
    
    for requestWorker in requestWorkers {
      dbgPrint("requestWorker.dataTask = \(requestWorker.dataTask), dataTask = \(dataTask)")
      if requestWorker.dataTask?.taskIdentifier == dataTask.taskIdentifier  {
        return requestWorker
      }
    }
    return nil
  }
}
