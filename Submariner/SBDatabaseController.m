//
//  SBLibraryController.m
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

#import "SBDatabaseController.h"
#import "SBAppDelegate.h"
#import "SBEditServerController.h"
#import "SBAddServerPlaylistController.h"
#import "SBMusicController.h"
#import "SBTracklistController.h"
#import "SBPlaylistController.h"
#import "SBDownloadsController.h"
#import "SBAnimatedView.h"
#import "SBImportOperation.h"
#import "SBSubsonicParsingOperation.h"
#import "SBSubsonicDownloadOperation.h"
#import "SBPlayer.h"
#import "SBTableView.h"

#import "SBSplitView.h"
#import "SBSection.h"
#import "SBTracklist.h"
#import "SBLibrary.h"
#import "SBServer.h"
#import "SBPlaylist.h"
#import "SBArtist.h"
#import "SBAlbum.h"
#import "SBTrack.h"
#import "SBDownloads.h"
#import "SBCover.h"

#import "NSManagedObjectContext+Fetch.h"
#import "NSOutlineView+Expand.h"
#import "NSOperationQueue+Shared.h"



// main split view constant
#define LEFT_VIEW_INDEX 0
#define LEFT_VIEW_PRIORITY 2
#define LEFT_VIEW_MINIMUM_WIDTH 150.0

#define MAIN_VIEW_INDEX 1
#define MAIN_VIEW_PRIORITY 0
#define MAIN_VIEW_MINIMUM_WIDTH 400.0





// my database controller private methods
@interface SBDatabaseController (Private)
- (void)populatedDefaultSections;
- (void)displayViewControllerForResource:(SBResource *)resource;
- (void)updateProgress:(NSTimer *)updatedTimer;

// notifications
- (void)subsonicPlaylistsUpdatedNotification:(NSNotification *)notification;
- (void)subsonicPlaylistsCreatedNotification:(NSNotification *)notification;
- (void)playerPlaylistUpdatedNotification:(NSNotification *)notification;
- (void)playerPlayStateNotification:(NSNotification *)notification;
- (void)playerHaveMovieToPlayNotification:(NSNotification *)notification;

- (void)subsonicConnectionFailed:(NSNotification *)notification;
- (void)subsonicConnectionSucceeded:(NSNotification *)notification;
- (void)subsonicIndexesUpdated:(NSNotification *)notification;
- (void)subsonicAlbumsUpdated:(NSNotification *)notification;
- (void)subsonicPlaylistsUpdated:(NSNotification *)notification;
- (void)subsonicPlaylistUpdated:(NSNotification *)notification;
- (void)subsonicChatMessageAdded:(NSNotification *)notification;
- (void)subsonicNowPlayingUpdated:(NSNotification *)notification;
- (void)subsonicUserInfoUpdated:(NSNotification *)notification;
@end




@implementation SBDatabaseController


@synthesize resourceSortDescriptors;
@synthesize addServerPlaylistController;
@synthesize currentViewController;
@synthesize library;


#pragma mark -
#pragma mark Class Methods

+ (NSString *)nibName
{
    return @"Database";
}





#pragma mark -
#pragma mark LifeCycle

- (id)initWithManagedObjectContext:(NSManagedObjectContext *)context {
    self = [super initWithManagedObjectContext:context];
    if (self) {
        // init sort descriptors
        NSSortDescriptor *sd1 = [NSSortDescriptor sortDescriptorWithKey:@"index" ascending:YES];
        resourceSortDescriptors = [NSMutableArray arrayWithObject:sd1];
        
        // init view controllers
        musicController = [[SBMusicController alloc] initWithManagedObjectContext:self.managedObjectContext];
        downloadsController = [[SBDownloadsController alloc] initWithManagedObjectContext:self.managedObjectContext];
        tracklistController = [[SBTracklistController alloc] initWithManagedObjectContext:self.managedObjectContext];
        playlistController = [[SBPlaylistController alloc] initWithManagedObjectContext:self.managedObjectContext];
        // additional VCs
        musicSearchController = [[SBMusicSearchController alloc] initWithManagedObjectContext:self.managedObjectContext];
        serverLibraryController = [[SBServerLibraryController alloc] initWithManagedObjectContext:self.managedObjectContext];
        serverHomeController = [[SBServerHomeController alloc] initWithManagedObjectContext:self.managedObjectContext];
        serverPodcastController = [[SBServerPodcastController alloc] initWithManagedObjectContext:self.managedObjectContext];
        serverUserController = [[SBServerUserViewController alloc] initWithManagedObjectContext:self.managedObjectContext];
        serverSearchController = [[SBServerSearchController alloc] initWithManagedObjectContext:self.managedObjectContext];
        
        [tracklistController setDatabaseController:self];
    }
    return self;
}

- (void)dealloc
{
    // remove Subsonic observers
    [[NSNotificationCenter defaultCenter] removeObserver:self name:SBSubsonicConnectionSucceededNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:SBSubsonicConnectionFailedNotification object:nil];
    // remove queue operations observer
    [[NSOperationQueue sharedServerQueue] removeObserver:self forKeyPath:@"operationCount"];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    // release all object references
    
}




#pragma mark -
#pragma mark Window Controller

- (void)windowDidLoad {
    
    [super windowDidLoad];
    
    // populate default sections
    [self populatedDefaultSections];
    
    // edit controllers
    [editServerController setManagedObjectContext:self.managedObjectContext];
    [addServerPlaylistController setManagedObjectContext:self.managedObjectContext];
    [musicController setDatabaseController:self];
    
    // source list drag and drop
    [sourceList registerForDraggedTypes:[NSArray arrayWithObject:SBLibraryTableViewDataType]];
    
    // observer number of currently running operations to animate progress
    [[NSOperationQueue sharedServerQueue] addObserver:self
                                                  forKeyPath:@"operationCount"
                                                     options:NSKeyValueObservingOptionNew
                                                     context:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(subsonicPlaylistsUpdatedNotification:)
                                                 name:SBSubsonicPlaylistsUpdatedNotification
                                               object:nil];
    
    // observer server playlists creation to reload source list when needed
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(subsonicPlaylistsCreatedNotification:)
                                                 name:SBSubsonicPlaylistsCreatedNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerPlaylistUpdatedNotification:)
                                                 name:SBPlayerPlaylistUpdatedNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerPlayStateNotification:)
                                                 name:SBPlayerPlayStateNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerHaveMovieToPlayNotification:)
                                                 name:SBPlayerMovieToPlayNotification
                                               object:nil];
    
    // observe Subsonic connection
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(subsonicConnectionSucceeded:)
                                                 name:SBSubsonicConnectionSucceededNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(subsonicConnectionFailed:)
                                                 name:SBSubsonicConnectionFailedNotification
                                               object:nil];

    // setup main box subviews animation
    [self setCurrentViewController: musicController];
    [self.currentViewController.view setFrameSize:[mainBox frame].size];
    
    NSView *contentView = [mainBox contentView];
    //[contentView setWantsLayer:YES];
    [contentView addSubview: [self currentViewController].view];
    
    transition = [CATransition animation];
    [transition setType:kCATransitionFade];
    [transition setDuration:0.05f];
    
    NSDictionary *ani = [NSDictionary dictionaryWithObject:transition
                                                    forKey:@"subviews"];
    [contentView setAnimations:ani];
    
    NSString *lastViewedURLString = [[NSUserDefaults standardUserDefaults] objectForKey: @"LastViewedResource"];
    if (lastViewedURLString != nil) {
        NSURL *lastViewedURL = [NSURL URLWithString: lastViewedURLString];
        SBResource *lastViewed = (SBResource *)[self.managedObjectContext objectWithID:[self.managedObjectContext.persistentStoreCoordinator managedObjectIDForURIRepresentation: lastViewedURL]];
        [self switchToResource: lastViewed];
    } else {
        [self setCurrentViewController: musicController];
    }
    
    [resourcesController addObserver:self
                          forKeyPath:@"content"
                             options:NSKeyValueObservingOptionNew
                             context:nil];
    

    [hostView setWantsLayer:YES];
}

