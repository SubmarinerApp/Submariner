//
//  NSString+Hex.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-02-07.
//  Copyright © 2023 Calvin Buckley. All rights reserved.
//

import Cocoa
import CryptoKit

@objc extension NSString {
    @objc func md5() -> NSString? {
        if let data = self.data(using: NSUTF8StringEncoding) {
            let hash = Insecure.MD5.hash(data: data)
            // stringify
            let str = hash.map({ String(format: "%02x", $0) }).joined() as NSString
            return str
        }
        return nil
    }
    
    @objc func toHex() -> NSString? {
        if let data = self.data(using: NSUTF8StringEncoding) as NSData? {
            return NSString.hexStringFrom(bytes: data)
        }
        return nil
    }
    
    @objc static func hexStringFrom(bytes: NSData) -> NSString {
        let data = bytes as Data
        let joined = data.map({ String(format: "%02x", $0) }).joined() as NSString
        return joined
    }
}
