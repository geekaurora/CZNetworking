import UIKit
import CZUtils
import CZNetworking

class ViewController: UIViewController {
  
  static let endpoint = "https://www.bluharborbywindsor.com/floorplans/a2-w"
  private let httManager: CZHTTPManager = CZHTTPManager.shared.maxConcurrencies(1)
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    CZNetworkingConstants.shouldJoinOnFlightOperation = true
    testFetch()
  }
  
  func testFetch() {
    (0..<1).forEach { _ in
      self.fetchFeeds()
    }
  }
  
  /// Fetch codable Feed array with json data.
  func fetchFeeds() {
    httManager.GET(
      Self.endpoint,
//      headers: ["User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.109 Safari/537.36"],
      success: { data in
        let html_string =  String(data: data!, encoding: .utf8)
        print("html_string: \(html_string!)")

      }, failure: { (error) in
        assertionFailure("Failed to fetch feeds. Error - \(error)")
      })

//    httManager.GETCodableModel(
//      Self.endpoint,
//      success: { (feeds: [Feed], data) in
//        dbgPrint("Succeed to fetch feeds: \n\(feeds.map { $0.id })")
//      }, failure: { (error) in
//        assertionFailure("Failed to fetch feeds. Error - \(error)")
//      })
  }
}
