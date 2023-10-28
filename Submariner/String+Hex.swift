//
//  String+Hex.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-02-07.
//  Copyright © 2023 Calvin Buckley. All rights reserved.
//

import Cocoa
import CryptoKit

extension String {
    func md5() -> String? {
        if let data = self.data(using: .utf8) {
            let hash = Insecure.MD5.hash(data: data)
            // stringify
            let str = hash.map({ String(format: "%02x", $0) }).joined()
            return str
        }
        return nil
    }
    
    func toHex() -> String? {
        if let data = self.data(using: .utf8) {
            return String.hexStringFrom(bytes: data)
        }
        return nil
    }
    
    static func hexStringFrom(bytes: Data) -> String {
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}
