//
//  NSManagedObjectContext+Fetch.swift
//  Submariner
//
//  Created by Calvin Buckley on 2024-01-03.
//
//  Copyright (c) 2024 Calvin Buckley
//  SPDX-License-Identifier: BSD-3-Clause
//  

import CoreData

extension NSManagedObjectContext {
    /// Fetches a single object from Core Data, such as a singleton.
    ///
    /// It's not predictable what object it will fetch first. You should only be fetching singletons or where the predicate will only ever return a single object.
    @objc(fetchEntityNammed:withPredicate:error:) func fetch(entityNamed entityName: String, predicate: NSPredicate? = nil) throws -> NSManagedObject {
        // XXX: Make a generic version for Swift callers (if useful)
        return try synchronized(self) {
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            request.predicate = predicate
            
            let entities = try self.fetch(request)
            return entities.first!
        }
    }
}