#pragma mark -
#pragma mark Awake from NIB

/* from https://stackoverflow.com/questions/64531415/how-to-use-the-big-sur-style-toolbar-split-view-from-an-old-codebase */
- (void)awakeFromNib {
    [super awakeFromNib];

    // create a new-style NSSplitView using NSSplitViewController
    splitVC=[[NSSplitViewController alloc] init];
    splitVC.splitView.vertical=YES;
    splitVC.view.translatesAutoresizingMaskIntoConstraints=NO;

    // prepare the left pane as a sidebar
    NSSplitViewItem*a=[NSSplitViewItem sidebarWithViewController:leftVC];
    //[a setTitlebarSeparatorStyle:NSTitlebarSeparatorStyleShadow];
    [splitVC addSplitViewItem:a];

    // prepare the right pane
    NSSplitViewItem*b=[NSSplitViewItem splitViewItemWithViewController:rightVC];
    b.titlebarSeparatorStyle = NSTitlebarSeparatorStyleNone;
    [splitVC addSplitViewItem:b];
    
    // prepare the righter pane
    tracklistSplit=[NSSplitViewItem splitViewItemWithViewController:tracklistVC];
    // XXX: Not really working like you'd expect
    tracklistSplit.titlebarSeparatorStyle = NSTitlebarSeparatorStyleNone;
    // This uses the width in the nib, which is specified to show everything while not looking ridiculous.
    tracklistSplit.maximumThickness = [tracklistController view].frame.size.width;
    // Width of tracklist title + icon + leading bit of padding + bit of end padding before time
    // tracklistContainmentBox.frame.size.width would be default size to clamp to if you want
    tracklistSplit.minimumThickness = 150 + 36;
    //[tracklistContainmentBox.contentView addSubview: [tracklistController view]];
    tracklistContainmentBox.contentView = [tracklistController view];
    [splitVC addSplitViewItem: tracklistSplit];
    tracklistSplit.canCollapse=YES;
    tracklistSplit.collapsed = YES;
    
    // swap the old NSSplitView with the new one
    [self.window.contentView replaceSubview:mainSplitView with:splitVC.view ];

    // set up the constraints so that the new `NSSplitView` to fill the window
    [splitVC.view.topAnchor constraintEqualToAnchor:self.window.contentView.topAnchor
                                           constant:0].active=YES;
    [splitVC.view.bottomAnchor constraintEqualToAnchor:((NSLayoutGuide*)self.window.contentLayoutGuide).bottomAnchor].active=YES;
    [splitVC.view.leftAnchor constraintEqualToAnchor:((NSLayoutGuide*)self.window.contentLayoutGuide).leftAnchor].active=YES;
    [splitVC.view.rightAnchor constraintEqualToAnchor:((NSLayoutGuide*)self.window.contentLayoutGuide).rightAnchor].active=YES;
    
    // Need to set both for some reason? And after assignment to the parent?
    splitVC.splitView.autosaveName = @"DatabaseWindowSplitViewController";
    splitVC.splitView.identifier = @"SBDatabaseWindowSplitViewController";
}

#pragma mark -
#pragma mark Observers

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    // queue observer
    if(object == [NSOperationQueue sharedServerQueue]) {
        // number of currently running operations
        if([keyPath isEqualToString:@"operationCount"]) {
            if([[NSOperationQueue sharedServerQueue] operationCount] > 0) {
                [progressIndicator performSelectorOnMainThread: @selector(startAnimation:) withObject: self waitUntilDone: NO];
            } else {
                [progressIndicator performSelectorOnMainThread: @selector(stopAnimation:) withObject: self waitUntilDone: NO];
            }
        }
    } else if(object == resourcesController) {
        if([keyPath isEqualToString:@"content"]) {
                        
            // expand LIBRARY section
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(resourceName == %@)", @"LIBRARY"];
            SBLibrary *section = [self.managedObjectContext fetchEntityNammed:@"Section" withPredicate:predicate error:nil];
            if(section != nil)
                [sourceList expandURIs:[NSArray arrayWithObject:[[[section objectID] URIRepresentation] absoluteString]]];
            
            predicate = [NSPredicate predicateWithFormat:@"(resourceName == %@)", @"PLAYLISTS"];
            section = [self.managedObjectContext fetchEntityNammed:@"Section" withPredicate:predicate error:nil];
            if(section != nil)
                [sourceList expandURIs:[NSArray arrayWithObject:[[[section objectID] URIRepresentation] absoluteString]]];
            
            // expand saved expanded source list item
            [sourceList expandURIs:[[NSUserDefaults standardUserDefaults] objectForKey:@"NSOutlineView Items SourceList"]];
            
            [resourcesController removeObserver:self forKeyPath:@"content"];
			
			// load a pdemo server
			predicate = [NSPredicate predicateWithFormat:@"(resourceName == %@)", @"SERVERS"];
			SBSection *serversSection = [self.managedObjectContext fetchEntityNammed:@"Section" withPredicate:predicate error:nil];
			
			NSArray *servers = [self.managedObjectContext fetchEntitiesNammed:@"Server" withPredicate:nil error:nil];
			if(servers && servers.count == 0) {
				SBServer *s = [SBServer insertInManagedObjectContext:self.managedObjectContext];
				[s setResourceName:@"Subsonic Demo"];
				[serversSection addResourcesObject:s];
			}
			
			[sourceList expandURIs:[NSArray arrayWithObject:[[[serversSection objectID] URIRepresentation] absoluteString]]];
			[self.managedObjectContext save:nil];
        }
    }
}







#pragma mark -
#pragma mark IBAction Methods


- (IBAction)openAudioFiles:(id)sender {
    NSArray *types = [NSArray arrayWithObjects:@"mp3", @"flac", @"m4a", @"wav", @"aiff", @"aif", @"ogg", @"aac", nil];
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseDirectories:YES];
    [openPanel setCanChooseFiles:YES];
    [openPanel allowsMultipleSelection];

    [super showVisualCue];
    
    [openPanel setAllowedFileTypes: types];
    [openPanel beginSheetModalForWindow: [self window] completionHandler:^(NSModalResponse result) {
        [self openAudioFilesPanelDidEnd: openPanel returnCode: result contextInfo: nil];
    }];

}


- (IBAction)toggleTrackList:(id)sender {
    // as we can now switch the view
    if (tracklistContainmentBox.contentView != [tracklistController view]) {
        tracklistContainmentBox.contentView = [tracklistController view];
        [tracklistSplit.animator setCollapsed: NO];
    } else {
        [tracklistSplit.animator setCollapsed: ![tracklistSplit isCollapsed]];
    }
}


