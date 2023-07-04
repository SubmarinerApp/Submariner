//
//  SBOperation.swift
//  Submariner
//
//  Created by Calvin Buckley on 2023-07-02.
//  Copyright © 2023 Submariner Developers. All rights reserved.
//

import Cocoa
import os

fileprivate let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "SBOperation")

class SBOperation: Operation {
    public let mainContext: NSManagedObjectContext
    public let threadedContext: NSManagedObjectContext
    
    init(managedObjectContext: NSManagedObjectContext) {
        self.mainContext = managedObjectContext
        self.threadedContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        self.threadedContext.persistentStoreCoordinator = self.mainContext.persistentStoreCoordinator
        self.threadedContext.mergePolicy = self.mainContext.mergePolicy
        self.threadedContext.retainsRegisteredObjects = true
        
        super.init()
    }
    
    // #MARK: Concurrency
    
    private var _isExecuting = false
    @objc dynamic override var isExecuting: Bool {
        get { return _isExecuting }
        set { _isExecuting = newValue }
    }
    
    private var _isFinished = false
    @objc dynamic override var isFinished: Bool {
        get { return _isFinished }
        set { _isFinished = newValue }
    }
    
    override var isConcurrent: Bool { true }
    
    public override func start() {
        if isCancelled {
            self.willChangeValue(forKey: "isFinished")
            isFinished = true
            self.didChangeValue(forKey: "isFinished")
            return
        }
        Thread.detachNewThread {
            self.main()
        }
        self.willChangeValue(forKey: "isExecuting")
        isExecuting = true
        self.didChangeValue(forKey: "isExecuting")
    }
    
    public func finish() {
        // TODO: Why do we have to do this if the propert is @objc dynamic?
        self.willChangeValue(forKey: "isFinished")
        self.willChangeValue(forKey: "isExecuting")
        isExecuting = false
        isFinished = true
        self.didChangeValue(forKey: "isExecuting")
        self.didChangeValue(forKey: "isFinished")
    }

    // #MARK: Core Data
    
    public func saveThreadedContext() {
        if self.threadedContext.hasChanges {
            logger.info("Changes to Core Data will be saved...")
            do {
                let observer = NotificationCenter.default.addObserver(forName: .NSManagedObjectContextDidSave, object: self.threadedContext, queue: nil) { notification in
                    logger.info("Merging changes onto main thread...")
                    DispatchQueue.main.async {
                        self.mainContext.mergeChanges(fromContextDidSave: notification)
                    }
                }
                try self.threadedContext.save()
                NotificationCenter.default.removeObserver(observer)
            } catch {
                logger.error("Failed to save: \(error, privacy: .public)")
            }
        }
        self.finish()
    }
}
