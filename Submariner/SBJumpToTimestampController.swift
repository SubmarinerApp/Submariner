//
//  SBJumpToTimestampController.swift
//  Submariner
//
//  Created by Calvin Buckley on 2024-07-04.
//
//  Copyright (c) 2024 Calvin Buckley
//  SPDX-License-Identifier: BSD-3-Clause
//  

import Cocoa
import SwiftUI

@objc class SBJumpToTimestampController: SBSheetController {
    var newTimestampString: String?
    
    override func openSheet(_ sender: Any!) {
        let timestampString = SBPlayer.sharedInstance().currentTimeString
        let viewController = NSHostingController(rootView: JumpToTimestampView(jumpToTimestampController: self, timestampString: timestampString))
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
    
    struct JumpToTimestampView: View {
        weak var jumpToTimestampController: SBJumpToTimestampController!
        
        @State var timestampString: String = ""
        
        var body: some View {
            VStack {
                Form {
                    TextField(text: $timestampString) {
                        Text("Timestamp")
                    }
                }
                HStack {
                    Spacer()
                    Button {
                        jumpToTimestampController.closeSheet(jumpToTimestampController)
                    } label: {
                        Text("Cancel")
                    }
                    .keyboardShortcut(.cancelAction)
                    Button {
                        jumpToTimestampController.newTimestampString = timestampString
                        jumpToTimestampController.closeSheet(jumpToTimestampController)
                    } label: {
                        Text("Seek")
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
        }
    }
}