- (IBAction)toggleServerUsers:(id)sender {
    if (!self.server) {
        return;
    }
    [serverUserController setServer: self.server];
    [serverUserController viewDidLoad];
    // as we can now switch the view
    if (tracklistContainmentBox.contentView != [serverUserController view]) {
        tracklistContainmentBox.contentView = [serverUserController view];
        [tracklistSplit.animator setCollapsed: NO];
    } else {
        [tracklistSplit.animator setCollapsed: ![tracklistSplit isCollapsed]];
    }
}


- (IBAction)toggleVolume:(id)sender {
    NSView *view = volumeButton;
    NSRect boundary = view.bounds;
    if (volumePopover.shown) {
        [volumePopover close];
    } else {
        [volumePopover showRelativeToRect: boundary ofView: view preferredEdge:NSMaxYEdge];
    }
}

- (IBAction)addPlaylist:(id)sender {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(resourceName == %@)", @"PLAYLISTS"];
    SBSection *playlistsSection = [self.managedObjectContext fetchEntityNammed:@"Section" withPredicate:predicate error:nil];
    
    SBPlaylist *newPlaylist = [SBPlaylist insertInManagedObjectContext:self.managedObjectContext];
    [newPlaylist setResourceName:@"New Playlist"];
    [newPlaylist setSection:playlistsSection];
    [playlistsSection addResourcesObject:newPlaylist];
    
    [sourceList expandURIs:[NSArray arrayWithObject:[[[playlistsSection objectID] URIRepresentation] absoluteString]]];
}

- (IBAction)addRemotePlaylist:(id)sender {
    NSInteger selectedRow = [sourceList selectedRow];
    
    if (selectedRow != -1) {
        SBResource *resource = [[sourceList itemAtRow:selectedRow] representedObject];
        if(resource && [resource isKindOfClass:[SBServer class]]) {
            SBServer *server = (SBServer *)resource;
            
            [super showVisualCue];
            
            [addServerPlaylistController setServer:server];
            [addServerPlaylistController openSheet:sender];
        }
    }
}


- (IBAction)deleteRemotePlaylist:(id)sender {
    NSInteger selectedRow = [sourceList selectedRow];
    
    if (selectedRow != -1) {
        SBResource *resource = [[sourceList itemAtRow:selectedRow] representedObject];
        if(resource && [resource isKindOfClass:[SBPlaylist class]]) {
            
            NSAlert *alert = [[NSAlert alloc] init];
            [alert addButtonWithTitle:@"OK"];
            [alert addButtonWithTitle:@"Cancel"];
            [alert setMessageText:@"Delete the selected server playlist?"];
            [alert setInformativeText:@"Deleted server playlists cannot be restored."];
            [alert setAlertStyle:NSAlertStyleWarning];
            
            [super showVisualCue];
            
            [alert beginSheetModalForWindow: [self window] completionHandler:^(NSModalResponse returnCode) {
                [self deleteServerPlaylistAlertDidEnd: alert returnCode: returnCode contextInfo: nil];
            }];
        }
    }
}


- (IBAction)removeItem:(id)sender {
    NSInteger selectedRow = [sourceList selectedRow];
    
    if (selectedRow != -1) {
        SBResource *resource = [[sourceList itemAtRow:selectedRow] representedObject];
        if(resource && ([resource isKindOfClass:[SBPlaylist class]] || [resource isKindOfClass:[SBServer class]])) {
            
            NSAlert *alert = [[NSAlert alloc] init];
            [alert addButtonWithTitle:@"OK"];
            [alert addButtonWithTitle:@"Cancel"];
            [alert setMessageText:@"Delete the selected item?"];
            [alert setInformativeText:@"Deleted items cannot be restored."];
            [alert setAlertStyle:NSAlertStyleWarning];
            
            [super showVisualCue];
            
            [alert beginSheetModalForWindow: [self window] completionHandler:^(NSModalResponse returnCode) {
                [self removeItemAlertDidEnd: alert returnCode: returnCode contextInfo: nil];
            }];
        }
    }
}

- (IBAction)addServer:(id)sender {
    
    [sourceList deselectAll:sender];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(resourceName == %@)", @"SERVERS"];
    SBSection *serversSection = [self.managedObjectContext fetchEntityNammed:@"Section" withPredicate:predicate error:nil];
    
    SBServer *newServer = [SBServer insertInManagedObjectContext:self.managedObjectContext];
    [newServer setResourceName:@"New Server"];
    [newServer setSection:serversSection];
    [serversSection addResourcesObject:newServer];
    
    [sourceList expandURIs:[NSArray arrayWithObject:[[[serversSection objectID] URIRepresentation] absoluteString]]];
    
    [super showVisualCue];
    
    [editServerController setServer:newServer];
    [editServerController openSheet:sender];
}

- (IBAction)editItem:(id)sender {
    NSInteger selectedRow = [sourceList selectedRow];
    
    if (selectedRow != -1) {
        SBResource *resource = [[sourceList itemAtRow:selectedRow] representedObject];
        if(resource && [resource isKindOfClass:[SBPlaylist class]] && ((SBPlaylist *)resource).server == nil) {
            [sourceList editColumn:0 row:selectedRow withEvent:nil select:YES];
        } else if(resource && [resource isKindOfClass:[SBServer class]]) {
            
            [super showVisualCue];
            
            [editServerController setEditMode:YES];
            [editServerController setServer:(SBServer *)resource];
            [editServerController openSheet:sender];
        }
    }
}

- (IBAction)reloadServer:(id)sender {
    NSInteger selectedRow = [sourceList selectedRow];
    
    if (selectedRow != -1) {
        SBServer *server = [[sourceList itemAtRow:selectedRow] representedObject];
        if(server && [server isKindOfClass:[SBServer class]]) {
            [server getServerLicense];
            [server getServerIndexes];
            [server getServerPlaylists];
        }
    }
}

- (IBAction)playPause:(id)sender {
    
    if([[SBPlayer sharedInstance] isPlaying] || [[SBPlayer sharedInstance] isPaused]) {
        // player is already running
        [[SBPlayer sharedInstance] playPause];
    } else {
        // player hasn't run
        NSLog(@"player hasn't run");
    }
}

- (IBAction)stop:(id)sender {
    [[SBPlayer sharedInstance] stop];
}

- (IBAction)nextTrack:(id)sender {
    [[SBPlayer sharedInstance] next];
}

- (IBAction)previousTrack:(id)sender {
    [[SBPlayer sharedInstance] previous];
}

- (IBAction)seekTime:(id)sender {
    if([[SBPlayer sharedInstance] isPlaying]) {
        [[SBPlayer sharedInstance] seek:[sender doubleValue]];
    }
}

- (IBAction)rewind:(id)sender {
    // XXX: Controllable increment
    if([[SBPlayer sharedInstance] isPlaying]) {
        double newTime = MAX([[SBPlayer sharedInstance] currentTime] - 5, 0);
        [[SBPlayer sharedInstance] seekToTime: newTime];
    }
}

- (IBAction)fastForward:(id)sender {
    if([[SBPlayer sharedInstance] isPlaying]) {
        double maxTime = [[SBPlayer sharedInstance] durationTime];
        double newTime = MIN([[SBPlayer sharedInstance] currentTime] + 5, maxTime);
        [[SBPlayer sharedInstance] seekToTime: newTime];
    }
}

- (IBAction)setVolume:(id)sender {
    [[SBPlayer sharedInstance] setVolume:[sender floatValue]];
}

- (IBAction)setMuteOn:(id)sender {
    [[SBPlayer sharedInstance] setVolume:0.0f];
}

