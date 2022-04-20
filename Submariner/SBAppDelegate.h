//
//  SubmarinerAppDelegate.h
//  Submariner
//
//  Created by Rafaël Warnault on 06/06/11.
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

#import <Cocoa/Cocoa.h>

@class SBPreferencesController;
@class SBDatabaseController;
@class DDHotKeyCenter;

@interface SBAppDelegate : NSObject <NSApplicationDelegate, NSMenuDelegate, NSUserInterfaceValidations> {
@private
    // Core Data
    NSPersistentStoreCoordinator *__persistentStoreCoordinator;
    NSManagedObjectModel *__managedObjectModel;
    NSManagedObjectContext *__managedObjectContext;

    // Controllers
    SBPreferencesController *preferencesController;   
    SBDatabaseController *databaseController;
        
    // Status Menu
    NSStatusItem *statusItem;
    IBOutlet NSMenu *statusMenu;
}

@property (nonatomic, retain, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (nonatomic, retain, readonly) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, retain, readonly) NSManagedObjectContext *managedObjectContext;

+ (id)sharedInstance;

- (NSURL *)applicationFilesDirectory;
- (NSString *)musicDirectory;
- (NSString *)coverDirectory;

- (IBAction)openAudioFiles:(id)sender;
- (IBAction)saveAction:(id)sender;
- (IBAction)openPreferences:(id)sender;
- (IBAction)zoomDatabaseWindow:(id)sender;
- (IBAction)toogleTracklist:(id)sender;
- (IBAction)newPlaylist:(id)sender;
- (IBAction)newServer:(id)sender;
- (IBAction)playPause:(id)sender;
- (IBAction)stop:(id)sender;
- (IBAction)nextTrack:(id)sender;
- (IBAction)previousTrack:(id)sender;
- (IBAction)showWebsite:(id)sender;
- (IBAction)playTrackForMenuItem:(id)sender;

@end
