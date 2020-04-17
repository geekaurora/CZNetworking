//
//  Extensions.swift
//  CZNetworking
//
//  Created by Cheng Zhang on 12/11/15.
//  Copyright © 2015 Cheng Zhang. All rights reserved.
//

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