- (IBAction)setMuteOff:(id)sender {
    [[SBPlayer sharedInstance] setVolume:1.0f];
}

- (IBAction)volumeUp:(id)sender {
    // XXX: Controllable increment
    float newVolume = MIN(1.0f, [[SBPlayer sharedInstance] volume] + 0.1f);
    [[SBPlayer sharedInstance] setVolume: newVolume];
}

- (IBAction)volumeDown:(id)sender {
    float newVolume = MAX(0.0f, [[SBPlayer sharedInstance] volume] - 0.1f);
    [[SBPlayer sharedInstance] setVolume: newVolume];
}

- (IBAction)shuffle:(id)sender {
    // Don't call this from a bound control, or you'll have a bad time
    BOOL isShuffle = [[SBPlayer sharedInstance] isShuffle];
    [[SBPlayer sharedInstance] setIsShuffle:!isShuffle];
}

- (IBAction)repeatNone:(id)sender {
    [[SBPlayer sharedInstance] setRepeatMode: SBPlayerRepeatNo];
}

- (IBAction)repeatOne:(id)sender {
    [[SBPlayer sharedInstance] setRepeatMode: SBPlayerRepeatOne];
}

- (IBAction)repeatAll:(id)sender {
    [[SBPlayer sharedInstance] setRepeatMode: SBPlayerRepeatAll];
}

- (IBAction)repeat:(id)sender {
    SBPlayerRepeatMode repeatMode = [[SBPlayer sharedInstance] repeatMode];
    if (repeatMode == SBPlayerRepeatNo) {
        [[SBPlayer sharedInstance] setRepeatMode: SBPlayerRepeatOne];
    } else if (repeatMode == SBPlayerRepeatOne) {
        [[SBPlayer sharedInstance] setRepeatMode: SBPlayerRepeatAll];
    } else if (repeatMode == SBPlayerRepeatAll) {
        [[SBPlayer sharedInstance] setRepeatMode: SBPlayerRepeatNo];
    }
}


- (IBAction)openHomePage:(id)sender {
    NSInteger selectedRow = [sourceList selectedRow];
    
    if (selectedRow != -1) {
        SBServer *server = [[sourceList itemAtRow:selectedRow] representedObject];
        if(server && [server isKindOfClass:[SBServer class]]) {
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:server.url]];
        }
    }
}


- (void)showDownloadView {
	[self setCurrentViewController: downloadsController];
}

- (IBAction)showIndices:(id)sender {
    if (!self.server) {
        return;
    }
    [self.server setSelectedTabIndex: 0];
    [serverLibraryController setDatabaseController:self];
    [serverLibraryController setServer:self.server];
    [self setCurrentViewController: serverLibraryController];
}

- (IBAction)showAlbums:(id)sender {
    if (!self.server) {
        return;
    }
    [self.server setSelectedTabIndex: 1];
    [serverHomeController setDatabaseController:self];
    [serverHomeController setServer:self.server];
    [self setCurrentViewController: serverHomeController];
}

- (IBAction)showPodcasts:(id)sender {
    if (!self.server) {
        return;
    }
    [self.server setSelectedTabIndex: 2];
    [serverPodcastController setServer:self.server];
    [self setCurrentViewController: serverPodcastController];
}


- (IBAction)search:(id)sender {
    NSString *query;
    if ([sender isMemberOfClass: [NSSearchField class]]) {
        query = [sender stringValue];
    } else {
        [searchToolbarItem beginSearchInteraction];
        return;
    }
    
    
    if(query && [query length] > 0) {
        if (self.server) {
            // Remote
            [serverSearchController setServer:self.server];
            [self setCurrentViewController: serverSearchController];
            [self.server searchWithQuery:query];
        } else {
            // Local
            [self setCurrentViewController: musicSearchController];
            [musicSearchController searchString:query];
        }
    } else {
        [searchToolbarItem endSearchInteraction];
        // reset view for local/remote
        if (self.server) {
            switch ([self.server selectedTabIndex]) {
                case 0:
                default:
                    [self setCurrentViewController: serverLibraryController];
                    break;
                case 1:
                    [self setCurrentViewController: serverHomeController];
                    break;
                case 2:
                    [self setCurrentViewController: serverPodcastController];
                    break;
                // 3 was search and 4 was server users
            }
        } else {
            [self setCurrentViewController: musicController];
        }
    }
}


- (IBAction)cleanTracklist:(id)sender {
    [self stop: sender];
    [tracklistController cleanTracklist: sender];
}



#pragma mark -
#pragma mark NSTimer

- (void)clearPlaybackProgress {
    [progressSlider setEnabled:NO];
    [progressTextField setStringValue:@"00:00"];
    [durationTextField setStringValue:@"-00:00"];
    [progressSlider setDoubleValue:0];
}

- (void)installProgressTimer {
    if (progressUpdateTimer != nil) {
        return;
    }
    progressUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:0.01
                                                           target:self
                                                         selector:@selector(updateProgress:)
                                                         userInfo:nil
                                                          repeats:YES];
}

- (void)uninstallProgressTimer {
    if (progressUpdateTimer == nil) {
        return;
    }
    [progressUpdateTimer invalidate];
    progressUpdateTimer = nil;
    [self clearPlaybackProgress];
}

- (void)updateProgress:(NSTimer *)updatedTimer {
    
    if([[SBPlayer sharedInstance] isPlaying]) {
        [progressSlider setEnabled:YES];
        
        NSString *currentTimeString = [[SBPlayer sharedInstance] currentTimeString];
        NSString *remainingTimeString = [[SBPlayer sharedInstance] remainingTimeString];
        double progress = [[SBPlayer sharedInstance] progress];
        
        if(currentTimeString)
            [progressTextField setStringValue:currentTimeString];
        
        if(remainingTimeString)
            [durationTextField setStringValue:remainingTimeString];
        
        if(progress > 0)
            [progressSlider setDoubleValue:progress];
        
        // If buffering is useful to know, we could reimplement it better someday.
    
    } else {
        [self clearPlaybackProgress];
    }
}






#pragma mark -
#pragma mark NSOpenPanel Selector

- (void)openAudioFilesPanelDidEnd:(NSOpenPanel *)panel returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    if(returnCode == NSModalResponseOK) {
        NSArray *files = [panel filenames];
        if(files) {
            
            [panel orderOut:self];
            [NSApp endSheet:panel];
            
            [self openImportAlert:[self window] files:files];
        }
    } else {
        [super hideVisualCue];
    }
}


- (void)importSheetDidEnd: (NSWindow *)sheet returnCode: (NSInteger)returnCode contextInfo: (NSArray *)choosedFiles {
    
    if(returnCode == NSAlertFirstButtonReturn) {
        if(choosedFiles != nil) {
            
            SBImportOperation *op = [[SBImportOperation alloc] initWithManagedObjectContext:self.managedObjectContext];
            [op setFilePaths:choosedFiles];
            [op setLibraryID:[library objectID]];
            [op setCopy:YES];
            [op setRemove:NO];
            
            [[NSOperationQueue sharedDownloadQueue] addOperation:op];
        }
        
    } else if(returnCode == NSAlertSecondButtonReturn) {
        if(choosedFiles != nil) {
            
            SBImportOperation *op = [[SBImportOperation alloc] initWithManagedObjectContext:self.managedObjectContext];
            [op setFilePaths:choosedFiles];
            [op setLibraryID:[library objectID]];
            [op setCopy:NO];
            [op setRemove:NO];
            
            [[NSOperationQueue sharedDownloadQueue] addOperation:op];
        }
    }
    [super hideVisualCue];
}


