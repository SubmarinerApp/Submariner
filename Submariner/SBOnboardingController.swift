//
//  SBOnboardingController.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-01-27.
//  Copyright © 2023 Calvin Buckley. All rights reserved.
//

import Cocoa

@objc class SBOnboardingController: SBViewController {
    // annoyingly an optional because of the stupid coder ctor
    @objc var databaseController: SBDatabaseController? = nil
    
    @objc override init(managedObjectContext: NSManagedObjectContext) {
        super.init(managedObjectContext: managedObjectContext)
    }
    
    @objc required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    @objc static override func nibName() -> String! {
        "Onboarding"
    }
    
    @objc override func viewDidLoad() {
        title = "Welcome to Submariner"
        super.viewDidLoad()
    }
    
    @IBAction func addServer(_ sender: NSButton) {
        databaseController!.addServer(self)
    }
    
    @IBAction func createDemoServer(_ sender: NSButton) {
        databaseController!.createDemoServer(self)
    }
    
    @IBAction func openAudioFiles(_ sender: NSButton) {
        databaseController!.openAudioFiles(self)
    }
}
