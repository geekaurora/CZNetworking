import UIKit
import CZUtils
import CZNetworking

class ViewController: UIViewController {
  
  static let endpoint = "https://jsonplaceholder.typicode.com/posts"
  private let httManager: CZHTTPManager = CZHTTPManager.shared.maxConcurrencies(1)
  
  override func viewDidLoad() {
    super.viewDidLoad()    
    testFetch()
  }
  
  func testFetch() {
    (0..<5).forEach { _ in
      self.fetchFeeds()
    }
  }
  
  /// Fetch codable Feed array with json data.
  func fetchFeeds() {
    httManager.GETCodableModel(
      Self.endpoint,
      success: { (feeds: [Feed]) in
        dbgPrint("Succeed to fetch feeds: \n\(feeds.map { $0.id })")
    }, failure: { (error) in
      assertionFailure("Failed to fetch feeds. Error - \(error)")
    })
  }  
}

struct Feed: Codable {
  let userId: Int
  let id: Int
  let title: String
  let body: String
}
