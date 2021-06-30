import Foundation
import CZUtils

public extension HTTPRequestWorker {  
  /// Request types of HTTPRequestWorker.
  enum RequestType: Equatable {
    case GET
    case POST(ContentType, Data?)
    case PUT
    case DELETE
    case UPLOAD(String, Data)
    case HEAD
    case PATCH
    case OPTIONS
    case TRACE
    case CONNECT
    case UNKNOWN
    
    var stringValue: String {
      switch self {
      case .GET: return "GET"
      case .POST: return "POST"
      case .PUT: return "PUT"
      case .DELETE: return "DELETE"
      case .UPLOAD: return "UPLOAD"
      default:
        assertionFailure("Unsupported type")
        return ""
      }
    }
    
    var hasSerializableUrl: Bool {
      switch self {
      case .GET, .PUT:
        return true
      default:
        return false
      }
    }
    
    public static func ==(lhs: RequestType, rhs: RequestType) -> Bool {
      switch (lhs, rhs) {
      case (.GET, .GET):
        return true
      case (.POST, .POST):
        return true
      case (.PUT, .PUT):
        return true
      case (.DELETE, .DELETE):
        return true
      case (.UPLOAD, .UPLOAD):
        return true
      default:
        return false
      }
    }
  }
}
