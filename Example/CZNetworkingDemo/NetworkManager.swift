import UIKit
import CZUtils
import CZNetworking

class NetworkManager: NSObject, URLSessionDataDelegate {

  private var session: URLSession!

  func testHTTP3Request() {

    if self.session == nil {
      let config = URLSessionConfiguration.default
      config.requestCachePolicy = .reloadIgnoringLocalCacheData
      self.session = URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }

    let urlStr = "https://google.com"
    // Device: H3
    // let urlStr = "https://cloudflare-quic.com"

    let url = URL(string: urlStr)!
    var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60.0)

    // Enable HTTP3
    if #available(iOS 15, *) {
      print("Before: request.assumesHTTP3Capable = \(request.assumesHTTP3Capable)")
      request.assumesHTTP3Capable = true
    }


    print("task will start, url: \(url.absoluteString)")
    self.session.dataTask(with: request) { (data, response, error) in
      if let error = error as NSError? {
        print("task transport error \(error.domain) / \(error.code)")
        return
      }
      guard let data = data, let response = response as? HTTPURLResponse else {
        print("task response is invalid")
        return
      }

      guard 200 ..< 300 ~= response.statusCode else {
        print("task response status code is invalid; received \(response.statusCode), but expected 2xx")
        return
      }
      print("task finished with status \(response.statusCode), bytes \(data.count)")
    }.resume()

  }
}

extension NetworkManager {

  func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
    let protocols = metrics.transactionMetrics.map { $0.networkProtocolName ?? "-" }
    print("protocols: \(protocols)")
  }
}