- (void)removeItemAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSAlertFirstButtonReturn) {
        NSInteger selectedRow = [sourceList selectedRow];
        
        if (selectedRow != -1) {
            SBResource *resource = [[sourceList itemAtRow:selectedRow] representedObject];
            if(resource && ([resource isKindOfClass:[SBPlaylist class]] || [resource isKindOfClass:[SBServer class]])) {
                [self.managedObjectContext deleteObject:resource];
                [self.managedObjectContext processPendingChanges];
            }
        }
    }
    [super hideVisualCue];
}


- (void)deleteServerPlaylistAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSAlertFirstButtonReturn) {
        NSInteger selectedRow = [sourceList selectedRow];
        
        if (selectedRow != -1) {
            SBResource *resource = [[sourceList itemAtRow:selectedRow] representedObject];
            if(resource && [resource isKindOfClass:[SBPlaylist class]]) {
                SBPlaylist *playlist = (SBPlaylist *)resource;
                SBServer *server = playlist.server;
                
                [server deletePlaylistWithID:playlist.id];
                
                [self.managedObjectContext deleteObject:playlist];
                [self.managedObjectContext processPendingChanges];
            }
        }
    }
    [super hideVisualCue];
}







#pragma mark -
#pragma mark Private Methods

- (void)updateTitle {
    if ([[SBPlayer sharedInstance] isPlaying]) {
        // Let the notification handle it for us, for now
        return;
    }
    [self.window setTitle: currentViewController.title ?: @""];
    [self.window setSubtitle: @""];
}

- (void)populatedDefaultSections {
    NSPredicate *predicate = nil;
    SBSection *section = nil;
    NSError *error = nil;
    
    // library section
    predicate = [NSPredicate predicateWithFormat:@"(resourceName == %@)", @"LIBRARY"];
    section = [self.managedObjectContext fetchEntityNammed:@"Section" withPredicate:predicate error:&error];
    if(!section) {
        section = [SBSection insertInManagedObjectContext:self.managedObjectContext];
        [section setResourceName:@"LIBRARY"];
        [section setIndex:[NSNumber numberWithInteger:0]];
    }
    
    // library resource
    SBResource *resource = nil;
    predicate = [NSPredicate predicateWithFormat:@"(resourceName == %@)", @"Music"];
    library = [self.managedObjectContext fetchEntityNammed:@"Library" withPredicate:predicate error:&error];
    if(!library) {
        library = [SBLibrary insertInManagedObjectContext:self.managedObjectContext];
        [library setResourceName:@"Music"];
        [library setIndex:[NSNumber numberWithInteger:0]];
        [library setSection:section];
        [self.managedObjectContext assignObject:library toPersistentStore:[self.managedObjectContext.persistentStoreCoordinator.persistentStores objectAtIndex:0]];
    }
    
    // DOWNLOADS resource
    predicate = [NSPredicate predicateWithFormat:@"(resourceName == %@)", @"Downloads"];
    resource = [self.managedObjectContext fetchEntityNammed:@"Downloads" withPredicate:predicate error:&error];
    if(!resource) {
        resource = [SBDownloads insertInManagedObjectContext:self.managedObjectContext];
        [resource setResourceName:@"Downloads"];
        [resource setIndex:[NSNumber numberWithInteger:1]];
        [resource setSection:section];
        [self.managedObjectContext assignObject:resource toPersistentStore:[self.managedObjectContext.persistentStoreCoordinator.persistentStores objectAtIndex:0]];
    }
    
//    // tracklist resource
//    predicate = [NSPredicate predicateWithFormat:@"(resourceName == %@)", @"Tracklist"];
//    resource = [self.managedObjectContext fetchEntityNammed:@"Tracklist" withPredicate:predicate error:&error];
//    if(!resource) {
//        resource = [SBTracklist insertInManagedObjectContext:self.managedObjectContext];
//        [resource setResourceName:@"Tracklist"];
//        [resource setIndex:[NSNumber numberWithInteger:1]];
//
//        // expand LIBRARY section
//        //[sourceList expandAllItems];
//    }
//    [section addResourcesObject:resource];
//    [resource setSection:section];

    
    // playlist section
    predicate = [NSPredicate predicateWithFormat:@"(resourceName == %@)", @"PLAYLISTS"];
    section = [self.managedObjectContext fetchEntityNammed:@"Section" withPredicate:predicate error:&error];
    if(!section) {
        section = [SBSection insertInManagedObjectContext:self.managedObjectContext];
        [section setResourceName:@"PLAYLISTS"];
        [section setIndex:[NSNumber numberWithInteger:1]];
    }
    
    // servers section
    predicate = [NSPredicate predicateWithFormat:@"(resourceName == %@)", @"SERVERS"];
    section = [self.managedObjectContext fetchEntityNammed:@"Section" withPredicate:predicate error:&error];
    if(!section) {
        section = [SBSection insertInManagedObjectContext:self.managedObjectContext];
        [section setResourceName:@"SERVERS"];
        [section setIndex:[NSNumber numberWithInteger:2]];
    }
    
    //[sourceList expandAllItems];
    
    //[outlineView expandURIs:];
    
    [[self managedObjectContext] processPendingChanges];
    [[self managedObjectContext] save:nil];
}

//- (void)setServer:(SBServer *)server {
//    _server = server;
//}

- (void)switchToResource:(SBResource*)resource {
    if(resource && [resource isKindOfClass:[SBServer class]]) {
        SBServer *server = (SBServer *)resource;
        [server connect];
    }
    // Must be after the connection.
    if(resource) {
        [self displayViewControllerForResource:resource];
    }
    
    if([resource isKindOfClass:[SBPlaylist class]]) {
        SBPlaylist *playlist = (SBPlaylist *)resource;
        
        if(playlist.server != nil) { // is remote playlist
            // clear playlist
            [playlistController clearPlaylist];
            
            // update playlist
            [playlist.server getPlaylistTracks:playlist];
        }
        
    }
}

- (void)displayViewControllerForResource:(SBResource *)resource {
    // NSURLs dont go to plists
    if (![resource isKindOfClass: [SBResource class]]) {
        NSLog(@"Hey, \"%@\" isn't a resource", resource);
        return;
    }
    NSString *urlString = resource.objectID.URIRepresentation.absoluteString;
    [[NSUserDefaults standardUserDefaults] setObject: urlString forKey: @"LastViewedResource"];
    // swith view relative to a selected resource
    if([resource isKindOfClass:[SBLibrary class]]) {
        
        [self setServer: nil];
        [self setCurrentViewController: musicController];
        [searchToolbarItem setEnabled: YES];
        [searchField setPlaceholderString: @"Local Search"];
        
    }  else if([resource isKindOfClass:[SBDownloads class]]) {
        
        [self setServer: nil];
        [self setCurrentViewController: downloadsController];
        [searchToolbarItem setEnabled: NO];
        [searchField setPlaceholderString: @""];
        
    } else if([resource isKindOfClass:[SBTracklist class]]) {
        
        [self setServer: nil];
        [self setCurrentViewController: tracklistController];
        [searchToolbarItem setEnabled: NO];
        [searchField setPlaceholderString: @""];
        
    } else if([resource isKindOfClass:[SBPlaylist class]]) {
        
        [self setServer: nil];
        [playlistController setPlaylist:(SBPlaylist *)resource];
        [self setCurrentViewController: playlistController];
        [searchToolbarItem setEnabled: NO];
        [searchField setPlaceholderString: @""];
         
    } else if([resource isKindOfClass:[SBServer class]]) {
        SBServer *server = (SBServer*)resource;
        [self setServer: server]; // set to nil afterwards?
        switch ([server selectedTabIndex]) {
            case 0:
            default:
                [serverLibraryController setDatabaseController:self];
                [serverLibraryController setServer: server];
                [self setCurrentViewController: serverLibraryController];
                break;
            case 1:
                [serverHomeController setDatabaseController:self];
                [serverHomeController setServer: server];
                [self setCurrentViewController: serverHomeController];
                break;
            case 2:
                [serverPodcastController setServer: server];
                [self setCurrentViewController: serverPodcastController];
                break;
            // 3 was search and 4 was server users
        }
        [searchToolbarItem setEnabled: YES];
        [searchField setPlaceholderString: @"Server Search"];
    }
}


