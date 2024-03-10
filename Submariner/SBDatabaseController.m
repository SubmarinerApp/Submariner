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
#import "SBMusicController.h"
#import "SBPlaylistController.h"
#import "SBAnimatedView.h"
#import "SBTableView.h"

#import "SBSplitView.h"

#import "NSOutlineView+Expand.h"

#import "Submariner-Swift.h"

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
@synthesize library;
@synthesize server;


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
        // init sort descriptors; index comes first, followed by alphabetical if no index override
        // (if we just use name, then it messes up the library section)
        NSSortDescriptor *sd1 = [NSSortDescriptor sortDescriptorWithKey:@"index" ascending:YES];
        NSSortDescriptor *sd2 = [NSSortDescriptor sortDescriptorWithKey:@"resourceName" ascending:YES];
        resourceSortDescriptors = @[sd1, sd2];
        
        // init view controllers
        onboardingController = [[SBOnboardingController alloc] initWithManagedObjectContext:self.managedObjectContext];
        musicController = [[SBMusicController alloc] initWithManagedObjectContext:self.managedObjectContext];
        downloadsController = [[SBDownloadsController alloc] initWithManagedObjectContext:self.managedObjectContext];
        tracklistController = [[SBTracklistController alloc] initWithManagedObjectContext:self.managedObjectContext];
        playlistController = [[SBPlaylistController alloc] initWithManagedObjectContext:self.managedObjectContext];
        // additional VCs
        musicSearchController = [[SBMusicSearchController alloc] initWithManagedObjectContext:self.managedObjectContext];
        serverLibraryController = [[SBServerLibraryController alloc] initWithManagedObjectContext:self.managedObjectContext];
        serverHomeController = [[SBServerHomeController alloc] initWithManagedObjectContext:self.managedObjectContext];
        serverDirectoryController = [[SBServerDirectoryController alloc] initWithManagedObjectContext:self.managedObjectContext];
        serverPodcastController = [[SBServerPodcastController alloc] initWithManagedObjectContext:self.managedObjectContext];
        serverUserController = [[SBServerUserViewController alloc] initWithManagedObjectContext:self.managedObjectContext];
        serverSearchController = [[SBServerSearchController alloc] initWithManagedObjectContext:self.managedObjectContext];
        inspectorController = [[SBInspectorController alloc] initWithManagedObjectContext:self.managedObjectContext];
        
        [onboardingController setDatabaseController:self];
        [musicController setDatabaseController:self];
        [musicSearchController setDatabaseController:self];
        [tracklistController setDatabaseController:self];
        [playlistController setDatabaseController:self];
        [serverLibraryController setDatabaseController:self];
        [serverHomeController setDatabaseController:self];
        [serverDirectoryController setDatabaseController:self];
        [serverSearchController setDatabaseController:self];
        [serverUserController setDatabaseController:self];
        [inspectorController setDatabaseController:self];
    }
    return self;
}

- (void)dealloc
{
    // remove window observer
    [self.window.contentView removeObserver: self forKeyPath: @"safeAreaInsets"];
    // remove Subsonic observers
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"SBSubsonicConnectionSucceededNotification" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"SBSubsonicConnectionFailedNotification" object:nil];
    // remove window observers
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidChangeOcclusionStateNotification object:nil];
    // remove queue operations observer
    [[NSOperationQueue sharedServerQueue] removeObserver:self forKeyPath:@"operationCount"];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    // release all object references
    
}




#pragma mark -
#pragma mark Window Controller

- (BOOL)shouldShowOnboarding {
    // The criteria for showing the onboarding dialog is:
    // 1. No local music
    // 2. No servers
    // So, check for both
    NSError *error;
    
    NSPredicate *localMusicPredicate = [NSPredicate predicateWithFormat:@"(server == %@)", nil];
    NSEntityDescription *artistDescription = [NSEntityDescription entityForName: @"Artist" inManagedObjectContext: self.managedObjectContext];
    NSFetchRequest *localMusicFetchRequest = [[NSFetchRequest alloc] init];
    localMusicFetchRequest.predicate = localMusicPredicate;
    localMusicFetchRequest.entity = artistDescription;
    NSUInteger localMusicCount = [self.managedObjectContext countForFetchRequest: localMusicFetchRequest error: &error];
    
    NSEntityDescription *serverDescription = [NSEntityDescription entityForName: @"Server" inManagedObjectContext: self.managedObjectContext];
    NSFetchRequest *serverFetchRequest = [[NSFetchRequest alloc] init];
    serverFetchRequest.entity = serverDescription;
    NSUInteger serverCount = [self.managedObjectContext countForFetchRequest: serverFetchRequest error: &error];
    
    return (localMusicCount < 1 && serverCount < 1);
}

