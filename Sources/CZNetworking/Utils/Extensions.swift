import Foundation
import CZUtils

public extension Data {
    public mutating func append(_ string: String, using encoding: String.Encoding = .utf8) {
        if let data = string.data(using: encoding) {
            append(data)
        }
    }
}

public extension UUID {
    public static func generate() -> String {
        return UUID().uuidString
    }
}
