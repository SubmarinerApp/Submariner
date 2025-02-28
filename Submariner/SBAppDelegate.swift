//
//  SBAppDelegate.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-06-17.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//

import Cocoa
import os

fileprivate let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SBAppDelegate")

@main
@objc(SBAppDelegate) class SBAppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSUserInterfaceValidations {
    
    // #MARK: - Initialization
    
    @objc let databaseController: SBDatabaseController
    let preferencesController: SBPreferencesController
    
    override init() {
        // #MARK: Init User Defaults
        let defaults: [String: Any] = [
            "clientIdentifier": "submariner",
            "apiVersion": "1.16.1",
            "playerBehavior": NSNumber(value: 1),
            "playerVolume": NSNumber(value: 0.5),
            "repeatMode": NSNumber(value: SBPlayer.RepeatMode.no.rawValue),
            "shuffle": NSNumber(value: false),
            "enableCacheStreaming": NSNumber(value: true),
            "autoRefreshNowPlaying": NSNumber(value: false),
            "coverSize": NSNumber(value: 0.75),
            "maxBitRate": NSNumber(value: 0),
            "MaxCoverSize": NSNumber(value: 300),
            "scrobbleToServer": NSNumber(value: true),
            "deleteAfterPlay": NSNumber(value: false),
            "SkipIncrement": NSNumber(value: 5.0),
            "albumSortOrder": "OldestFirst",
            "canLinkImport": NSNumber(value: false),
            "playRate": NSNumber(value: 1.0),
        ]
        UserDefaults.standard.register(defaults: defaults)
        
        // #MARK: Init Value Transformers
        // other NSVTs are found by objc runtime by name
        let noneTrans = SBRepeatModeTransformer(mode: .no)
        let noneTransName = NSValueTransformerName(rawValue: "SBRepeatModeNoneTransformer")
        ValueTransformer.setValueTransformer(noneTrans, forName: noneTransName)
        let oneTrans = SBRepeatModeTransformer(mode: .one)
        let oneTransName = NSValueTransformerName(rawValue: "SBRepeatModeOneTransformer")
        ValueTransformer.setValueTransformer(oneTrans, forName: oneTransName)
        let allTrans = SBRepeatModeTransformer(mode: .all)
        let allTransName = NSValueTransformerName(rawValue: "SBRepeatModeAllTransformer")
        ValueTransformer.setValueTransformer(allTrans, forName: allTransName)
        
        let tracklistTrans = SBToggleNameTransformer(name: "Tracklist")
        let tracklistTransName = NSValueTransformerName(rawValue: "SBToggleTracklistNameTransformer")
        ValueTransformer.setValueTransformer(tracklistTrans, forName: tracklistTransName)
        let serverUsersTrans = SBToggleNameTransformer(name: "Server Users")
        let serverUsersTransName = NSValueTransformerName(rawValue: "SBToggleServerUsersNameTransformer")
        ValueTransformer.setValueTransformer(serverUsersTrans, forName: serverUsersTransName)
        let inspectorTrans = SBToggleNameTransformer(name: "Inspector")
        let inspectorTransName = NSValueTransformerName(rawValue: "SBToggleInspectorNameTransformer")
        ValueTransformer.setValueTransformer(inspectorTrans, forName: inspectorTransName)
        
        // #MARK: Init Core Data (managed object model)
        let modelURL = Bundle.main.url(forResource: "Submariner", withExtension: "momd")!
        self.managedObjectModel = NSManagedObjectModel(contentsOf: modelURL)!
        
        // #MARK: Init Core Data (persistent store coordinator)
        self.persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let storeOpts = [
            NSInferMappingModelAutomaticallyOption: true,
            NSMigratePersistentStoresAutomaticallyOption: true
        ]
        // check if the model needs a migration; we let Core Data do lightweight migrations and let us handle heavyweight,
        // but we should probably invalidate object IDs in the defaults DB. migration should handle OIDs in the store.
        // if we were doing the migration manually we could try to convert the ID, but we don't have this control with
        // NSMigratePersistentStoresAutomaticallyOption.
        let newURL = SBAppDelegate.storeFileName
        if let metadata = try? NSPersistentStoreCoordinator.metadataForPersistentStore(type: .sqlite, at: newURL),
           !self.managedObjectModel.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata) {
            // SBDatabaseController defaults to local music for now
            UserDefaults.standard.removeObject(forKey: "LastViewedResource")
        }
        // we no longer migrate from Submariner 1.x stores. use 3.1.1 or older first beforehand
        _ = try! self.persistentStoreCoordinator.addPersistentStore(type: .sqlite,
                                                                    configuration: nil,
                                                                    at: newURL,
                                                                    options: storeOpts)
        