- (void)windowDidLoad {
    
    [super windowDidLoad];
    
    // populate default sections
    [self populatedDefaultSections];
    
    // edit controllers
    [editServerController setManagedObjectContext:self.managedObjectContext];
    [addServerPlaylistController setManagedObjectContext:self.managedObjectContext];
    
    // source list drag and drop
    [sourceList registerForDraggedTypes: @[SBLibraryTableViewDataType, SBLibraryItemTableViewDataType]];
    
    // re-layout when visible, so that ServerHome MGScopeBar doesn't get swallowed
    // the insets are the variable that changes, not the safeAreaRect (which is presumably calculated)
    [self.window.contentView addObserver: self forKeyPath: @"safeAreaInsets" options: NSKeyValueObservingOptionNew context: nil];
    
    // observer number of currently running operations to animate progress
    [[NSOperationQueue sharedServerQueue] addObserver:self
                                                  forKeyPath:@"operationCount"
                                                     options:NSKeyValueObservingOptionNew
                                                     context:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(subsonicPlaylistsUpdatedNotification:)
                                                 name:@"SBSubsonicPlaylistsUpdatedNotification"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(subsonicPlaylistUpdatedNotification:)
                                                 name:@"SBSubsonicPlaylistUpdatedNotification"
                                               object:nil];
    
    // observer server playlists creation to reload source list when needed
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(subsonicPlaylistsCreatedNotification:)
                                                 name:@"SBSubsonicPlaylistsCreatedNotification"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerPlaylistUpdatedNotification:)
                                                 name:@"SBPlayerPlaylistUpdatedNotification"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerPlayStateNotification:)
                                                 name:@"SBPlayerPlayStateNotification"
                                               object:nil];
    
    // observe Subsonic connection
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(subsonicConnectionSucceeded:)
                                                 name:@"SBSubsonicConnectionSucceededNotification"
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(subsonicConnectionFailed:)
                                                 name:@"SBSubsonicConnectionFailedNotification"
                                               object:nil];

    // observe window state
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(windowDidChangeOcclusionState:)
                                                 name:NSWindowDidChangeOcclusionStateNotification
                                               object:nil];


    // setup main box subviews animation
    // XXX: Creates a null first item
    SBNavigationItem *navItem = [[SBLocalMusicNavigationItem alloc] init];
    [self navigateForwardToNavItem: navItem];
    
    id lastViewed = nil;
    NSString *lastViewedURLString = [[NSUserDefaults standardUserDefaults] objectForKey: @"LastViewedResource"];
    if (lastViewedURLString != nil) {
        NSURL *lastViewedURL = [NSURL URLWithString: lastViewedURLString];
        NSError *error = nil;
        NSManagedObjectID *oid = [self.managedObjectContext.persistentStoreCoordinator managedObjectIDForURIRepresentation: lastViewedURL];
        // Use this, or Core Data will happily make a fault of a non-existent object.
        @try {
            lastViewed = [self.managedObjectContext existingObjectWithID: oid error: &error];
        } @catch (NSException *exc) {
            NSLog(@"existingObjectWithID failed, but not fatal: %@", exc);
        }
    }
    
    if ([self shouldShowOnboarding]) {
        SBNavigationItem *navItem = [[SBOnboardingNavigationItem alloc] init];
        [self navigateForwardToNavItem: navItem];
    } else if (lastViewed != nil) {
        // XXX: should make switchToResource not handle SBMusicItem
        [self switchToResource: (SBResource*)lastViewed];
    } else {
        SBNavigationItem *navItem = [[SBLocalMusicNavigationItem alloc] init];
        [self navigateForwardToNavItem: navItem];
    }
    // Reset history
    [rightVC setArrangedObjects: @[ [rightVC.arrangedObjects objectAtIndex: 1] ]];
    [rightVC setSelectedIndex: 0];
    
    NSString *lastRightSidebar = [[NSUserDefaults standardUserDefaults] objectForKey: @"RightSidebar"];
    if ([lastRightSidebar isEqualToString: @"ServerUsers"]) {
        [self toggleServerUsers: self];
    } else if ([lastRightSidebar isEqualToString: @"Tracklist"]) {
        [self toggleTrackList: self];
    } else if ([lastRightSidebar isEqualToString: @"Inspector"]) {
        [self toggleInspector: self];
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
    a.holdingPriority = 275; // 250 is default, we want the sidebars to hold
    //[a setTitlebarSeparatorStyle:NSTitlebarSeparatorStyleShadow];
    [splitVC addSplitViewItem:a];

    // prepare the right pane
    NSSplitViewItem*b=[NSSplitViewItem splitViewItemWithViewController:rightVC];
    b.holdingPriority = 266;
    b.titlebarSeparatorStyle = NSTitlebarSeparatorStyleNone;
    [splitVC addSplitViewItem:b];
    
    // prepare the righter pane
    tracklistSplit=[NSSplitViewItem splitViewItemWithViewController:tracklistVC];
    tracklistSplit.holdingPriority = 300;
    // XXX: Not really working like you'd expect
    tracklistSplit.titlebarSeparatorStyle = NSTitlebarSeparatorStyleNone;
    // This uses the width in the nib, which is specified to show everything while not looking ridiculous.
    tracklistSplit.maximumThickness = [tracklistController view].frame.size.width;
    // Width of tracklist title + icon + leading bit of padding + bit of end padding before time
    // tracklistContainmentBox.frame.size.width would be default size to clamp to if you want
    tracklistSplit.minimumThickness = 150 + 36;
    //[tracklistContainmentBox.contentView addSubview: [tracklistController view]];
    // Don't set the view here, we set it when querying defaults for last opened view.
    // Otherwise, we'll confuse it if the view is the one from the defaults
    //tracklistContainmentBox.contentView = [tracklistController view];
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
    
    // HACK: AppKit bug, for some reason, the RPV doesn't get assigned to the NSToolBarItem subview
    // We have to hold a strong reference onto the RPV and slap it in, otherwise it gets dealloc'd.
    routePickerToolbarItem.view = routePicker;
    
    // The tracklist button needs an MOC
    tracklistButton.databaseController = self;
    
    volumeButton.volumePopover = volumePopover;
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
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(resourceName == %@)", @"Library"];
            SBLibrary *section = [self.managedObjectContext fetchEntityNammed:@"Section" withPredicate:predicate error:nil];
            if(section != nil)
                [sourceList expandURIs:[NSArray arrayWithObject:[[[section objectID] URIRepresentation] absoluteString]]];
            
            predicate = [NSPredicate predicateWithFormat:@"(resourceName == %@)", @"Playlists"];
            section = [self.managedObjectContext fetchEntityNammed:@"Section" withPredicate:predicate error:nil];
            if(section != nil)
                [sourceList expandURIs:[NSArray arrayWithObject:[[[section objectID] URIRepresentation] absoluteString]]];
            
            // expand saved expanded source list item
            [sourceList expandURIs:[[NSUserDefaults standardUserDefaults] objectForKey:@"NSOutlineView Items SourceList"]];
            
            [resourcesController removeObserver:self forKeyPath:@"content"];
			
			// load a pdemo server
			SBSection *serversSection = [self.managedObjectContext fetchEntityNammed:@"Section" withPredicate:predicate error:nil];
			
			[sourceList expandURIs:[NSArray arrayWithObject:[[[serversSection objectID] URIRepresentation] absoluteString]]];
			[self.managedObjectContext save:nil];
        }
    } else if (object == self.window.contentView && [keyPath isEqualToString: @"safeAreaInsets"]) { // this should be ok main thread wise
        NSRect targetRect = rightVC.selectedViewController == serverHomeController ? rightVC.view.safeAreaRect : rightVC.view.frame;
        [rightVC.selectedViewController.view setFrameSize: targetRect.size];
    }
}







#pragma mark -
#pragma mark IBAction Methods


- (IBAction)createDemoServer:(id)sender {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(resourceName == %@)", @"Servers"];
    SBSection *serversSection = [self.managedObjectContext fetchEntityNammed:@"Section" withPredicate:predicate error:nil];
    // These values aren't defined in the Core Data model.
    SBServer *s = [SBServer insertInManagedObjectContext:self.managedObjectContext];
    [s setResourceName:@"Subsonic Demo"];
    s.url = @"http://demo.subsonic.org/";
    // Change this in case it gets rotated? It can go up to guest4.
    s.username = @"guest1";
    s.password = @"guest";
    [s updateKeychainPassword]; // or it won't work when switched to
    [serversSection addResourcesObject:s];
    [self.managedObjectContext save:nil];
    
    [self switchToResource: s];
}


- (IBAction)openAudioFiles:(id)sender {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setCanChooseDirectories:YES];
    [openPanel setCanChooseFiles:YES];
    [openPanel setAllowsMultipleSelection: YES];
    
    [openPanel setAllowedContentTypes: [UTType audioToolboxTypes]];
    [openPanel beginSheetModalForWindow: [self window] completionHandler:^(NSModalResponse result) {
        [self openAudioFilesPanelDidEnd: openPanel returnCode: result contextInfo: nil];
    }];

}


- (void)toggleRightSidebar: (NSString*) type {
    NSViewController *newVC = nil;
    if ([type isEqualToString: @"Tracklist"]) {
        newVC = tracklistController;
    } else if ([type isEqualToString: @"ServerUsers"]) {
        newVC = serverUserController;
    } else if ([type isEqualToString: @"Inspector"]) {
        newVC = inspectorController;
    } else {
        NSLog(@"Oops. Unknown right sidebar type %@", type);
        return;
    }
    
    // shared logic
    [self willChangeValueForKey: @"isServerUsersShown"];
    [self willChangeValueForKey: @"isTracklistShown"];
    [self willChangeValueForKey: @"isInspectorShown"];
    NSSplitViewItem *maybeAnimated = self.window.visible ? tracklistSplit.animator : tracklistSplit;
    if (tracklistContainmentBox.contentView != [newVC view]) {
        tracklistContainmentBox.contentView = [newVC view];
        [maybeAnimated setCollapsed: NO];
    } else {
        [maybeAnimated setCollapsed: ![tracklistSplit isCollapsed]];
    }
    [[NSUserDefaults standardUserDefaults] setObject: [tracklistSplit isCollapsed] ? @"" : type forKey: @"RightSidebar"];
    [self didChangeValueForKey: @"isInspectorShown"];
    [self didChangeValueForKey: @"isServerUsersShown"];
    [self didChangeValueForKey: @"isTracklistShown"];
}


