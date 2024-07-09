//
//  SBPlayRateController.swift
//  Submariner
//
//  Created by Calvin Buckley on 2024-07-09.
//
//  Copyright (c) 2024 Calvin Buckley
//  SPDX-License-Identifier: BSD-3-Clause
//  

import Cocoa
import SwiftUI

@objc class SBPlayRateController: SBSheetController {
    var newTimestampString: String?
    
    override func openSheet(_ sender: Any!) {
        let timestampString = SBPlayer.sharedInstance().currentTimeString
        let viewController = NSHostingController(rootView: PlayRateControllerView(playRateController: self))
        let sheet = NSWindow(contentViewController: viewController)
        sheet.hasShadow = true
        sheet.isReleasedWhenClosed = true
        // This is pretty gross and based on vibes, but not sure how to get the content size;
        // preferredContentSize seems to be small as possible.
        sheet.setContentSize(NSSize(width: 300, height: 100))
        self.sheet = sheet
    
        super.openSheet(sender)
    }
    
    override func closeSheet(_ sender: Any!) {
        // TODO: Put some effort into parsing?
        if let newTimestampString = self.newTimestampString {
            SBPlayer.sharedInstance().seek(to: newTimestampString.toTimeInterval())
        }
        
        super.closeSheet(sender)
    }
    
    struct PlayRateControllerView: View {
        weak var playRateController: SBPlayRateController!
        
        @AppStorage("playRate") private var playRate: Double = 1.0
        
        var body: some View {
            VStack {
                Form {
                    Slider(value: $playRate, in: 0.5...2, step: 0.25) {
                        Text("Playback Speed")
                    } minimumValueLabel: {
                        Text("0.5")
                    } maximumValueLabel: {
                        Text("2")
                    }
                }
                HStack {
                    Button {
                        playRate = 1.0
                    } label: {
                        Text("Reset")
                    }
                    Spacer()
                    Button {
                        playRateController.closeSheet(playRateController)
                    } label: {
                        Text("OK")
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
        }
    }
}