        // #MARK: Init Core Data (managed object store)
        // must be main queue for SwiftUI
        self.managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        self.managedObjectContext.persistentStoreCoordinator = self.persistentStoreCoordinator
        
        // #MARK: Run cleanup steps
        let cleanupOrphansOperation = SBLibraryCleanupOrphansOperation(managedObjectContext: self.managedObjectContext)
        OperationQueue.sharedServerQueue.addOperation(cleanupOrphansOperation)
        let cleanupCoverPathsOperation = SBLibraryCleanupCoverPathsOperation(managedObjectContext: self.managedObjectContext)
        OperationQueue.sharedServerQueue.addOperation(cleanupCoverPathsOperation)
        
        // #MARK: Init Window Controllers
        self.databaseController = SBDatabaseController(managedObjectContext: self.managedObjectContext)
        self.preferencesController = SBPreferencesController()
    }
    
    // #MARK: - NSApplicationDelegate
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        zoomDatabaseWindow(self)
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        SBPlayer.sharedInstance().stop()
        
        // If we have database corruption, we're screwed anyways and shouldn't put the user in an infinite loop.
        if !managedObjectContext.commitEditing() {
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "Failed to Commit Changes"
            alert.informativeText = "Submariner failed to commit changes to the local database while exiting."
            alert.runModal()
            return .terminateNow
        }
        
        if !managedObjectContext.hasChanges {
            return .terminateNow
        }
        
        do {
            try managedObjectContext.save()
        } catch {
            if NSApplication.shared.presentError(error) {
                return .terminateCancel
            }
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "Could not save changes while quitting. Quit anyway?"
            alert.informativeText = "Quitting now will lose any changes you have made since the last successful save."
            alert.addButton(withTitle: "Quit")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() == .alertSecondButtonReturn {
                return .terminateCancel
            }
        }
        
        return .terminateNow
    }
    
    // XXX: this is called on launch, but is it needed?
    func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
        zoomDatabaseWindow(self)
        return false
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        databaseController.openImportAlert(databaseController.window, files: urls)
    }
    
    // #MARK: - Application Files/Directories
    
    @objc static var musicDirectory: URL {
        let path = FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).last!.appendingPathComponent("Submariner/Music")
        if !FileManager.default.fileExists(atPath: path.path) {
            try! FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        }
        return path
    }
    
    @objc static var coverDirectory: URL {
        let path = FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).last!.appendingPathComponent("Submariner/Covers")
        if !FileManager.default.fileExists(atPath: path.path) {
            try! FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        }
        return path
    }
    
    static var storeFileName: URL {
        let baseURL = FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).last!.appendingPathComponent("Submariner")
        let path = FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).last!.appendingPathComponent("Submariner/Submariner Library.sqlite")
        if !FileManager.default.fileExists(atPath: baseURL.path) {
            try! FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
        }
        return path
    }
    
    // #MARK: - Outlets
    
    @IBAction func showWebsite(_ sender: Any?) {
        NSWorkspace.shared.open(URL(string: "https://submarinerapp.com")!)
    }
    
    @IBAction func saveAction(_ sender: Any?) {
        if managedObjectContext.hasChanges {
            do {
                managedObjectContext.commitEditing()
                try managedObjectContext.save()
            } catch {
                NSApplication.shared.presentError(error)
            }
        }
    }
    
    @IBAction func zoomDatabaseWindow(_ sender: Any?) {
        databaseController.window?.makeKeyAndOrderFront(sender)
    }
    
    @IBAction func openPreferences(_ sender: Any?) {
        preferencesController.showWindow(sender)
    }
    
    @IBAction func openDatabase(_ sender: Any?) {
        databaseController.showWindow(sender)
    }
    
    @IBAction func openAudioFiles(_ sender: Any?) {
        databaseController.openAudioFiles(sender)
    }
    
    @IBAction func newPlaylist(_ sender: Any?) {
        databaseController.addPlaylist(sender)
    }
    
    @IBAction func addPlaylistToCurrentServer(_ sender: Any?) {
        databaseController.addPlaylistToCurrentServer(sender)
    }
    
    @IBAction func newServer(_ sender: Any?) {
        databaseController.addServer(sender)
    }
    
    @IBAction func toogleTracklist(_ sender: Any?) {
        databaseController.toggleTrackList(sender)
    }
    
    @IBAction func toggleServerUsers(_ sender: Any?) {
        databaseController.toggleServerUsers(sender)
    }
    
    @IBAction func playPause(_ sender: Any?) {
        databaseController.playPause(sender)
    }
    
    @IBAction func stop(_ sender: Any?) {
        databaseController.stop(sender)
    }
    
    @IBAction func nextTrack(_ sender: Any?) {
        databaseController.nextTrack(sender)
    }
    
    @IBAction func previousTrack(_ sender: Any?) {
        databaseController.previousTrack(sender)
    }
    
    @IBAction func repeatNone(_ sender: Any?) {
        databaseController.repeatNone(sender)
    }
    
    @IBAction func repeatOne(_ sender: Any?) {
        databaseController.repeatOne(sender)
    }
    
    @IBAction func repeatAll(_ sender: Any?) {
        databaseController.repeatAll(sender)
    }
    
    @IBAction func repeatModeCycle(_ sender: Any?) {
        databaseController.repeat(sender)
    }
    
    @IBAction func toggleShuffle(_ sender: Any?) {
        databaseController.shuffle(sender)
    }
    
    @IBAction func rewind(_ sender: Any?) {
        databaseController.rewind(sender)
    }
    
    @IBAction func fastForward(_ sender: Any?) {
        databaseController.fastForward(sender)
    }
    
    @IBAction func setMuteOn(_ sender: Any?) {
        databaseController.setMuteOn(sender)
    }
    
    @IBAction func volumeUp(_ sender: Any?) {
        databaseController.volumeUp(sender)
    }
    
    @IBAction func volumeDown(_ sender: Any?) {
        databaseController.volumeDown(sender)
    }
    
    @IBAction func search(_ sender: Any?) {
        databaseController.search(sender)
    }
    
    @IBAction func showIndices(_ sender: Any?) {
        databaseController.showIndices(sender)
    }
    
    @IBAction func showAlbums(_ sender: Any?) {
        databaseController.showAlbums(sender)
    }
    
    @IBAction func showDirectories(_ sender: Any?) {
        databaseController.showDirectories(sender)
    }
    
    @IBAction func showPodcasts(_ sender: Any?) {
        databaseController.showPodcasts(sender)
    }
    
    @IBAction func cleanTracklist(_ sender: Any?) {
        databaseController.cleanTracklist(sender)
    }
    
    @IBAction func reloadCurrentServer(_ sender: Any?) {
        databaseController.reloadCurrentServer(sender)
    }
    
    @IBAction func openCurrentServerHomePage(_ sender: Any?) {
        databaseController.openCurrentServerHomePage(sender)
    }
    
    @IBAction func goToCurrentTrack(_ sender: Any?) {
        databaseController.goToCurrentTrack(sender)
    }
    
    @IBAction func renameItem(_ sender: Any?) {
        databaseController.renameItem(sender)
    }
    
    @IBAction func configureCurrentServer(_ sender: Any?) {
        databaseController.configureCurrentServer(sender)
    }
    
    @IBAction func scanCurrentLibrary(_ sender: Any?) {
        databaseController.scanCurrentLibrary(sender)
    }
    
    @IBAction func purgeLocalLibrary(_ sender: Any?) {
        let operation = SBLibraryPurgeOperation(managedObjectContext: managedObjectContext)
        OperationQueue.sharedServerQueue.addOperation(operation)
    }
    
    // #MARK: - Core Data
    
    @objc let managedObjectModel: NSManagedObjectModel
    @objc let persistentStoreCoordinator: NSPersistentStoreCoordinator
    @objc let managedObjectContext: NSManagedObjectContext
    
    // #MARK: - UI Validation
    
    func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        return databaseController.validate(item)
    }
}