- (IBAction)toggleTrackList:(id)sender {
    [self toggleRightSidebar: @"Tracklist"];
}


- (IBAction)toggleServerUsers:(id)sender {
    if (!self.server) {
        return;
    }
    [self toggleRightSidebar: @"ServerUsers"];
}


- (IBAction)toggleInspector:(id)sender {
    [self toggleRightSidebar: @"Inspector"];
}


- (IBAction)toggleVolume:(id)sender {
    BOOL visible = [[self.window.toolbar visibleItems] containsObject: volumeToolbarItem];
    // [self.window.toolbar performSelector:@selector(_toolbarView)] is better, but undocumented
    NSView *view = visible ? volumeButton : self.window.contentView;
    NSRect boundary = view.bounds;
    if (volumePopover.shown) {
        [volumePopover close];
    } else {
        [volumePopover showRelativeToRect: boundary ofView: view preferredEdge:NSMaxYEdge];
    }
}

- (IBAction)addPlaylist:(id)sender {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(resourceName == %@)", @"Playlists"];
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
            
            [addServerPlaylistController setServer:server];
            [addServerPlaylistController openSheet:sender];
        }
    }
}

- (IBAction)addPlaylistToCurrentServer:(id)sender {
    SBServer *server = self.server;
    if(server != nil) {
        [addServerPlaylistController setServer:server];
        [addServerPlaylistController openSheet:sender];
    }
    
}


- (IBAction)addPlaylistFromTracklist:(id)sender {
    NSSet *tracklistSet = [NSSet setWithArray: [[SBPlayer sharedInstance] playlist]];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(resourceName == %@)", @"Playlists"];
    SBSection *playlistsSection = [self.managedObjectContext fetchEntityNammed:@"Section" withPredicate:predicate error:nil];
    
    SBPlaylist *newPlaylist = [SBPlaylist insertInManagedObjectContext:self.managedObjectContext];
    [newPlaylist setResourceName:@"New Saved Tracklist"];
    [newPlaylist setSection:playlistsSection];
    [newPlaylist setTracks: tracklistSet];
    [playlistsSection addResourcesObject:newPlaylist];
    
    [sourceList expandURIs:[NSArray arrayWithObject:[[[playlistsSection objectID] URIRepresentation] absoluteString]]];
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
            
            [alert beginSheetModalForWindow: [self window] completionHandler:^(NSModalResponse returnCode) {
                [self removeItemAlertDidEnd: alert returnCode: returnCode contextInfo: nil];
            }];
        }
    }
}

- (IBAction)addServer:(id)sender {
    [sourceList deselectAll:sender];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(resourceName == %@)", @"Servers"];
    SBSection *serversSection = [self.managedObjectContext fetchEntityNammed:@"Section" withPredicate:predicate error:nil];
    
    SBServer *newServer = [SBServer insertInManagedObjectContext:self.managedObjectContext];
    [newServer setResourceName:@"New Server"];
    [newServer setSection:serversSection];
    [serversSection addResourcesObject:newServer];
    
    [sourceList expandURIs:[NSArray arrayWithObject:[[[serversSection objectID] URIRepresentation] absoluteString]]];
    
    [editServerController setServer:newServer];
    [editServerController openSheet:sender];
    
    // XXX: A notification from EditServerController for switching to it, if created
    // (motiviation is onboarding)
}

- (IBAction)configureCurrentServer:(id)sender {
    if (self.server == nil) {
        return;
    }
    [editServerController setEditMode:YES];
    [editServerController setServer:self.server];
    [editServerController openSheet:sender];
}

- (IBAction)renameItem:(id)sender {
    NSInteger selectedRow = [sourceList selectedRow];
    
    if (selectedRow != -1) {
        SBResource *resource = [[sourceList itemAtRow:selectedRow] representedObject];
        if(resource && ([resource isKindOfClass:[SBPlaylist class]] || [resource isKindOfClass:[SBServer class]]) ) {
            [sourceList editColumn:0 row:selectedRow withEvent:nil select:YES];
        }
    }
}

- (IBAction)editItem:(id)sender {
    NSInteger selectedRow = [sourceList selectedRow];
    
    if (selectedRow != -1) {
        SBResource *resource = [[sourceList itemAtRow:selectedRow] representedObject];
        if(resource && [resource isKindOfClass:[SBPlaylist class]]) {
            [sourceList editColumn:0 row:selectedRow withEvent:nil select:YES];
        } else if(resource && [resource isKindOfClass:[SBServer class]]) {
            [editServerController setEditMode:YES];
            [editServerController setServer:(SBServer *)resource];
            [editServerController openSheet:sender];
        }
    }
}

- (void)reloadServerInternal: (SBServer*)server {
    if (server == nil || ![server isKindOfClass:[SBServer class]]) {
        return;
    }
    [server getServerLicense];
    [server getArtists];
    [server getServerDirectories];
    [server getServerPlaylists];
    // XXX: Check if it's the current VC too?
    if (server != nil && serverHomeController.server == server) {
        [serverHomeController reloadSelected: nil];
    }
    [serverUserController refreshNowPlaying];
}

- (IBAction)reloadServer:(id)sender {
    NSInteger selectedRow = [sourceList selectedRow];
    
    if (selectedRow != -1) {
        SBServer *server = [[sourceList itemAtRow:selectedRow] representedObject];
        [self reloadServerInternal: server];
    }
}

- (IBAction)reloadCurrentServer:(id)sender {
    [self reloadServerInternal: self.server];
}

- (void)scanLibraryInternal: (SBServer*)server {
    if (server == nil || ![server isKindOfClass:[SBServer class]]) {
        return;
    }
    // TODO: This should subscribe to the notifications to observe progress,
    // and kick off a reload event when done
    [server scanLibrary];
}

- (IBAction)scanLibrary:(id)sender {
    NSInteger selectedRow = [sourceList selectedRow];
    
    if (selectedRow != -1) {
        SBServer *server = [[sourceList itemAtRow:selectedRow] representedObject];
        [self scanLibraryInternal: server];
    }
}

- (IBAction)scanCurrentLibrary:(id)sender {
    [self scanLibraryInternal: self.server];
}

