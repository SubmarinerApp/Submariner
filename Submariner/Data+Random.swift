//
//  Data+Random.swift
//  Submariner
//
//  Created by Calvin Buckley on 2024-02-14.
//
//  Copyright (c) 2024 Calvin Buckley
//  SPDX-License-Identifier: BSD-3-Clause
//  

import Foundation

extension Data {
    init?(randomByteCount count: Data.Index) {
        self.init(count: count)
        let saltResult = self.withUnsafeMutableBytes { mutableData in
            let bufferPointer = mutableData.bindMemory(to: UInt8.self)
            return SecRandomCopyBytes(kSecRandomDefault, count, bufferPointer.baseAddress!)
        }
        if saltResult != errSecSuccess {
            return nil
        }
    }
}