- (void)setCurrentViewController:(SBViewController *)newViewController {
    if (!currentViewController) {
        currentViewController = newViewController;
        return;
    }
    NSView *contentView = [mainBox contentView];
    [[contentView animator] replaceSubview:currentViewController.view with:newViewController.view];
    [newViewController.view setFrameSize:[mainBox frame].size];
    currentViewController = newViewController;
    [self updateTitle];
}


- (BOOL)openImportAlert:(NSWindow *)sender files:(NSArray *)files {
    NSAlert *importAlert = [[NSAlert alloc] init];
    [importAlert setMessageText:@"Do you want to copy the imported audio files?"];
    [importAlert setInformativeText: @"If you click the \"Copy\" button, the imported files will be copied into the database. If you click the \"Link\" button, the files will not be copied, but instead linked into the database."];
    [importAlert addButtonWithTitle: @"Copy"];
    [importAlert addButtonWithTitle: @"Link"];
    [importAlert addButtonWithTitle: @"Cancel"];
    [importAlert beginSheetModalForWindow: sender completionHandler:^(NSModalResponse alertReturnCode) {
        [self importSheetDidEnd: sender returnCode: alertReturnCode contextInfo: files];
    }];
    
    //[files autorelease];
    return NO;
}




#pragma mark -
#pragma mark Subsonic Notifications (Private)

- (void)subsonicPlaylistsUpdatedNotification:(NSNotification *)notification {
    
    //[resourcesController rearrangeObjects];
    [sourceList performSelector:@selector(reloadData) withObject:nil afterDelay:0.0f];
    
    NSArray *URIs = [NSArray arrayWithObject:[[[notification object] URIRepresentation] absoluteString]];
    [sourceList performSelectorOnMainThread:@selector(reloadURIs:) withObject:URIs waitUntilDone:YES];
    //[sourceList performSelectorOnMainThread:@selector(expandURIs:) withObject:URIs waitUntilDone:YES];
}


- (void)subsonicPlaylistsCreatedNotification:(NSNotification *)notification {
    
    SBServer *server = (SBServer *)[self.managedObjectContext objectWithID:[notification object]];
    if(server)
        [server getServerPlaylists];
}


- (void)subsonicConnectionFailed:(NSNotification *)notification {
    if([[notification object] isKindOfClass:[NSDictionary class]]) {
        NSDictionary *attr = [notification object];
        NSInteger code = [[attr valueForKey:@"code"] intValue];
        
        // Even creating the alert on the main thread is a problem
        dispatch_async(dispatch_get_main_queue(), ^{
            NSAlert *alert = [[NSAlert alloc] init];
            [alert setAlertStyle: NSAlertStyleCritical];
            [alert setMessageText: [NSString stringWithFormat:@"Subsonic Error (code %ld)", code]];
            [alert setInformativeText: [attr valueForKey:@"message"]];
            [alert addButtonWithTitle: @"OK"];
            [alert runModal];
        });
    }
}


- (void)subsonicConnectionSucceeded:(NSNotification *)notification {
    // loading of server content, major !!!
    [self.server getServerLicense];
    [self.server getServerIndexes];
    [self.server getServerPlaylists];
}



#pragma mark -
#pragma mark Player Notifications (Private)

- (void)playerPlaylistUpdatedNotification:(NSNotification *)notification {
    SBTrack *currentTrack = [[SBPlayer sharedInstance] currentTrack];
    
    if(currentTrack != nil) {
        
        NSString *trackInfos = [NSString stringWithFormat:@"%@ - %@", currentTrack.artistString, currentTrack.albumString];
        SBCover *cover = currentTrack.album.cover;
        NSImage *coverImage = nil;
        
        if(cover && cover.imagePath) {
            coverImage = [[NSImage alloc] initWithContentsOfFile:cover.imagePath];
        } else {
            coverImage = [NSImage imageNamed:@"NoArtwork"];
        }
        
        [self.window setTitle:currentTrack.itemName];
        [self.window setSubtitle:trackInfos];
        [coverImageView setImage:coverImage];
        
        if(![currentTrack.isLocal boolValue])
            if(currentTrack.localTrack != nil) {
                [onlineImageView setImage:[NSImage imageWithSystemSymbolName:@"wifi.slash" accessibilityDescription:@"Cached"]];
            } else {
                [onlineImageView setImage:[NSImage imageWithSystemSymbolName:@"wifi" accessibilityDescription:@"Online"]];
            }
        else [onlineImageView setImage:nil];
        
//        if(![currentTrack.isPlaying boolValue])
//            [playPauseButton setState:NSOffState];
//        else [playPauseButton setState:NSOnState];
        
    } else {
        [self.window setTitle: currentViewController.title ?: @""];
        [self.window setSubtitle: @""];
        [onlineImageView setImage:nil];
        [coverImageView setImage:[NSImage imageNamed:@"NoArtwork"]];
        [playPauseButton setState:NSControlStateValueOn];
    }
}
- (void)playerPlayStateNotification:(NSNotification *)notification {
    SBTrack *currentTrack = [[SBPlayer sharedInstance] currentTrack];
    
    if(currentTrack != nil) {
        // XXX: Could it be safe to stop the timer when paused?
        [self installProgressTimer];
        if([[SBPlayer sharedInstance] isPaused]) {
            [playPauseButton setState:NSControlStateValueOff];
            NSLog(@"Paused?");
        }
        else {
            [playPauseButton setState:NSControlStateValueOn];
            NSLog(@"Playing?");
        }
    } else {
        [self uninstallProgressTimer];
        [playPauseButton setState:NSControlStateValueOn];
        NSLog(@"Stopped?");
    }
}

- (void)playerHaveMovieToPlayNotification:(NSNotification *)notification {
    // XXX: We get SBPlayer here, does that ever make sense?
    [self displayViewControllerForResource:[notification object]];
}



#pragma mark -
#pragma mark SourceList DataSource

- (NSUInteger)sourceList:(SBSourceList*)sourceList numberOfChildrenOfItem:(id)item {
    return [[[item representedObject] resources] count];
}

- (id)sourceList:(SBSourceList*)aSourceList child:(NSUInteger)index ofItem:(id)item {
    return nil;
}

- (id)sourceList:(SBSourceList*)aSourceList objectValueForItem:(id)item {
    return nil;
}

- (void)sourceList:(SBSourceList *)aSourceList setObjectValue:(id)object forItem:(id)item {
    [[item representedObject] setResourceName:object];
}