- (IBAction)playPause:(id)sender {
    
    if([[SBPlayer sharedInstance] isPlaying] || [[SBPlayer sharedInstance] isPaused]) {
        // player is already running
        [[SBPlayer sharedInstance] playPause];
    } else {
        // isn't playing; start playback
        [[SBPlayer sharedInstance] playTracklistAtBeginning];
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
    if([[SBPlayer sharedInstance] isPlaying]) {
        [[SBPlayer sharedInstance] rewind];
    }
}

- (IBAction)fastForward:(id)sender {
    if([[SBPlayer sharedInstance] isPlaying]) {
        [[SBPlayer sharedInstance] fastForward];
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


- (IBAction)openCurrentServerHomePage:(id)sender {
    SBServer *server = self.server;
    if(server && [server isKindOfClass:[SBServer class]]) {
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:server.url]];
    }
}


- (IBAction)showDownloadView: (id)sender {
    SBDownloads *downloads = (SBDownloads *)[self.managedObjectContext fetchEntityNammed:@"Downloads" withPredicate:nil error:nil];
    [self switchToResource: downloads];
}


- (IBAction)showLibraryView: (id)sender {
    SBLibrary *library = (SBLibrary *)[self.managedObjectContext fetchEntityNammed:@"Library" withPredicate:nil error:nil];
    [self switchToResource: library];
}

- (IBAction)showIndices:(id)sender {
    if (!self.server) {
        return;
    }
    [self.server setSelectedTabIndex: 0];
    SBNavigationItem *navItem = [[SBServerLibraryNavigationItem alloc] initWithServer: self.server];
    [self navigateForwardToNavItem: navItem];
}

- (IBAction)showAlbums:(id)sender {
    if (!self.server) {
        return;
    }
    [self.server setSelectedTabIndex: 1];
    SBNavigationItem *navItem = [[SBServerHomeNavigationItem alloc] initWithServer: self.server];
    [self navigateForwardToNavItem: navItem];
}

- (IBAction)showDirectories:(id)sender {
    if (!self.server) {
        return;
    }
    [self.server setSelectedTabIndex: 3];
    SBNavigationItem *navItem = [[SBServerDirectoriesNavigationItem alloc] initWithServer: self.server];
    [self navigateForwardToNavItem: navItem];
}

- (IBAction)showPodcasts:(id)sender {
    if (!self.server) {
        return;
    }
    [self.server setSelectedTabIndex: 2];
    SBNavigationItem *navItem = [[SBServerPodcastsNavigationItem alloc] initWithServer: self.server];
    [self navigateForwardToNavItem: navItem];
}


- (IBAction)search:(id)sender {
    // XXX: Check for
    if (!self.window.toolbar.visible) {
        [self.window toggleToolbarShown: sender];
        // we need to resend w/ delay because it doesn't work immediately
        [self performSelector: @selector(search:) withObject: sender afterDelay: 0.01];
        return;
    }
    
    BOOL visible = [[self.window.toolbar visibleItems] containsObject: searchToolbarItem];
    if (!visible) {
        return; // we need to focus in it
    }
    
    NSString *query;
    if ([sender isMemberOfClass: [NSSearchField class]]) {
        query = [sender stringValue];
    } else {
        [searchToolbarItem beginSearchInteraction];
        return;
    }
    
    
    if(query && [query length] > 0) {
        SBNavigationItem *navItem = nil;
        if (self.server) {
            navItem = [[SBServerSearchNavigationItem alloc] initWithServer: self.server query: query];
        } else {
            navItem = [[SBLocalSearchNavigationItem alloc] initWithQuery: query];
        }
        [self navigateForwardToNavItem: navItem];
    } else {
        [searchToolbarItem endSearchInteraction];
        if ([rightVC.selectedViewController isKindOfClass: SBMusicSearchController.class]
               || [rightVC.selectedViewController isKindOfClass: SBServerSearchController.class]) {
            [rightVC navigateBack: sender];
        }
    }
}


- (IBAction)cleanTracklist:(id)sender {
    [self stop: sender];
    [tracklistController cleanTracklist: sender];
}

- (void)goToTrack: (SBTrack*)track {
   if (track == nil) {
       return;
   } else if (track.isLocal.boolValue == YES) {
       SBLocalMusicNavigationItem *navItem = [[SBLocalMusicNavigationItem alloc] init];
       navItem.selectedMusicItem = track;
       [self navigateForwardToNavItem: navItem];
   } else {
       [self switchToResource: track.server];
       // XXX: Should this set self.server so everything matches it?
       [serverLibraryController setServer: track.server];
       // as we could be on albums/podcasts
       SBServerLibraryNavigationItem *navItem = [[SBServerLibraryNavigationItem alloc] initWithServer: track.server];
       navItem.selectedMusicItem = track;
       [self navigateForwardToNavItem: navItem];
   }
}


- (IBAction)goToCurrentTrack:(id)sender {
    SBTrack *track = [SBPlayer sharedInstance].currentTrack;
    [self goToTrack: track];
}


- (IBAction)navigateBack:(id)sender {
    [rightVC navigateBack: sender];
}


- (IBAction)navigateForward:(id)sender {
    [rightVC navigateForward: sender];
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
    progressUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
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
}

/// Updates the progress slider, without any preconditions.
- (void)updateProgress {
    
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
    
}

- (void)updateProgress:(NSTimer *)updatedTimer {
    
    if([[SBPlayer sharedInstance] isPlaying]) {
        if ([[SBPlayer sharedInstance] isPaused]) {
            return;
        }
        
        BOOL visible = self.window.occlusionState & NSWindowOcclusionStateVisible;
        if (!visible) {
            return;
        }

        [self updateProgress];
    } else {
        [self clearPlaybackProgress];
    }
}






#pragma mark -
#pragma mark NSOpenPanel Selector

- (void)openAudioFilesPanelDidEnd:(NSOpenPanel *)panel returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    if(returnCode == NSModalResponseOK) {
        NSArray<NSURL*> *files = [panel URLs];
        if(files) {
            [panel orderOut:self];
            [NSApp endSheet:panel];
            
            [self openImportAlert:[self window] files:files];
            
            if (rightVC.selectedViewController != musicController) {
                [self showLibraryView: self];
            }
        }
    }
}


- (void)importSheetDidEnd: (NSWindow *)sheet returnCode: (NSInteger)returnCode contextInfo: (NSArray<NSURL*> *)choosedFiles {
    
    if(returnCode == NSAlertFirstButtonReturn) {
        if(choosedFiles != nil) {
            SBImportOperation *op = [[SBImportOperation alloc]
                                     initWithManagedObjectContext: self.managedObjectContext
                                     files: choosedFiles
                                     copyFiles: YES];
            
            [[NSOperationQueue sharedDownloadQueue] addOperation:op];
        }
        
    } else if(returnCode == NSAlertSecondButtonReturn) {
        if(choosedFiles != nil) {
            SBImportOperation *op = [[SBImportOperation alloc]
                                     initWithManagedObjectContext: self.managedObjectContext
                                     files: choosedFiles
                                     copyFiles: NO];
            
            [[NSOperationQueue sharedDownloadQueue] addOperation:op];
        }
    }
}


- (void)removeItemAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSAlertFirstButtonReturn) {
        NSInteger selectedRow = [sourceList selectedRow];
        
        if (selectedRow != -1) {
            SBResource *resource = [[sourceList itemAtRow:selectedRow] representedObject];
            if (resource == nil) {
                // What was the point?
                return;
            }
            // FIXME: Remove references from the navigation stack
            if (self.server == resource) {
                // Clean out any possible state involving this server...
                self.server = nil;
                // if it's open, close it
                if (tracklistContainmentBox.contentView == [serverUserController view]) {
                    // keeps the sidebar open
                    [self toggleTrackList: nil];
                }
                [self showLibraryView: nil];
            }
            if ([resource isKindOfClass:[SBPlaylist class]]) {
                SBPlaylist *playlist = (SBPlaylist *)resource;
                SBServer *server = playlist.server;
                
                if (server != nil) {
                    [server deletePlaylistWithID: playlist.itemId];
                }
            }
            if ([resource isKindOfClass:[SBPlaylist class]] || [resource isKindOfClass:[SBServer class]]) {
                [self.managedObjectContext deleteObject:resource];
                [self.managedObjectContext processPendingChanges];
            }
        }
    }
}







