//
//  SBLibraryController.h
//  Sub
//
//  Created by Rafaël Warnault on 04/06/11.
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

#import <Foundation/Foundation.h>
#import <Quartz/Quartz.h>
#import "SBWindowController.h"
#import "SBMusicSearchController.h"
#import "SBServerLibraryController.h"
#import "SBServerHomeController.h"
#import "SBServerPodcastController.h"
#import "SBServerUserViewController.h"
#import "SBServerSearchController.h"
#import "SBSourceList.h"

@class SBSplitView;
@class SBSourceList;
@class SBEditServerController;
@class SBAddServerPlaylistController;
@class SBMusicController;
@class SBMusicSearchController;
@class SBServerSearchController;
@class SBDownloadsController;
@class SBTracklistController;
@class SBPlaylistController;
@class SBLibrary;
@class SBAnimatedView;


#define SBLibraryTableViewDataType @"SBLibraryTableViewDataType"


@interface SBDatabaseController : SBWindowController <NSWindowDelegate, SBSourceListDelegate, SBSourceListDataSource> {
@private
    IBOutlet NSView *titleView;
    IBOutlet NSView *hostView;
    IBOutlet SBSplitView *mainSplitView;
    IBOutlet SBSplitView *titleSplitView;   
    IBOutlet NSSplitView *coverSplitView;
    IBOutlet NSImageView *handleSplitView;
    IBOutlet SBSourceList *sourceList;
    IBOutlet NSTreeController *resourcesController;
    IBOutlet SBEditServerController *editServerController;
    SBAddServerPlaylistController *addServerPlaylistController;
    IBOutlet SBViewController *currentViewController;
    IBOutlet NSProgressIndicator *progressIndicator;
    IBOutlet NSButton *toggleButton;
    IBOutlet NSTextField *durationTextField;
    IBOutlet NSTextField *progressTextField;
    IBOutlet NSSlider *progressSlider;
    IBOutlet NSImageView *coverImageView;
    IBOutlet NSButton *playPauseButton;
    
    IBOutlet NSViewController *leftVC;
    IBOutlet NSViewController *rightVC;
    NSSplitViewController *splitVC;
    NSSplitViewItem *tracklistSplit;
    
    IBOutlet NSViewController *tracklistVC;
    IBOutlet NSBox *tracklistContainmentBox;
    
    __weak IBOutlet NSToolbarItem *volumeToolbarItem;
    IBOutlet NSButton *volumeButton;
    IBOutlet NSPopover *volumePopover;
    IBOutlet NSSearchField *searchField;
    IBOutlet NSSearchToolbarItem *searchToolbarItem;
    
    IBOutlet NSPanel *onboardingWindow;
    
    SBMusicController *musicController;
    SBDownloadsController *downloadsController;
    SBTracklistController *tracklistController;
    SBPlaylistController *playlistController;
    // additional controllers
    SBMusicSearchController *musicSearchController;
    SBServerLibraryController *serverLibraryController;
    SBServerHomeController *serverHomeController;
    SBServerPodcastController *serverPodcastController;
    SBServerUserViewController *serverUserController;
    SBServerSearchController *serverSearchController;
    
    NSArray *resourceSortDescriptors;
    SBLibrary *library;
    
    CATransition *transition;
    
    NSTimer *progressUpdateTimer;
}

@property (readwrite, strong) NSArray *resourceSortDescriptors;
@property (readwrite, strong) IBOutlet SBViewController *currentViewController;
@property (readwrite, strong) IBOutlet SBAddServerPlaylistController *addServerPlaylistController;
@property (readwrite, strong) SBLibrary *library;
// XXX: Make as part of SBServerController?
@property (readwrite, strong) SBServer *server;

- (void)setCurrentViewController:(SBViewController *)newView;
- (BOOL)openImportAlert:(NSWindow *)sender files:(NSArray *)files;

- (void)goToTrack: (SBTrack*)track;

- (IBAction)showDownloadView:(id)sender;
- (IBAction)showLibraryView:(id)sender;

- (IBAction)openAudioFiles:(id)sender;
- (IBAction)toggleTrackList:(id)sender;
- (IBAction)toggleServerUsers:(id)sender;
- (IBAction)addPlaylist:(id)sender;
- (IBAction)addRemotePlaylist:(id)sender;
- (IBAction)addPlaylistToCurrentServer:(id)sender;
- (IBAction)addServer:(id)sender;
- (IBAction)editItem:(id)sender;
- (IBAction)removeItem:(id)sender;
- (IBAction)deleteRemotePlaylist:(id)sender;
- (IBAction)reloadServer:(id)sender;
- (IBAction)reloadCurrentServer:(id)sender;
- (IBAction)playPause:(id)sender;
- (IBAction)stop:(id)sender;
- (IBAction)nextTrack:(id)sender;
- (IBAction)previousTrack:(id)sender;
- (IBAction)seekTime:(id)sender;
- (IBAction)rewind:(id)sender;
- (IBAction)fastForward:(id)sender;
- (IBAction)setVolume:(id)sender;
- (IBAction)setMuteOn:(id)sender;
- (IBAction)setMuteOff:(id)sender;
- (IBAction)volumeUp:(id)sender;
- (IBAction)volumeDown:(id)sender;
- (IBAction)openHomePage:(id)sender;
- (IBAction)openCurrentServerHomePage:(id)sender;
- (IBAction)configureCurrentServer:(id)sender;
- (IBAction)shuffle:(id)sender;
- (IBAction)repeatNone:(id)sender;
- (IBAction)repeatOne:(id)sender;
- (IBAction)repeatAll:(id)sender;
- (IBAction)repeat:(id)sender;
- (IBAction)search:(id)sender;
- (IBAction)showIndices:(id)sender;
- (IBAction)showAlbums:(id)sender;
- (IBAction)showPodcasts:(id)sender;
- (IBAction)cleanTracklist:(id)sender;
- (IBAction)goToCurrentTrack:(id)sender;
- (IBAction)renameItem:(id)sender;

// NSUserInterfaceValidations protocol is implemented by AppDelegate, but logic lives here
- (BOOL)validateUserInterfaceItem: (id<NSValidatedUserInterfaceItem>) item;

@end