- (BOOL)sourceList:(SBSourceList*)aSourceList isItemExpandable:(id)item {
    return YES;
}

- (BOOL)sourceList:(SBSourceList*)aSourceList itemHasIcon:(id)item {
    return YES;
}

- (NSImage*)sourceList:(SBSourceList*)aSourceList iconForItem:(id)item {

    if([[item representedObject] isKindOfClass:[SBLibrary class]])
        return [NSImage imageWithSystemSymbolName:@"music.note" accessibilityDescription:@"Library"];
    
    if([[item representedObject] isKindOfClass:[SBTracklist class]])
        return [NSImage imageWithSystemSymbolName:@"music.note.list" accessibilityDescription:@"Tracklist"];
    
    if([[item representedObject] isKindOfClass:[SBPlaylist class]])
        return [NSImage imageWithSystemSymbolName:@"music.note.list" accessibilityDescription:@"Playlist"];
    
    if([[item representedObject] isKindOfClass:[SBServer class]])
        return [NSImage imageWithSystemSymbolName:@"network" accessibilityDescription:@"Network"];
    
    if([[item representedObject] isKindOfClass:[SBDownloads class]])
        return [NSImage imageWithSystemSymbolName:@"tray.and.arrow.down.fill" accessibilityDescription:@"Downloads"];
    
    return nil;
}



#pragma mark -
#pragma mark SourceList DataSource (Drag & Drop)

- (NSDragOperation)sourceList:(SBSourceList *)sourceList validateDrop:(id<NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(NSInteger)index {
    NSSet *allowedClasses = [NSSet setWithObjects: NSIndexSet.class, NSArray.class, NSURL.class, nil];
    NSError *error = nil;
    if([[item representedObject] isKindOfClass:[SBPlaylist class]]) {
        if([[[info draggingPasteboard] types] containsObject:SBLibraryTableViewDataType]) {
            NSData *data = [[info draggingPasteboard] dataForType:SBLibraryTableViewDataType];
            NSArray *tracksURIs = [NSKeyedUnarchiver unarchivedObjectOfClasses: allowedClasses fromData: data error: &error];
            if (error != nil) {
                NSLog(@"Error unserializing array %@", error);
                return NSDragOperationNone;
            }
            
            SBTrack *firstTrack = (SBTrack *)[self.managedObjectContext objectWithID:[self.managedObjectContext.persistentStoreCoordinator managedObjectIDForURIRepresentation:[tracksURIs objectAtIndex:0]]];
            SBPlaylist *targetPlaylist = [item representedObject];
            
            if(targetPlaylist.server == nil) { // is local playlist and local track
                return NSDragOperationCopy;
            } else if([targetPlaylist.server isEqualTo:firstTrack.server]) {
                return NSDragOperationCopy;
            }
        }
    } else if([[item representedObject] isKindOfClass:[SBDownloads class]] || [[item representedObject] isKindOfClass:[SBLibrary class]]) {
        NSData *data = [[info draggingPasteboard] dataForType:SBLibraryTableViewDataType];
        NSArray *tracksURIs = [NSKeyedUnarchiver unarchivedObjectOfClasses: allowedClasses fromData: data error: &error];
        if (error != nil) {
            NSLog(@"Error unserializing array %@", error);
            return NSDragOperationNone;
        }
        
        SBTrack *firstTrack = (SBTrack *)[self.managedObjectContext objectWithID:[self.managedObjectContext.persistentStoreCoordinator managedObjectIDForURIRepresentation:[tracksURIs objectAtIndex:0]]];
        
        // if remote or not in cache
        if(firstTrack.server != nil || (firstTrack.server != nil && firstTrack.localTrack == nil)) {
            return NSDragOperationCopy;
        }
    }
    
    return NSDragOperationNone;
}


- (BOOL)sourceList:(SBSourceList *)aSourceList acceptDrop:(id<NSDraggingInfo>)info item:(id)item childIndex:(NSInteger)index {
    NSSet *allowedClasses = [NSSet setWithObjects: NSIndexSet.class, NSArray.class, NSURL.class, nil];
    NSError *error = nil;
    if([[item representedObject] isKindOfClass:[SBPlaylist class]]) {
        SBPlaylist *playlist = (SBPlaylist *)[item representedObject];
        
        if([[[info draggingPasteboard] types] containsObject:SBLibraryTableViewDataType]) {
           
            if(playlist.server == nil) {
                NSData *data = [[info draggingPasteboard] dataForType:SBLibraryTableViewDataType];
                NSArray *tracksURIs = [NSKeyedUnarchiver unarchivedObjectOfClasses: allowedClasses fromData: data error: &error];
                if (error != nil) {
                    NSLog(@"Error unserializing array %@", error);
                    return NO;
                }
                
                // also add new track IDs to the array
                [tracksURIs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    SBTrack *track = (SBTrack *)[self.managedObjectContext objectWithID:[[self.managedObjectContext persistentStoreCoordinator] managedObjectIDForURIRepresentation:obj]];
                    
                    [track setPlaylistIndex:[NSNumber numberWithInteger:[playlist.tracks count]]];
                    [playlist addTracksObject:track];
                }];
            } else {
                
                NSData *data = [[info draggingPasteboard] dataForType:SBLibraryTableViewDataType];
                NSArray *tracksURIs = [NSKeyedUnarchiver unarchivedObjectOfClasses: allowedClasses fromData: data error: &error];
                if (error != nil) {
                    NSLog(@"Error unserializing array %@", error);
                    return NO;
                }
                NSMutableArray *trackIDs = [NSMutableArray array];
                NSString *playlistID = playlist.id;
                
                // create an IDs array with existing playlist tracks
                [playlist.tracks enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
                    [trackIDs addObject:[obj valueForKey:@"id"]];
                }];
                
                // also add new track IDs to the array
                [tracksURIs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    SBTrack *track = (SBTrack *)[self.managedObjectContext objectWithID:[[self.managedObjectContext persistentStoreCoordinator] managedObjectIDForURIRepresentation:obj]];
                    [trackIDs addObject:track.id];
                }];
                
                [playlist.server updatePlaylistWithID:playlistID tracks:trackIDs];
            }
            
            return YES;
        }
    } else if([[item representedObject] isKindOfClass:[SBDownloads class]] || [[item representedObject] isKindOfClass:[SBLibrary class]]) {
		
		[self displayViewControllerForResource:[item representedObject]];
		
        NSData *data = [[info draggingPasteboard] dataForType:SBLibraryTableViewDataType];
        NSArray *tracksURIs = [NSKeyedUnarchiver unarchivedObjectOfClasses: allowedClasses fromData: data error: &error];
        if (error != nil) {
            NSLog(@"Error unserializing array %@", error);
            return NO;
        }
        
        // also add new track IDs to the array
        [tracksURIs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            SBTrack *track = (SBTrack *)[self.managedObjectContext objectWithID:[[self.managedObjectContext persistentStoreCoordinator] managedObjectIDForURIRepresentation:obj]];

            // download track
            SBSubsonicDownloadOperation *op = [[SBSubsonicDownloadOperation alloc] initWithManagedObjectContext:self.managedObjectContext];
            [op setTrackID:[track objectID]];
            
            [[NSOperationQueue sharedDownloadQueue] addOperation:op];
        }];
    }
    
    return YES;
}





#pragma mark -
#pragma mark SourceList DataSource (Badges)