#pragma mark -
#pragma mark Private Methods

- (void)updateTitle {
    if ([[SBPlayer sharedInstance] isPlaying]) {
        // Let the notification handle it for us, for now
        return;
    }
    [self.window setTitle: rightVC.selectedViewController.title ?: @""];
    [self.window setSubtitle: @""];
}

- (void)populatedDefaultSections {
    NSPredicate *predicate = nil;
    SBSection *section = nil;
    NSError *error = nil;
    
    // library section
    predicate = [NSPredicate predicateWithFormat:@"(resourceName == %@)", @"Library"];
    section = [self.managedObjectContext fetchEntityNammed:@"Section" withPredicate:predicate error:&error];
    if(!section) {
        predicate = [NSPredicate predicateWithFormat:@"(resourceName == %@)", @"LIBRARY"];
        section = [self.managedObjectContext fetchEntityNammed:@"Section" withPredicate:predicate error:&error];
        if (section) {
            [section setResourceName: @"Library"];
        } else {
            section = [SBSection insertInManagedObjectContext:self.managedObjectContext];
            [section setResourceName:@"Library"];
            [section setIndex:[NSNumber numberWithInteger:0]];
        }
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
    
    // playlist section
    predicate = [NSPredicate predicateWithFormat:@"(resourceName == %@)", @"Playlists"];
    section = [self.managedObjectContext fetchEntityNammed:@"Section" withPredicate:predicate error:&error];
    if(!section) {
        predicate = [NSPredicate predicateWithFormat:@"(resourceName == %@)", @"PLAYLISTS"];
        section = [self.managedObjectContext fetchEntityNammed:@"Section" withPredicate:predicate error:&error];
        if (section) {
            [section setResourceName: @"Playlists"];
        } else {
            section = [SBSection insertInManagedObjectContext:self.managedObjectContext];
            [section setResourceName:@"Playlists"];
            [section setIndex:[NSNumber numberWithInteger:1]];
        }
    }
    
    // servers section
    predicate = [NSPredicate predicateWithFormat:@"(resourceName == %@)", @"Servers"];
    section = [self.managedObjectContext fetchEntityNammed:@"Section" withPredicate:predicate error:&error];
    if(!section) {
        predicate = [NSPredicate predicateWithFormat:@"(resourceName == %@)", @"SERVERS"];
        section = [self.managedObjectContext fetchEntityNammed:@"Section" withPredicate:predicate error:&error];
        if (section) {
            [section setResourceName: @"Servers"];
        } else {
            section = [SBSection insertInManagedObjectContext:self.managedObjectContext];
            [section setResourceName:@"Servers"];
            [section setIndex:[NSNumber numberWithInteger:2]];
        }
    }
    
    //[sourceList expandAllItems];
    
    //[outlineView expandURIs:];
    
    [[self managedObjectContext] processPendingChanges];
    [[self managedObjectContext] save:nil];
}

- (SBServer*) server {
    return server;
}

- (void)setServer:(SBServer *)newServer {
    server = newServer;
    // yes, even if nil
    editServerController.server = server;
    addServerPlaylistController.server = server;
    serverHomeController.server = server;
    serverDirectoryController.server = server;
    serverUserController.server = server;
    serverSearchController.server = server;
    serverLibraryController.server = server;
    serverPodcastController.server = server;
    // XXX: Reload anything that's current? i.e. now playing?
}

- (void) updateSourceListSelection: (SBResource*)resource {
    SBResource *sidebarResource = resource;
    if ([sidebarResource isKindOfClass:[SBArtist class]] || [sidebarResource isKindOfClass:[SBAlbum class]]) {
        sidebarResource = (SBLibrary *)[self.managedObjectContext fetchEntityNammed:@"Library" withPredicate:nil error:nil];
    }
    NSIndexPath *newPath = [resourcesController indexPathForObject: resource];
    if (newPath != nil && ![newPath isEqualTo: resourcesController.selectionIndexPath]) {
        ignoreNextSelection = YES;
        [resourcesController setSelectionIndexPath: newPath];
    }
}

- (void)switchToResource:(SBResource*)resource updateSidebar:(BOOL)updateSidebar {
    if (resource && [resource isKindOfClass: [SBServer class]]) {
        SBServer *server = (SBServer *)resource;
        [server connect];
    } else if (resource && [resource isKindOfClass: [SBPlaylist class]]) {
        SBPlaylist *playlist = (SBPlaylist *)resource;
        if (playlist.server) {
            [playlist.server connect];
        }
    }
    // Must be after the connection.
    if (resource) {
        [self displayViewControllerForResource:resource];
    }
    // For cases where we get a resource change that didn't come from the source list
    if (updateSidebar) {
        [self updateSourceListSelection: resource];
    }
}

- (void)switchToResource:(SBResource*)resource {
    [self switchToResource: resource updateSidebar: YES];
}

- (void)displayViewControllerForResource:(SBResource *)resource {
    // NSURLs dont go to plists
    if (!([resource isKindOfClass: [SBResource class]] || [resource isKindOfClass: [SBMusicItem class]])) {
        return;
    }
    NSString *urlString = resource.objectID.URIRepresentation.absoluteString;
    [[NSUserDefaults standardUserDefaults] setObject: urlString forKey: @"LastViewedResource"];
    // swith view relative to a selected resource
    SBNavigationItem *navItem = nil;
    if([resource isKindOfClass:[SBLibrary class]]) {
        navItem = [[SBLocalMusicNavigationItem alloc] init];
    }  else if([resource isKindOfClass:[SBDownloads class]]) {
        navItem = [[SBDownloadsNavigationItem alloc] init];
    } else if([resource isKindOfClass:[SBPlaylist class]]) {
        navItem = [[SBPlaylistNavigationItem alloc] initWithPlaylist: (SBPlaylist*)resource];
    } else if([resource isKindOfClass:[SBServer class]]) {
        SBServer *server = (SBServer*)resource;
        switch ([server selectedTabIndex]) {
            case 0:
            default:
                navItem = [[SBServerLibraryNavigationItem alloc] initWithServer: server];
                break;
            case 1:
                navItem = [[SBServerHomeNavigationItem alloc] initWithServer: server];
                break;
            case 2:
                navItem = [[SBServerPodcastsNavigationItem alloc] initWithServer: server];
                break;
            case 3:
                navItem = [[SBServerDirectoriesNavigationItem alloc] initWithServer: server];
                break;
        }
    } else if([resource isKindOfClass:[SBAlbum class]]) {
        SBAlbum *album = (SBAlbum*)resource;
        // take advantage of existing logic
        if (album.artist.server != nil) {
            [self switchToResource: album.artist.server];
            [serverLibraryController showAlbumInLibrary: album];
            // XXX: Make sure we're on the right controller?
        } else {
            SBLibrary *library = (SBLibrary *)[self.managedObjectContext fetchEntityNammed:@"Library" withPredicate:nil error:nil];
            [self switchToResource: library];
            [musicController showAlbumInLibrary: album];
        }
    } else if([resource isKindOfClass:[SBArtist class]]) {
        SBArtist *artist = (SBArtist*)resource;
        if (artist.server != nil) {
            [self switchToResource: artist.server];
            [serverLibraryController showArtistInLibrary: artist];
        } else {
            SBLibrary *library = (SBLibrary *)[self.managedObjectContext fetchEntityNammed:@"Library" withPredicate:nil error:nil];
            [self switchToResource: library];
            [musicController showArtistInLibrary: artist];
        }
    }
    
    if (navItem) {
        [self navigateForwardToNavItem: navItem];
    }
}


- (BOOL)openImportAlert:(NSWindow *)sender files:(NSArray<NSURL*> *)files {
    NSAlert *importAlert = [[NSAlert alloc] init];
    [importAlert setMessageText:@"Do you want to copy the imported audio files?"];
    [importAlert setInformativeText: @"The files will copied into the library directory, or have the new library items link to the original files."];
    [importAlert addButtonWithTitle: @"Copy into Library"];
    [importAlert addButtonWithTitle: @"Link Existing Files"];
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

- (void)subsonicPlaylistUpdatedNotification:(NSNotification *)notification {
    // HACK: we should send the notification about the playlist ID + server specifically, but this will do for now
    [self subsonicPlaylistsCreatedNotification: notification];
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
    [self.server getArtists];
    [self.server getServerPlaylists];
}



#pragma mark -
#pragma mark Window Notification (Private)

- (void)windowDidChangeOcclusionState:(NSNotification *)notification {
    NSWindow *sender = [notification object];
    if ([sender isEqual:self.window]) {
        BOOL visible = self.window.occlusionState & NSWindowOcclusionStateVisible;
        BOOL playing = [[SBPlayer sharedInstance] isPlaying];
        if (visible && playing) {
            // call updateProgress to always update, as updateProgress: from the timer will bail early if paused
            [self updateProgress];
            [self installProgressTimer];
        }
        else {
            [self uninstallProgressTimer];
        }
    }
}





#pragma mark -
#pragma mark Player Notifications (Private)

- (void)playerPlaylistUpdatedNotification:(NSNotification *)notification {
    SBTrack *currentTrack = [[SBPlayer sharedInstance] currentTrack];
    
    if(currentTrack != nil) {
        
        NSString *trackInfos = [[SBPlayer sharedInstance] subtitle];
        [self.window setTitle:currentTrack.itemName];
        [self.window setSubtitle:trackInfos];
    } else {
        [self.window setTitle: rightVC.selectedViewController.title ?: @""];
        [self.window setSubtitle: @""];
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
        }
        else {
            [playPauseButton setState:NSControlStateValueOn];
        }
    } else {
        [self uninstallProgressTimer];
        [self clearPlaybackProgress];
        [playPauseButton setState:NSControlStateValueOn];
    }
}

- (void)playerHaveMovieToPlayNotification:(NSNotification *)notification {
    // We get this on playlist update but in theory, we could get it for specific media in the future
    //[self displayViewControllerForResource:[notification object]];
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
    NSString *newName = (NSString*)object;
    SBResource *resource = (SBResource*)[item representedObject];
    // Let the remote server have a say first, just do it for local
    if ([resource isKindOfClass: SBPlaylist.class] && [(SBPlaylist*)resource server] != nil) {
        SBPlaylist *playlist = (SBPlaylist*)resource;
        [playlist.server updatePlaylistWithID: playlist.itemId name: newName comment: nil appending: nil removing: nil];
    } else {
        [resource setResourceName: newName];
    }
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
    NSArray<SBTrack*> *tracks = [info.draggingPasteboard libraryItemsWithManagedObjectContext: self.managedObjectContext];
    if (tracks == nil) {
        return NSDragOperationNone;
    }
    SBTrack *firstTrack = [tracks firstObject];
    if ([[item representedObject] isKindOfClass:[SBPlaylist class]]) {
        SBPlaylist *targetPlaylist = [item representedObject];
        
        if (targetPlaylist.server == nil) { // is local playlist and local track
            return NSDragOperationCopy;
        } else if ([targetPlaylist.server isEqualTo:firstTrack.server]) {
            return NSDragOperationCopy;
        }
    } else if ([[item representedObject] isKindOfClass:[SBDownloads class]] || [[item representedObject] isKindOfClass:[SBLibrary class]]) {
        // if remote or not in cache
        if (firstTrack.server != nil || (firstTrack.server != nil && firstTrack.localTrack == nil)) {
            return NSDragOperationCopy;
        }
    }
    
    return NSDragOperationNone;
}


- (BOOL)sourceList:(SBSourceList *)aSourceList acceptDrop:(id<NSDraggingInfo>)info item:(id)item childIndex:(NSInteger)index {
    NSArray<SBTrack*> *tracks = [info.draggingPasteboard libraryItemsWithManagedObjectContext: self.managedObjectContext];
    if (tracks == nil) {
        return NO;
    }
    if ([[item representedObject] isKindOfClass:[SBPlaylist class]]) {
        SBPlaylist *playlist = (SBPlaylist *)[item representedObject];
        
        if(playlist.server == nil) {
            // also add new track IDs to the array
            [tracks enumerateObjectsUsingBlock:^(SBTrack *track, NSUInteger idx, BOOL *stop) {
                [track setPlaylistIndex:[NSNumber numberWithInteger:[playlist.tracks count]]];
                [playlist addTracksObject:track];
            }];
        } else {
            NSString *playlistID = playlist.itemId;
            
            // append these tracks using the updatePlaylist endpoint
            [playlist.server updatePlaylistWithID: playlistID name: nil comment: nil appending: tracks removing: nil];
        }
        
        return YES;
    } else if ([[item representedObject] isKindOfClass:[SBDownloads class]] || [[item representedObject] isKindOfClass:[SBLibrary class]]) {
		[self switchToResource:[item representedObject]];
        
        // also add new track IDs to the array
        [tracks enumerateObjectsUsingBlock:^(SBTrack *track, NSUInteger idx, BOOL *stop) {
            // download track
            SBSubsonicDownloadOperation *op = [[SBSubsonicDownloadOperation alloc]
                                               initWithManagedObjectContext: self.managedObjectContext
                                               trackID: [track objectID]];
            
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
        if(downloadsController.itemCount > 0)
            result = YES;
    }
    
    return result;
}

- (NSInteger)sourceList:(SBSourceList*)aSourceList badgeValueForItem:(id)item {
    NSInteger result = 0;
    
    if ([[item representedObject] isKindOfClass:[SBDownloads class]]) {
        if(downloadsController.itemCount > 0)
            result = downloadsController.itemCount;
    }
    
    return result;
}





#pragma mark -
#pragma mark SourceList Delegate

- (void)sourceListSelectionDidChange:(NSNotification *)notification {
    if (ignoreNextSelection) {
        ignoreNextSelection = NO;
        return;
    }
    NSInteger selectedRow = [sourceList selectedRow];
    
    if (selectedRow != -1) {
        SBResource *resource = [[sourceList itemAtRow:selectedRow] representedObject];
        
        [self switchToResource: resource updateSidebar: NO];
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
    
    if([[[group representedObject] resourceName] isEqualToString:@"Library"])
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
    
    if([[item representedObject] isKindOfClass:[SBPlaylist class]])
        return NO;
    
    return YES;

}

- (NSMenu*)sourceList:(SBSourceList *)aSourceList menuForEvent:(NSEvent*)theEvent item:(id)item {
    
    if ([theEvent type] == NSEventTypeRightMouseDown || ([theEvent type] == NSEventTypeLeftMouseDown && ([theEvent modifierFlags] & NSEventModifierFlagControl) == NSEventModifierFlagControl)) {
    
        
        if(item != nil) {
            SBResource *resource = [item representedObject];
            
            if([resource isKindOfClass:[SBPlaylist class]]) {
                
                NSMenu * m = [[NSMenu alloc] init];
                
                [m addItemWithTitle: @"Rename Playlist" action:@selector(editItem:) keyEquivalent:@""];
                [m addItemWithTitle: @"Delete Playlist" action:@selector(removeItem:) keyEquivalent:@""];
                
                return m;
                
            } else if([resource isKindOfClass:[SBServer class]]) {
                
                NSMenu * m = [[NSMenu alloc] init];
                
                [m addItemWithTitle:@"Add Playlist to Server" action:@selector(addRemotePlaylist:) keyEquivalent:@""];
                [m addItem:[NSMenuItem separatorItem]];
                [m addItemWithTitle:@"Reload Server" action:@selector(reloadServer:) keyEquivalent:@""];
                [m addItemWithTitle:@"Scan Server Library" action:@selector(scanLibrary:) keyEquivalent:@""];
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
               [self removeItem:self];
           }
    }
}



#pragma mark -
#pragma mark NSPageController Delegate

/// Called after a page transition.
- (void) resetViewAfterTransition {
    // Title
    [self updateTitle];
    // HACK: The scope bar will be under the title bar without using the safe area.
    // However, using the full rect allows other views to adapt and put vibrance of scrolled over content under title bar.
    // Thus, use the one that's appropriate for each..
    NSRect targetRect = rightVC.selectedViewController == serverHomeController ? rightVC.view.safeAreaRect : rightVC.view.frame;
    [rightVC.selectedViewController.view setFrameSize: targetRect.size];
}


- (void)saveNavItemState {
    if ([rightVC selectedIndex] == -1 || [rightVC.arrangedObjects count] == 0) {
        return;
    }
    SBNavigationItem *navItem = [rightVC.arrangedObjects objectAtIndex: [rightVC selectedIndex]];
    if ([navItem isKindOfClass: SBLocalMusicNavigationItem.class]) {
        SBLocalMusicNavigationItem *musicNavItem = (SBLocalMusicNavigationItem*)navItem;
        musicNavItem.selectedMusicItem = [musicController selectedItem];
    } else if ([navItem isKindOfClass: SBServerLibraryNavigationItem.class]) {
        SBServerLibraryNavigationItem *musicNavItem = (SBServerLibraryNavigationItem*)navItem;
        musicNavItem.selectedMusicItem = [serverLibraryController selectedItem];
    }
}


- (void)navigateForwardToNavItem: (SBNavigationItem*)navItem {
    // We have to bottleneck the the navigation, so it'll properly save state.
    // Back/forward gets handled in beginning live transition.
    [self saveNavItemState];
    [rightVC navigateForwardToObject: navItem];
}


- (NSRect)pageController:(NSPageController *)pageController frameForObject:(id)object {
    // Otherwise, the albums view will look weird in a transition.
    if ([object isKindOfClass: SBServerHomeNavigationItem.class]) {
        return rightVC.view.safeAreaRect;
    }
    return rightVC.view.frame;
}


- (void)pageController:(NSPageController *)pageController prepareViewController:(NSViewController *)viewController withObject:(id)object {
    // Unknown what we'd do with this guy, since we finalize changes after transition
    [viewController viewDidAppear];
}


// All view changes like query, server, etc. now occur here, so navigation works properly.
- (void)pageController:(NSPageController *)pageController didTransitionToObject:(id)object {
    SBNavigationItem *navItem = (SBNavigationItem*)object;
    // Server
    if ([navItem isKindOfClass: SBServerNavigationItem.class]) {
        SBServerNavigationItem *serverNavItem = (SBServerNavigationItem*)navItem;
        self.server = serverNavItem.server;
        [self updateSourceListSelection: serverNavItem.server];
    } else if ([navItem isKindOfClass: SBPlaylistNavigationItem.class]) {
        SBPlaylistNavigationItem *playlistNavItem = (SBPlaylistNavigationItem*)navItem;
        SBPlaylist *playlist = playlistNavItem.playlist;
        // set server for UI properly recognizes this
        self.server = playlist.server;
        
        [self updateSourceListSelection: playlist];
    } else {
        self.server = nil;
    }
    // Search (search bar enablement is below)
    if ([navItem isKindOfClass: SBLocalSearchNavigationItem.class]) {
        SBLocalSearchNavigationItem *searchNavItem = (SBLocalSearchNavigationItem*)navItem;
        [musicSearchController searchString: searchNavItem.query];
        [searchField setStringValue: searchNavItem.query];
    } else if ([navItem isKindOfClass: SBServerSearchNavigationItem.class]) {
        SBServerSearchNavigationItem *searchNavItem = (SBServerSearchNavigationItem*)navItem;
        [self.server searchWithQuery: searchNavItem.query];
        [searchField setStringValue: searchNavItem.query];
    } else {
        [searchField setStringValue: @""];
        [searchToolbarItem endSearchInteraction];
    }
    // Playlist
    if ([navItem isKindOfClass: SBPlaylistNavigationItem.class]) {
        SBPlaylistNavigationItem *playlistNavItem = (SBPlaylistNavigationItem*)navItem;
        SBPlaylist *playlist = playlistNavItem.playlist;
        [playlistController setPlaylist: playlist];
        if (playlist.server != nil) { // is remote playlist
            // clear playlist
            [playlistController clearPlaylist];
            
            // update playlist
            [playlist.server getPlaylistTracks:playlist];
        }
        [self updateSourceListSelection: playlistNavItem.playlist];
    }
    // Selected item
    // XXX: Kinda messed up by the fact the controllers and nav item don't have a common ancestor for music item
    if ([navItem isKindOfClass: SBLocalMusicNavigationItem.class]) {
        SBLocalMusicNavigationItem *musicNavItem = (SBLocalMusicNavigationItem*)navItem;
        if ([musicNavItem.selectedMusicItem isKindOfClass: SBTrack.class]) {
            [musicController showTrackInLibrary: (SBTrack*)musicNavItem.selectedMusicItem];
        } else if ([musicNavItem.selectedMusicItem isKindOfClass: SBAlbum.class]) {
            [musicController showAlbumInLibrary: (SBAlbum*)musicNavItem.selectedMusicItem];
        } else if ([musicNavItem.selectedMusicItem isKindOfClass: SBArtist.class]) {
            [musicController showArtistInLibrary: (SBArtist*)musicNavItem.selectedMusicItem];
        }
    } else if ([navItem isKindOfClass: SBServerLibraryNavigationItem.class]) {
        SBServerLibraryNavigationItem *musicNavItem = (SBServerLibraryNavigationItem*)navItem;
        if ([musicNavItem.selectedMusicItem isKindOfClass: SBTrack.class]) {
            [serverLibraryController showTrackInLibrary: (SBTrack*)musicNavItem.selectedMusicItem];
        } else if ([musicNavItem.selectedMusicItem isKindOfClass: SBAlbum.class]) {
            [serverLibraryController showAlbumInLibrary: (SBAlbum*)musicNavItem.selectedMusicItem];
        } else if ([musicNavItem.selectedMusicItem isKindOfClass: SBArtist.class]) {
            [serverLibraryController showArtistInLibrary: (SBArtist*)musicNavItem.selectedMusicItem];
        }
    }
    // Search bar
    if ([navItem isKindOfClass: SBLocalMusicNavigationItem.class] || [navItem isKindOfClass: SBLocalSearchNavigationItem.class]) {
        [searchToolbarItem setEnabled: YES];
        [searchField setPlaceholderString: @"Local Search"];
    } else if ([navItem isKindOfClass: SBServerNavigationItem.class] || [navItem isKindOfClass: SBServerSearchNavigationItem.class]) {
        [searchToolbarItem setEnabled: YES];
        [searchField setPlaceholderString: @"Server Search"];
    } else {
        [searchToolbarItem setEnabled: NO];
        [searchField setPlaceholderString: @""];
    }
    // Sidebar for downloads/library cases
    if ([navItem isKindOfClass: SBDownloadsNavigationItem.class]) {
        SBDownloads *downloads = (SBDownloads *)[self.managedObjectContext fetchEntityNammed:@"Downloads" withPredicate:nil error:nil];
        [self updateSourceListSelection: downloads];
    } else if ([navItem isKindOfClass: SBLocalMusicNavigationItem.class]) {
        SBLibrary *library = (SBLibrary *)[self.managedObjectContext fetchEntityNammed:@"Library" withPredicate:nil error:nil];
        [self updateSourceListSelection: library];
    }
    
    [self resetViewAfterTransition];
}


- (void)pageControllerWillStartLiveTransition:(NSPageController *)pageController {
    // Save the state into our current one. Only triggered for back/forward though.
    [self saveNavItemState];
}


- (void)pageControllerDidEndLiveTransition:(NSPageController *)pageController {
    [rightVC completeTransition];
    // Still looks awkward, VC only changes here
    [self resetViewAfterTransition];
}

// ~~~~

- (NSString *)pageController:(NSPageController *)pageController identifierForObject:(id)object {
    SBNavigationItem *navItem = (SBNavigationItem*)object;
    return navItem.identifier;
}


- (NSViewController *)pageController:(NSPageController *)pageController viewControllerForIdentifier:(NSString *)identifier {
    static SBViewController *tempVC = nil;
    static NSDictionary *mapping = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        tempVC = [[SBViewController alloc] init];
        tempVC.view = [[NSView alloc] initWithFrame: rightVC.view.frame];
        mapping = @{
            @"Music": musicController,
            @"Onboarding": onboardingController,
            @"Downloads": downloadsController,
            @"ServerLibrary": serverLibraryController,
            @"ServerHome": serverHomeController,
            @"ServerDirectories": serverDirectoryController,
            @"ServerPodcasts": serverPodcastController,
            @"ServerSearch": serverSearchController,
            @"MusicSearch": musicSearchController,
            @"Playlist": playlistController,
            @"": tempVC,
        };
    });
    return mapping[identifier];
}

#pragma mark -
#pragma mark UI Validator

// XXX: Toolbars too
- (BOOL)validateUserInterfaceItem: (id<NSValidatedUserInterfaceItem>) item {
    SEL action = [item action];
    
    BOOL isPlaying = [[SBPlayer sharedInstance] isPlaying];
    BOOL tracklistHasItems = [[[SBPlayer sharedInstance] playlist] count] > 0;
    
    if (action == @selector(playPause:)) {
        return isPlaying || tracklistHasItems;
    }
    if (action == @selector(stop:)
        || action == @selector(rewind:) || action == @selector(fastForward:)
        || action == @selector(goToCurrentTrack:)) {
        return isPlaying;
    }
    if (action == @selector(cleanTracklist:)) {
        return tracklistHasItems;
    }
    // Similar, but could use if prv/next track exist
    if (action == @selector(previousTrack:) || action == @selector(nextTrack:)) {
        return isPlaying;
    }
    
    // only works if we have a server set
    if (action == @selector(showIndices:)
        || action == @selector(showAlbums:)
        || action == @selector(showDirectories:)
        || action == @selector(reloadCurrentServer:)
        || action == @selector(openCurrentServerHomePage:)
        || action == @selector(addPlaylistToCurrentServer:)
        || action == @selector(configureCurrentServer:)
        || action == @selector(scanCurrentLibrary:)) {
        return self.server != nil;
    }
    
    if (action == @selector(showPodcasts:)) {
        return self.server != nil && [self.server.supportsPodcasts boolValue];
    }
    
    if (action == @selector(toggleServerUsers:)) {
        return self.server != nil && [self.server.supportsNowPlaying boolValue];
    }
    
    if (action == @selector(search:)) {
        // Covers toolbar not having search item and visible, covers toolbar having search item and not visible, but not both
        BOOL canBeVisible = [[self.window.toolbar visibleItems] containsObject: searchToolbarItem] || !self.window.toolbar.visible;
        return [searchToolbarItem isEnabled] && canBeVisible;
    }
    
    if (action == @selector(renameItem:)) {
        if (self.window.firstResponder != sourceList) {
            return NO;
        }
        NSInteger selectedRow = [sourceList selectedRow];
        if (selectedRow != -1) {
            SBResource *resource = [[sourceList itemAtRow:selectedRow] representedObject];
            return ([resource isKindOfClass:[SBPlaylist class]] || [resource isKindOfClass:[SBServer class]]);
        } else {
            return NO;
        }
    }
    
    if (action == @selector(navigateBack:)) {
        return rightVC.selectedIndex > 0;
    } else if (action == @selector(navigateForward:)) {
        return rightVC.selectedIndex < rightVC.arrangedObjects.count - 1;
    }
    
    if (action == @selector(addPlaylistFromTracklist:)) {
        return [[SBPlayer sharedInstance] playlist].count > 0;
    }
    
    return YES;
}

#pragma mark - Bindings for Interface Toggles

- (NSNumber*)isTracklistShown {
    return [NSNumber numberWithBool: (!tracklistSplit.collapsed &&
            (tracklistContainmentBox.contentView == tracklistController.view))];
}

- (void)setIsTracklistShown:(NSNumber *)isTracklistShown {
    [self toggleTrackList: nil];
}

- (NSNumber*)isServerUsersShown {
    return [NSNumber numberWithBool: (!tracklistSplit.collapsed &&
            (tracklistContainmentBox.contentView == serverUserController.view))];
}

- (void)setIsServerUsersShown:(NSNumber *)isServerUsersShown {
    [self toggleServerUsers: nil];
}

- (NSNumber*)isInspectorShown {
    return [NSNumber numberWithBool: (!tracklistSplit.collapsed &&
            (tracklistContainmentBox.contentView == inspectorController.view))];
}

- (void)setIsInspectorShown:(NSNumber *)isServerUsersShown {
    [self toggleInspector: nil];
}

@end




