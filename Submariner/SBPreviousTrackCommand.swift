//
//  SBPreviousTrackCommand.swift
//  Submariner
//
//  Created by Calvin Buckley on 2024-02-15.
//
//  Copyright (c) 2024 Calvin Buckley
//  SPDX-License-Identifier: BSD-3-Clause
//  

import Cocoa

@objc(SBPreviousTrackCommand) class SBPreviousTrackCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        SBPlayer.sharedInstance().previous()
    }
}