- (BOOL)sourceList:(SBSourceList*)aSourceList itemHasBadge:(id)item {
    BOOL result = NO;
    
    if([[item representedObject] isKindOfClass:[SBDownloads class]]) {
        if(downloadsController.downloadActivities.count > 0)
            result = YES;
    }
    
    return result;
}

- (NSInteger)sourceList:(SBSourceList*)aSourceList badgeValueForItem:(id)item {
    NSInteger result = 0;
    
    if([[item representedObject] isKindOfClass:[SBServer class]]) {
                [[NSApp dockTile] setBadgeLabel:nil]; // XXX: Needed?
    } else if([[item representedObject] isKindOfClass:[SBDownloads class]]) {
        if(downloadsController.downloadActivities.count > 0)
            result = downloadsController.downloadActivities.count;
    }
    
    return result;
}





#pragma mark -
#pragma mark SourceList Delegate

- (void)sourceListSelectionDidChange:(NSNotification *)notification {
    NSInteger selectedRow = [sourceList selectedRow];
    
    if (selectedRow != -1) {
        SBResource *resource = [[sourceList itemAtRow:selectedRow] representedObject];
        
        [self switchToResource: resource];
    }
}

- (CGFloat)sourceList:(SBSourceList *)aSourceList heightOfRowByItem:(id)item {
    
    if([[item representedObject] isKindOfClass:[SBSection class]]) {
        return 26.0f;
    }
    return 22.0f;
}

- (BOOL)sourceList:(SBSourceList*)aSourceList shouldSelectItem:(id)item {
    if([[item representedObject] isKindOfClass:[SBSection class]])
        return NO;
    return YES;
}


- (BOOL)sourceList:(SBSourceList*)aSourceList shouldExpandItem:(id)item {
    return YES;
}

- (BOOL)sourceList:(SBSourceList *)aSourceList isGroupAlwaysExpanded:(id)group {
    
    if([[[group representedObject] resourceName] isEqualToString:@"LIBRARY"])
        return YES;
    
    return NO;
}

- (BOOL)sourceList:(SBSourceList*)aSourceList shouldEditItem:(id)item {
    if([[item representedObject] isKindOfClass:[SBLibrary class]])
        return NO;

    if([[item representedObject] isKindOfClass:[SBDownloads class]])
        return NO;
    
    if([[item representedObject] isKindOfClass:[SBTracklist class]])
        return NO;
    
    if([[item representedObject] isKindOfClass:[SBSection class]])
        return NO;
    
    if([[item representedObject] isKindOfClass:[SBPlaylist class]] && ((SBPlaylist *)[item representedObject]).server != nil)
        return NO;
    
    return YES;

}

- (NSMenu*)sourceList:(SBSourceList *)aSourceList menuForEvent:(NSEvent*)theEvent item:(id)item {
    
    if ([theEvent type] == NSEventTypeRightMouseDown || ([theEvent type] == NSEventTypeLeftMouseDown && ([theEvent modifierFlags] & NSEventModifierFlagControl) == NSEventModifierFlagControl)) {
    
        
        if(item != nil) {
            SBResource *resource = [item representedObject];
            
            if([resource isKindOfClass:[SBPlaylist class]]) {
                
                SBPlaylist *playlist = (SBPlaylist *)resource;
                NSMenu * m = [[NSMenu alloc] init];
                
                if(playlist.server == nil) {
                    // if playlist is local
                    NSString *editString = [NSString stringWithFormat:@"Edit \"%@\"", [[item representedObject] resourceName]];
                    
                    [m addItemWithTitle:editString action:@selector(editItem:) keyEquivalent:@""];
                    [m addItemWithTitle:@"Remove Playlist" action:@selector(removeItem:) keyEquivalent:@""];
                    
                } else {
                    // if playlist is a remote playlist
                    NSString *removeString = [NSString stringWithFormat:@"Delete \"%@\"", [[item representedObject] resourceName]];
                    [m addItemWithTitle:removeString action:@selector(deleteRemotePlaylist:) keyEquivalent:@""];
                }
                
                return m;
                
            } else if([resource isKindOfClass:[SBServer class]]) {
                
                NSMenu * m = [[NSMenu alloc] init];
                
                [m addItemWithTitle:@"Add Playlist to Server" action:@selector(addRemotePlaylist:) keyEquivalent:@""];
                [m addItemWithTitle:@"Reload Server" action:@selector(reloadServer:) keyEquivalent:@""];
                [m addItem:[NSMenuItem separatorItem]];
                [m addItemWithTitle:@"Open Home Page" action:@selector(openHomePage:) keyEquivalent:@""];
                [m addItemWithTitle:@"Configure Server" action:@selector(editItem:) keyEquivalent:@""];
                [m addItem:[NSMenuItem separatorItem]];
                [m addItemWithTitle:@"Remove Server" action:@selector(removeItem:) keyEquivalent:@""];
                
                
                return m;
            }
            
        } else {
            NSMenu * m = [[NSMenu alloc] init];
            
            [m addItemWithTitle:@"Add Playlist" action:@selector(addPlaylist:) keyEquivalent:@""];
            [m addItemWithTitle:@"Add Server" action:@selector(addServer:) keyEquivalent:@""];
            
            return m;
        }
	}
	return nil;
}


- (id)sourceList:(SBSourceList *)aSourceList persistentObjectForItem:(id)item {
    return [[[(NSManagedObject*)[item representedObject] objectID] URIRepresentation] absoluteString];
}


- (void)sourceListDeleteKeyPressedOnRows:(NSNotification *)notification {
    NSInteger selectedRow = [sourceList selectedRow];
    
    if(selectedRow != -1) {
        SBResource *res = [[sourceList itemAtRow:selectedRow] representedObject];
        if(![res isKindOfClass:[SBSection class]] &&
           (![res.resourceName isEqualToString:@"Music"] ||
            ![res.resourceName isEqualToString:@"Tracklist"])) {
               if([res isKindOfClass:[SBPlaylist class]] && ((SBPlaylist *)res).server != nil) {
                   [self deleteRemotePlaylist:self];
               } else {
                   [self removeItem:self];
               }
           }
    }
}



#pragma mark -
#pragma mark NSWindow Delegate

- (void)windowWillClose:(NSNotification *)notification {
}

- (void)windowWillMove:(NSNotification *)notification {
    containerView.frame = rightVC.view.safeAreaRect;
}

- (void)windowWillStartLiveResize:(NSNotification *)notification {
    containerView.frame = rightVC.view.safeAreaRect;
}


- (void)windowWillMiniaturize:(NSNotification *)notification {
}



#pragma mark -
#pragma mark UI Validator

// XXX: Toolbars too
- (BOOL)validateUserInterfaceItem: (id<NSValidatedUserInterfaceItem>) item {
    SEL action = [item action];
    
    BOOL isPlaying = [[SBPlayer sharedInstance] isPlaying];
    
    if (action == @selector(playPause:) || action == @selector(stop:)
        || action == @selector(rewind:) || action == @selector(fastForward:)) {
        return isPlaying;
    }
    // Similar, but could use if prv/next track exist
    if (action == @selector(previousTrack:) || action == @selector(nextTrack:)) {
        return isPlaying;
    }
    
    // only works if we have a server set
    if (action == @selector(showIndices:)
        || action == @selector(showAlbums:)
        || action == @selector(showPodcasts:)
        || action == @selector(toggleServerUsers:)) {
        return self.server != nil;
    }
    
    if (action == @selector(search:)) {
        return [searchToolbarItem isEnabled];
    }
    
    return YES;
}


@end




