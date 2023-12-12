//
//  UTType+AudioToolbox.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-12-12.
//
//  Copyright (c) 2023 Calvin Buckley
//  SPDX-License-Identifier: BSD-3-Clause
//  

import Foundation
import AudioToolbox
import UniformTypeIdentifiers

// on ref because that's how we present it for Objective-C
extension UTTypeReference {
    /// Gets the UTTypes of types supported by AudioToolbox.
    @objc static var audioToolboxTypes: [UTType] = {
        var types: Unmanaged<CFArray>? = nil
        var typesSize: UInt32 = UInt32(MemoryLayout<[CFString]>.size)
        guard AudioFileGetGlobalInfo(kAudioFileGlobalInfo_AllUTIs, 0, nil, &typesSize, &types) == noErr,
              let types = types else {
            // Not necessarily supported AudioToolbox, but better than nothing.
            return [UTType.audio]
        }
        return (types.takeRetainedValue() as! [String]).compactMap { type in UTType(type) }
    }()
}
