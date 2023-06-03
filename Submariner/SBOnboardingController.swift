//
//  SBOnboardingController.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-01-27.
//  Copyright © 2023 Calvin Buckley. All rights reserved.
//

import Cocoa
import SwiftUI

@objc class SBOnboardingController: SBViewController {
    // annoyingly an optional because of the stupid coder ctor
    @objc var databaseController: SBDatabaseController? = nil
    
    @objc static override func nibName() -> String! {
        nil
    }
    
    @objc override func loadView() {
        let rootView = OnboardingContentView(onboardingController: self)
        view = NSHostingView(rootView: rootView)
        // because the SwiftUI view doesn't take the whole space up,
        // we need this for window/sidebar adjustments to keep that view centred
        view.autoresizingMask = [.maxXMargin, .maxYMargin, .minXMargin, .minYMargin]
        
        title = "Welcome to Submariner"
    }
    
    struct OnboardingContentView: View {
        let onboardingController: SBOnboardingController
        
        var body: some View {
                VStack(alignment: .center) {
                    Image(nsImage: NSImage(named: "AppIcon")!)
                        .resizable()
                        .frame(width: 128, height: 128, alignment: .center)
                    Text("Welcome to Submariner")
                        .font(.largeTitle)
                        .padding(.top, 1)
                        .padding(.bottom, 0.25)
                    Text("Get started by connecting to a server, or manage your local music.")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 1)
                    
                    Button {
                        onboardingController.databaseController!.addServer(self)
                    } label: {
                        Text("Connect to a Server")
                            .frame(width: 250, height: 40)
                    }
                    .controlSize(.large)
                    .font(.title3)
                    .modify {
                        if #available(macOS 13, *) {
                            // XXX: For some reason, the tint isn't applying for the prominent button.
                            $0.tint(.accentColor)
                                .buttonStyle(.borderedProminent)
                        }
                    }
                    
                    Button {
                        onboardingController.databaseController!.createDemoServer(self)
                    } label: {
                        Text("Use Demo Server")
                            .frame(width: 250, height: 40)
                    }
                    .controlSize(.large)
                    .font(.title3)
                    
                    Button {
                        onboardingController.databaseController!.openAudioFiles(self)
                    } label: {
                        Text("Add Music to Local Library")
                            .frame(width: 250, height: 40)
                    }
                    .controlSize(.large)
                    .font(.title3)
                }
                .padding(50)
                .frame(maxWidth: .infinity)
        }
    }
}
