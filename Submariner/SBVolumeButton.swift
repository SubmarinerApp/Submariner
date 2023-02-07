//
//  SBVolumeButton.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-02-07.
//  Copyright © 2023 Calvin Buckley. All rights reserved.
//

import Cocoa

@objc class SBVolumeButton: NSButton {
    @objc override func scrollWheel(with event: NSEvent) {
        // The trackpad gives us a (-)8 or so and slowly returns to zero.
        // Haven't tested wheel.
        guard event.deltaY != 0 else {
            return
        }
        let delta = Float(event.deltaY * 0.01);
        let oldVolume = SBPlayer.sharedInstance().volume()
        let newVolume = max(0, min(1, oldVolume + delta))
        SBPlayer.sharedInstance().setVolume(newVolume)
        // XXX: Display volume in popover/tooltip.
    }
}
