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

@class SBSourceListViewItem;
@class SBSourceListRowView;
@class SBEditServerController;
@class SBAddServerPlaylistController;
@class SBJumpToTimestampController;
@class SBPlayRateController;
@class SBMusicController;
@class SBMusicSearchController;
@class SBServerSearchController;
@class SBDownloadsController;
@class SBServerUserViewController;
@class SBServerSearchController;
@class SBServerDirectoryController;
@class SBInspectorController;
@class SBTracklistController;
@class SBPlaylistController;
@class SBLibrary;
@class SBAnimatedView;
@class SBVolumeButton;

#define SBLibraryTableViewDataType @"com.submarinerapp.item-url-list"
#define SBLibraryItemTableViewDataType @"com.submarinerapp.item-url-string"

// forward declarations for Swift classes (otherwise it's painful to reference,
// the swift bridging header can only be included in the impl)
@class SBRoutePickerView, SBOnboardingController, SBTracklistButton;
@protocol SBStarrable;

@interface SBDatabaseController : SBWindowController <NSWindowDelegate, NSOutlineViewDelegate, NSOutlineViewDataSource, NSPageControllerDelegate, NSMenuDelegate> {
@private
    IBOutlet NSView *titleView;
    IBOutlet NSView *hostView;
    IBOutlet NSSplitView *mainSplitView;
    IBOutlet NSSplitView *titleSplitView;
    IBOutlet NSSplitView *coverSplitView;
    IBOutlet NSImageView *handleSplitView;
    IBOutlet NSOutlineView *sourceList;
    IBOutlet NSTreeController *resourcesController;
    IBOutlet SBEditServerController *editServerController;
    SBJumpToTimestampController *jumpToTimestampController;
    SBPlayRateController *playRateController;
    SBAddServerPlaylistController *addServerPlaylistController;
    IBOutlet NSProgressIndicator *progressIndicator;
    IBOutlet NSButton *toggleButton;
    IBOutlet NSTextField *durationTextField;
    IBOutlet NSTextField *progressTextField;
    IBOutlet NSSlider *progressSlider;
    IBOutlet NSButton *playPauseButton;
    
    IBOutlet NSViewController *leftVC;
    IBOutlet NSPageController *rightVC;
    NSSplitViewController *splitVC;
    NSSplitViewItem *tracklistSplit;
    
    IBOutlet NSViewController *tracklistVC;
    IBOutlet NSBox *tracklistContainmentBox;
    
    IBOutlet SBRoutePickerView *routePicker;
    IBOutlet NSToolbarItem *routePickerToolbarItem;
    __weak IBOutlet NSToolbarItem *volumeToolbarItem;
    IBOutlet SBVolumeButton *volumeButton;
    IBOutlet NSPopover *volumePopover;
    IBOutlet SBTracklistButton *tracklistButton;
    IBOutlet NSSearchField *searchField;
    IBOutlet NSSearchToolbarItem *searchToolbarItem;
    
    SBOnboardingController *onboardingController;
    SBMusicController *musicController;
    SBDownloadsController *downloadsController;
    SBTracklistController *tracklistController;
    SBPlaylistController *playlistController;
    // additional controllers
    SBMusicSearchController *musicSearchController;
    SBServerLibraryController *serverLibraryController;
    SBServerHomeController *serverHomeController;
    SBServerDirectoryController *serverDirectoryController;
    SBServerPodcastController *serverPodcastController;
    SBServerUserViewController *serverUserController;
    SBServerSearchController *serverSearchController;
    SBInspectorController *inspectorController;
    
    NSArray *resourceSortDescriptors;
    SBLibrary *library;
    
    CATransition *transition;
    
    NSTimer *progressUpdateTimer;
    
    /// Used for changing the source list selection without updating the view state, for when the view state update needs to sync its changes to the source list.
    BOOL ignoreNextSelection;
}

@property (readwrite, strong) NSArray *resourceSortDescriptors;
@property (readwrite, strong) IBOutlet SBAddServerPlaylistController *addServerPlaylistController;
@property (readwrite, strong) SBLibrary *library;
// XXX: Make as part of SBServerController?
@property (readwrite, strong) SBServer *server;

@property (readonly, strong) IBOutlet NSNumber *isTracklistShown;
@property (readonly, strong) IBOutlet NSNumber *isServerUsersShown;
@property (readonly, strong) IBOutlet NSNumber *isInspectorShown;

@property (nonatomic, strong, readonly) NSArray<id<SBStarrable>> *selectedMusicItems;
@property (readonly) BOOL hasSelectedMusicItems;
@property (readwrite) NSControlStateValue selectedMusicItemsStarred;

- (BOOL)openImportAlert:(NSWindow *)sender files:(NSArray<NSURL*> *)files;

- (void)goToTrack: (SBTrack*)track;

- (IBAction)showDownloadView:(id)sender;
- (IBAction)showLibraryView:(id)sender;

- (void)getTopTracksFor:(NSString*)artistName;
- (void)getSimilarTracksTo:(SBArtist*)artist;

- (IBAction)openAudioFiles:(id)sender;
- (IBAction)toggleTrackList:(id)sender;
- (IBAction)toggleServerUsers:(id)sender;
- (IBAction)toggleInspector:(id)sender;
- (IBAction)addPlaylist:(id)sender;
- (IBAction)addRemotePlaylist:(id)sender;
- (IBAction)addPlaylistToCurrentServer:(id)sender;
- (IBAction)addServer:(id)sender;
- (IBAction)editItem:(id)sender;
- (IBAction)removeItem:(id)sender;
- (IBAction)reloadServer:(id)sender;
- (IBAction)reloadCurrentServer:(id)sender;
- (IBAction)scanCurrentLibrary:(id)sender;
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
- (IBAction)showDirectories:(id)sender;
- (IBAction)showSongs:(id)sender;
- (IBAction)showPodcasts:(id)sender;
- (IBAction)cleanTracklist:(id)sender;
- (IBAction)goToCurrentTrack:(id)sender;
- (IBAction)renameItem:(id)sender;
- (IBAction)createDemoServer:(id)sender;
- (IBAction)jumpToTimestamp:(id)sender;

- (IBAction)outlineViewTextFieldAction:(id)sender;

// NSUserInterfaceValidations protocol is implemented by AppDelegate, but logic lives here
- (BOOL)validateUserInterfaceItem: (id<NSValidatedUserInterfaceItem>) item;

@end
