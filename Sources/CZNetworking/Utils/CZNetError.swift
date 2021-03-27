import UIKit
import Foundation
import CZUtils

/// Network Error class
open class CZNetError: CZError {
    private static let domain = "CZNetworking"
    public static let `default` = CZNetError("Network Error")
    public static let returnType = CZNetError("ReturnType Error")
    public static let parse = CZNetError("Parse Error")

    public init(_ description: String? = nil, code: Int = 99) {
        super.init(domain: CZNetError.domain, code: code, description: description)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
