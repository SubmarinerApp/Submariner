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

extension NSNotification.Name {
    static let SBSubsonicOperationStarted = NSNotification.Name("SBSubsonicOperationStarted")
    static let SBSubsonicOperationFinished = NSNotification.Name("SBSubsonicOperationFinished")
}

class SBOperation: Operation, ObservableObject, Identifiable {
    public let mainContext: NSManagedObjectContext
    public let threadedContext: NSManagedObjectContext
    
    init(managedObjectContext: NSManagedObjectContext, name: String, author: String? = nil) {
        self.mainContext = managedObjectContext
        self.threadedContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        // For automatic merging to work, seems we need to associate with the parent MOC,
        // rather than attaching to the persistent store coordinator.
        self.threadedContext.parent = managedObjectContext
        self.threadedContext.automaticallyMergesChangesFromParent = true
        self.threadedContext.mergePolicy = self.mainContext.mergePolicy
        self.threadedContext.retainsRegisteredObjects = true
        self.threadedContext.transactionAuthor = author
        
        super.init()
        
        self.name = name
        
        // We have to publish these ourselves to anyone interested, because OperationCenter.operations is deprecated and racy.
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .SBSubsonicOperationStarted, object: self)
        }
    }
    
    // #MARK: - Metadata
    
    @Published var operationInfo: String = ""
    @Published var progress: Progress = .none
    
    enum Progress {
        case none
        case indeterminate(n: Float)
        case determinate(n: Float, outOf: Float)
    }
    
    // #MARK: - Concurrency
    
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
    override var isAsynchronous: Bool { true }
    
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
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .SBSubsonicOperationFinished, object: self)
        }
    }

    // #MARK: - Core Data
    
    public func saveThreadedContext() {
        if self.threadedContext.hasChanges {
            logger.info("Changes to Core Data will be saved...")
            do {
                // Merging is now done by NSManagedObjectContext.automaticallyMergesChangesFromParent
                try self.threadedContext.save()
            } catch {
                logger.error("Failed to save: \(error, privacy: .public)")
            }
        }
    }
}
