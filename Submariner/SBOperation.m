//
//  SBOperation.m
//  Submariner
//
//  Created by Rafaël Warnault on 24/08/11.
//
//  Copyright (c) 2011-2014, Rafaël Warnault
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  * Redistributions of source code must retain the above copyright notice, this
//  list of conditions and the following disclaimer.
//
//  * Redistributions in binary form must reproduce the above copyright notice,
//  this list of conditions and the following disclaimer in the documentation
//  and/or other materials provided with the distribution.
//
//  * Neither the name of the Read-Write.fr nor the names of its
//  contributors may be used to endorse or promote products derived from
//  this software without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
//  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
//  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
//  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//  OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
//  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "SBOperation.h"



@interface SBOperation(PrivateMethods)
- (void)mergeThreadedContextChangesIntoMainContext:(NSNotification *)notification;
@end



@implementation SBOperation


@synthesize mainContext = mainContext_;
@synthesize threadedContext = threadedContext_;



#pragma mark -
#pragma mark LifeCycle

- (id)initWithManagedObjectContext:(NSManagedObjectContext *)context {
    if ((self = [super init])) {
        mainContext_  = context;
        executing = NO;
        finished = NO;
    }

    return self;
}





#pragma mark -
#pragma mark Concurrency

- (BOOL)isConcurrent
{
    return YES;
}


- (BOOL)isFinished {
    return finished;
}


- (BOOL)isExecuting {
    return executing;
}




#pragma mark -
#pragma mark Helper

/* Respect Apple guidelines, this operation can run concurrently */
- (void)start {
    // Always check for cancellation before launching the task.
    if ([self isCancelled])
    {
        // Must move the operation to the finished state if it is canceled.
        [self willChangeValueForKey:@"isFinished"];
        finished = YES;
        [self didChangeValueForKey:@"isFinished"];
        return;
    }
    
    // If the operation is not canceled, begin executing the task.
    [self willChangeValueForKey:@"isExecuting"];
    [NSThread detachNewThreadSelector:@selector(main) toTarget:self withObject:nil];
    executing = YES;
    [self didChangeValueForKey:@"isExecuting"];
}


- (void)finish
{    
    [self willChangeValueForKey:@"isFinished"];
    [self willChangeValueForKey:@"isExecuting"];
    
    executing = NO;
    finished = YES;
    
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}





#pragma mark -
#pragma mark CoreData Operation

- (NSManagedObjectContext*)threadedContext {
    if (!threadedContext_) {
        threadedContext_ = [[NSManagedObjectContext alloc] initWithConcurrencyType: NSPrivateQueueConcurrencyType];
        [threadedContext_ setPersistentStoreCoordinator:[mainContext_ persistentStoreCoordinator]];
        [threadedContext_ setMergePolicy:[mainContext_ mergePolicy]];
        [threadedContext_ setRetainsRegisteredObjects:YES];
    }
    return threadedContext_;
}

- (void)saveThreadedContext {
    
//    if(![NSThread isMainThread]) {
//        [self performSelectorOnMainThread:@selector(saveThreadedContext) 
//                               withObject:nil waitUntilDone:YES];
//    }
    
    NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
    
    if ([[self threadedContext] hasChanges]) {
                
        [defaultCenter addObserver:self
                          selector:@selector(mergeThreadedContextChangesIntoMainContext:)
                              name:NSManagedObjectContextDidSaveNotification
                            object:self.threadedContext];
#if DEBUG                
        NSLog(@"INFO : 1. New Data will be saved...");
#endif
        NSError *error = nil;


        BOOL contextDidSave = [[self threadedContext] save:&error];
        
        if (!contextDidSave) {
            
            // If the context failed to save, log out as many details as possible.
            NSLog(@"FATAL : Failed to save to data store: %@", [error localizedDescription]);
            
            NSArray* detailedErrors = [[error userInfo] objectForKey:NSDetailedErrorsKey];
            
            if (detailedErrors != nil && [detailedErrors count] > 0) {
                
                for (NSError* detailedError in detailedErrors) {
                    NSLog(@"  DetailedError: %@", [detailedError userInfo]);
                }
            } else {
                NSLog(@"  %@", [error userInfo]);
            }
        }
        
        [defaultCenter removeObserver:self name:NSManagedObjectContextDidSaveNotification object:[self threadedContext]];
    }
    [self finish];
}

#pragma mark -
#pragma mark PrivateMethods
- (void)mergeThreadedContextChangesIntoMainContext:(NSNotification *)notification {
    
#if DEBUG   
    NSLog(@"INFO : 2. Database Merging Changes...");
#endif
    
    if ([notification object] == mainContext_) {
        // main context save, no need to perform the merge
        return;
    }
    
    if(![NSThread isMainThread]) {
        [self performSelectorOnMainThread:@selector(mergeThreadedContextChangesIntoMainContext:) 
                               withObject:notification 
                            waitUntilDone:YES];
        return;
    }
    
    [mainContext_ performSelectorOnMainThread:@selector(mergeChangesFromContextDidSaveNotification:)
                                   withObject:notification
                                waitUntilDone:YES];
}



@end
