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
#import "SBMusicTopbarController.h"
#import "SBTracklistController.h"
#import "SBPlaylistController.h"
#import "SBServerTopbarController.h"
#import "SBDownloadsController.h"
#import "SBAnimatedView.h"
#import "SBSpinningProgressIndicator.h"
#import "SBImportOperation.h"
#import "SBSubsonicParsingOperation.h"
#import "SBSubsonicDownloadOperation.h"
#import "SBPlayer.h"
#import "SBTableView.h"
#import "RWStreamingSliderCell.h"

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
#import "NSView+CHLayout.h"
#import "CHLayoutConstraint.h"



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
- (void)animateTrackListButton;
- (void)updateProgress:(NSTimer *)updatedTimer;

// notifications
- (void)subsonicPlaylistsUpdatedNotification:(NSNotification *)notification;
- (void)subsonicPlaylistsCreatedNotification:(NSNotification *)notification;
- (void)playerPlaylistUpdatedNotification:(NSNotification *)notification;
- (void)playerPlayStateNotification:(NSNotification *)notification;
- (void)playerHaveMovieToPlayNotification:(NSNotification *)notification;

@end




@implementation SBDatabaseController


@synthesize resourceSortDescriptors;
@synthesize addServerPlaylistController;
@synthesize currentView;
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
        resourceSortDescriptors = [[NSMutableArray arrayWithObject:sd1] retain];
        
        // init view controllers
        musicController = [[SBMusicController alloc] initWithManagedObjectContext:self.managedObjectContext];
        musicTopbarController = [[SBMusicTopbarController alloc] initWithManagedObjectContext:self.managedObjectContext];
        downloadsController = [[SBDownloadsController alloc] initWithManagedObjectContext:self.managedObjectContext];
        tracklistController = [[SBTracklistController alloc] initWithManagedObjectContext:self.managedObjectContext];
        playlistController = [[SBPlaylistController alloc] initWithManagedObjectContext:self.managedObjectContext];
        serverTopbarController = [[SBServerTopbarController alloc] initWithManagedObjectContext:self.managedObjectContext];
        
        [tracklistController setDatabaseController:self];
    }
    return self;
}

- (void)dealloc
{
    // remove queue operations observer
    [[NSOperationQueue sharedServerQueue] removeObserver:self forKeyPath:@"operationCount"];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    // release all object references
    [musicController release];
    [musicTopbarController release];
    [downloadsController release];
    [tracklistController release];
    [playlistController release];
    [serverTopbarController release];
    [resourceSortDescriptors release];
    [library release];
    [progressUpdateTimer release];
    
    [super dealloc];
}




#pragma mark -
#pragma mark Window Controller

- (void)windowDidLoad {  
    
    [super windowDidLoad];
    
    // images templates
    NSImage *image = [NSImage imageNamed:@"users"];
    [image setTemplate:YES];
    
    image = [NSImage imageNamed:@"search"];
    [image setTemplate:YES];
    
    image = [NSImage imageNamed:@"NSUserAccounts"];
    [image setTemplate:YES];
    
    image = [NSImage imageNamed:@"Podcast"];
    [image setTemplate:YES];
    
    image = [NSImage imageNamed:@"ServerHome"];
    [image setTemplate:YES];
    
    // populate default sections
    [self populatedDefaultSections];
    
    // edit controllers
    [editServerController setManagedObjectContext:self.managedObjectContext];
    [addServerPlaylistController setManagedObjectContext:self.managedObjectContext];
    [musicController setDatabaseController:self];
    [musicTopbarController setDatabaseController:self];
    [musicTopbarController setMusicController:musicController];
    
    // source list drag and drop
    [sourceList registerForDraggedTypes:[NSArray arrayWithObject:SBLibraryTableViewDataType]];
    
    // add the ability to server topbar to change view with animation
    [serverTopbarController setDatabaseController:self];
    
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

    // setup main box subviews animation 
    [self setCurrentView:(SBAnimatedView *)[musicController view]];
    [self.currentView setFrameSize:[mainBox frame].size];
    
    NSView *contentView = [mainBox contentView];
    //[contentView setWantsLayer:YES];
    [contentView addSubview:[self currentView]];
    
    transition = [CATransition animation];
    [transition setType:kCATransitionFade];
    [transition setDuration:0.05f];
    
    NSDictionary *ani = [NSDictionary dictionaryWithObject:transition 
                                                    forKey:@"subviews"];
    [contentView setAnimations:ani];
    
    [topbarBox setContentView:[musicTopbarController view]];
    [self setCurrentView:(SBAnimatedView *)[musicController view]];
                
    
    // player timer
    progressUpdateTimer = [[NSTimer scheduledTimerWithTimeInterval:0.01
                                                           target:self
                                                         selector:@selector(updateProgress:)
                                                         userInfo:nil
                                                          repeats:YES] retain];
    
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
    //a.canCollapse=NO;

    // prepare the right pane
    NSSplitViewItem*b=[NSSplitViewItem splitViewItemWithViewController:rightVC];
    b.titlebarSeparatorStyle = NSTitlebarSeparatorStyleNone;
    [splitVC addSplitViewItem:b];
    // swap the old NSSplitView with the new one
    [self.window.contentView replaceSubview:mainSplitView with:splitVC.view ];

    // set up the constraints so that the new `NSSplitView` to fill the window
    [splitVC.view.topAnchor constraintEqualToAnchor:self.window.contentView.topAnchor
                                           constant:0].active=YES;
    [splitVC.view.bottomAnchor constraintEqualToAnchor:((NSLayoutGuide*)self.window.contentLayoutGuide).bottomAnchor].active=YES;
    [splitVC.view.leftAnchor constraintEqualToAnchor:((NSLayoutGuide*)self.window.contentLayoutGuide).leftAnchor].active=YES;
    [splitVC.view.rightAnchor constraintEqualToAnchor:((NSLayoutGuide*)self.window.contentLayoutGuide).rightAnchor].active=YES;
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
    
    [openPanel beginSheetForDirectory:nil 
                                 file:nil 
                                types:types 
                       modalForWindow:[self window] 
                        modalDelegate:self 
                       didEndSelector:@selector(openAudioFilesPanelDidEnd:returnCode:contextInfo:) 
                          contextInfo:nil];

}


- (IBAction)toggleTrackList:(id)sender {
    tracklistPopoverVC.view = tracklistController.view;
    NSView *view = playPauseButton;
    NSRect boundary = view.bounds;
    if (tracklistPopover.shown) {
        [tracklistPopover close];
    } else {
        [tracklistPopover showRelativeToRect: boundary ofView: view preferredEdge:NSMaxYEdge];
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
            
            NSAlert *alert = [[[NSAlert alloc] init] autorelease];
            [alert addButtonWithTitle:@"OK"];
            [alert addButtonWithTitle:@"Cancel"];
            [alert setMessageText:@"Delete the selected server playlist?"];
            [alert setInformativeText:@"Deleted server playlists cannot be restored."];
            [alert setAlertStyle:NSWarningAlertStyle];
            
            [super showVisualCue];
            
            [alert beginSheetModalForWindow:[self window] 
                              modalDelegate:self 
                             didEndSelector:@selector(deleteServerPlaylistAlertDidEnd:returnCode:contextInfo:) 
                                contextInfo:nil];
            
        }
    }
}


- (IBAction)removeItem:(id)sender {
    NSInteger selectedRow = [sourceList selectedRow];
    
    if (selectedRow != -1) {
        SBResource *resource = [[[sourceList itemAtRow:selectedRow] representedObject] retain];
        if(resource && ([resource isKindOfClass:[SBPlaylist class]] || [resource isKindOfClass:[SBServer class]])) {
            
            NSAlert *alert = [[[NSAlert alloc] init] autorelease];
            [alert addButtonWithTitle:@"OK"];
            [alert addButtonWithTitle:@"Cancel"];
            [alert setMessageText:@"Delete the selected item?"];
            [alert setInformativeText:@"Deleted items cannot be restored."];
            [alert setAlertStyle:NSWarningAlertStyle];
            
            [super showVisualCue];
            
            [alert beginSheetModalForWindow:[self window] 
                              modalDelegate:self 
                             didEndSelector:@selector(removeItemAlertDidEnd:returnCode:contextInfo:) 
                                contextInfo:nil];
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

- (IBAction)setVolume:(id)sender {
    [[SBPlayer sharedInstance] setVolume:[sender floatValue]];
}

- (IBAction)setMuteOn:(id)sender {
    [[SBPlayer sharedInstance] setVolume:0.0f];
}

- (IBAction)setMuteOff:(id)sender {
    [[SBPlayer sharedInstance] setVolume:1.0f];
}

- (IBAction)shuffle:(id)sender {
    if([sender state] == NSOnState) {
        [[SBPlayer sharedInstance] setIsShuffle:YES];
        
    } else if([sender state] == NSOffState) {
        [[SBPlayer sharedInstance] setIsShuffle:YES];
    }
}

- (IBAction)repeat:(id)sender {
    
    if([sender state] == NSOnState) {
        [[SBPlayer sharedInstance] setRepeatMode:SBPlayerRepeatAll];
        [sender setAlternateImage:[NSImage imageWithSystemSymbolName: @"repeat.circle.fill" accessibilityDescription: @"Repeat On"]];
    } 
    if([sender state] == NSOffState) {
        [[SBPlayer sharedInstance] setRepeatMode:SBPlayerRepeatNo];
    } 
    if([sender state] == NSMixedState) {
        [[SBPlayer sharedInstance] setRepeatMode:SBPlayerRepeatOne];
        [sender setAlternateImage:[NSImage imageWithSystemSymbolName: @"repeat.1.circle.fill" accessibilityDescription: @"Repeat One"]];
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
	[self setCurrentView:(SBAnimatedView *)[downloadsController view]];
	[topbarBox setContentView:nil];
}



#pragma mark -
#pragma mark NSTimer

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
        [progressSlider setEnabled:NO];
        [progressTextField setStringValue:@"00:00"];
        [durationTextField setStringValue:@"-00:00"];
        [progressSlider setDoubleValue:0];

    }
    
}






#pragma mark -
#pragma mark NSOpenPanel Selector

- (void)openAudioFilesPanelDidEnd:(NSOpenPanel *)panel returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    if(returnCode == NSOKButton) {
        NSArray *files = [panel filenames];
        if(files) {
            
            [panel orderOut:self];
            [NSApp endSheet:panel];
            
            [self openImportAlert:[self window] files:[files retain]];
        }
    } else {
        [super hideVisualCue];
    }
}


- (void)importSheetDidEnd: (NSWindow *)sheet returnCode: (NSInteger)returnCode contextInfo: (void *)contextInfo {
    
    if(returnCode == NSAlertDefaultReturn) {
        
        NSArray *choosedFiles = (NSArray *)contextInfo;
        if(choosedFiles != nil) {
            
            SBImportOperation *op = [[SBImportOperation alloc] initWithManagedObjectContext:self.managedObjectContext];
            [op setFilePaths:choosedFiles];
            [op setLibraryID:[library objectID]];
            [op setCopy:YES];
            [op setRemove:NO];
            
            [[NSOperationQueue sharedDownloadQueue] addOperation:op];
        }
        
    } else if(returnCode == NSAlertAlternateReturn) {
        
        NSArray *choosedFiles = (NSArray *)contextInfo;
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
            SBResource *resource = [[[sourceList itemAtRow:selectedRow] representedObject] retain];
            if(resource && ([resource isKindOfClass:[SBPlaylist class]] || [resource isKindOfClass:[SBServer class]])) {
                [self.managedObjectContext deleteObject:resource];
                [resource release];
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
    library = [[self.managedObjectContext fetchEntityNammed:@"Library" withPredicate:predicate error:&error] retain];
    if(!library) {
        library = [[SBLibrary insertInManagedObjectContext:self.managedObjectContext] retain];
        [library setResourceName:@"Music"];
        [library setIndex:[NSNumber numberWithInteger:0]];
        [library setSection:section];
        [self.managedObjectContext assignObject:library toPersistentStore:[self.managedObjectContext.persistentStoreCoordinator.persistentStores objectAtIndex:0]];
    }
    
    // DOWNLOADS resource
    predicate = [NSPredicate predicateWithFormat:@"(resourceName == %@)", @"Downloads"];
    resource = [[self.managedObjectContext fetchEntityNammed:@"Downloads" withPredicate:predicate error:&error] retain];
    if(!resource) {
        resource = [[SBDownloads insertInManagedObjectContext:self.managedObjectContext] retain];
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


- (void)displayViewControllerForResource:(SBResource *)resource {
    // swith view relative to a selected resource
    if([resource isKindOfClass:[SBLibrary class]]) {

        [self setCurrentView:(SBAnimatedView *)[musicController view]];
        
        [topbarBox setContentView:nil];
        [topbarBox setContentView:[musicTopbarController view]];
        
    }  else if([resource isKindOfClass:[SBDownloads class]]) {
    
        [self setCurrentView:(SBAnimatedView *)[downloadsController view]];
        
        [topbarBox setContentView:nil];
        //[topbarBox setContentView:[musicTopbarController view]];
        
    } else if([resource isKindOfClass:[SBTracklist class]]) {
        
        [self setCurrentView:(SBAnimatedView *)[tracklistController view]];
        
        [topbarBox setContentView:nil];
        //[topbarBox setContentView:[musicTopbarController view]];
        
    } else if([resource isKindOfClass:[SBPlaylist class]]) {
        
        [playlistController setPlaylist:(SBPlaylist *)resource];
        [self setCurrentView:(SBAnimatedView *)[playlistController view]];
        
        [topbarBox setContentView:nil];
        //[topbarBox setContentView:[musicTopbarController view]];
        
    } else if([resource isKindOfClass:[SBServer class]]) {
    
        [topbarBox setContentView:nil];
        [topbarBox setContentView:[serverTopbarController view]];
        
        [serverTopbarController setServer:(SBServer *)resource];  
        [serverTopbarController setViewControllerAtIndex:[(SBServer *)resource selectedTabIndex]];

    }
}


- (void)setCurrentView:(SBAnimatedView *)newView {
    if (!currentView) {
        currentView = newView;
        return;
    }
    NSView *contentView = [mainBox contentView];
    [[contentView animator] replaceSubview:currentView with:newView];
    [newView setFrameSize:[mainBox frame].size];
    currentView = newView;
}


- (BOOL)openImportAlert:(NSWindow *)sender files:(NSArray *)files {
    NSBeginAlertSheet(
                      @"Do you want to copy imported audio files ?",
                      @"Copy",    
                      @"Link",    
                      @"Cancel",  
                      sender,     
                      self,       
                      @selector(importSheetDidEnd:returnCode:contextInfo:),
                      NULL,   
                      files,  
                      @"If you click the \"Copy\" button, imported files will be copied into the database. If you click the \"Link\" button, files will no be copied, but linked into the database.");
    
    //[files autorelease];
    return NO;
}


- (void)animateTrackListButton {

    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"pulse"];
    [animation setDuration:5.0f];
    [animation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];

    [[toggleButton layer] addAnimation:animation forKey:@"backgroungColor"];
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




#pragma mark -
#pragma mark Player Notifications (Private)

- (void)playerPlaylistUpdatedNotification:(NSNotification *)notification {
    SBTrack *currentTrack = [[SBPlayer sharedInstance] currentTrack];
    
    if(currentTrack != nil) {
        
        NSString *trackInfos = [NSString stringWithFormat:@"%@ - %@", currentTrack.artistString, currentTrack.albumString];
        SBCover *cover = currentTrack.album.cover;
        NSImage *coverImage = nil;
        
        if(cover && cover.imagePath) {
            coverImage = [[[NSImage alloc] initWithContentsOfFile:cover.imagePath] autorelease];
        } else {
            coverImage = [NSImage imageNamed:@"NoArtwork"];
        }
        
        [trackTitleTextField setStringValue:currentTrack.itemName];
        [trackInfosTextField setStringValue:trackInfos];
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
        [trackTitleTextField setStringValue:@""];
        [trackInfosTextField setStringValue:@""];
        [self.window setTitle: @""];
        [self.window setSubtitle: @""];
        [onlineImageView setImage:nil];
        [coverImageView setImage:[NSImage imageNamed:@"NoArtwork"]];
        [playPauseButton setState:NSOnState];
    }
}
- (void)playerPlayStateNotification:(NSNotification *)notification {
    SBTrack *currentTrack = [[SBPlayer sharedInstance] currentTrack];
    
    if(currentTrack != nil) {
        if([[SBPlayer sharedInstance] isPaused]) {
            [playPauseButton setState:NSOffState];
            NSLog(@"Paused?");
        }
        else {
            [playPauseButton setState:NSOnState];
            NSLog(@"Playing?");
        }
    } else {
        [playPauseButton setState:NSOnState];
        NSLog(@"Stopped?");
    }
}

- (void)playerHaveMovieToPlayNotification:(NSNotification *)notification {
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
    
    if([[item representedObject] isKindOfClass:[SBPlaylist class]]) {
        if([[[info draggingPasteboard] types] containsObject:SBLibraryTableViewDataType]) {
            NSData *data = [[info draggingPasteboard] dataForType:SBLibraryTableViewDataType];
            NSArray *tracksURIs = [NSKeyedUnarchiver unarchiveObjectWithData:data]; 
            
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
        NSArray *tracksURIs = [NSKeyedUnarchiver unarchiveObjectWithData:data]; 
        
        SBTrack *firstTrack = (SBTrack *)[self.managedObjectContext objectWithID:[self.managedObjectContext.persistentStoreCoordinator managedObjectIDForURIRepresentation:[tracksURIs objectAtIndex:0]]];
        
        // if remote or not in cache
        if(firstTrack.server != nil || (firstTrack.server != nil && firstTrack.localTrack == nil)) {
            return NSDragOperationCopy;
        }
    }
    
    return NSDragOperationNone;
}


- (BOOL)sourceList:(SBSourceList *)aSourceList acceptDrop:(id<NSDraggingInfo>)info item:(id)item childIndex:(NSInteger)index {
    
    if([[item representedObject] isKindOfClass:[SBPlaylist class]]) {
        SBPlaylist *playlist = (SBPlaylist *)[item representedObject];
        
        if([[[info draggingPasteboard] types] containsObject:SBLibraryTableViewDataType]) {
           
            if(playlist.server == nil) {
                NSData *data = [[info draggingPasteboard] dataForType:SBLibraryTableViewDataType];
                NSArray *tracksURIs = [NSKeyedUnarchiver unarchiveObjectWithData:data]; 
                
                // also add new track IDs to the array
                [tracksURIs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    SBTrack *track = (SBTrack *)[self.managedObjectContext objectWithID:[[self.managedObjectContext persistentStoreCoordinator] managedObjectIDForURIRepresentation:obj]]; 
                    
                    [track setPlaylistIndex:[NSNumber numberWithInteger:[playlist.tracks count]]];
                    [playlist addTracksObject:track];
                }];
            } else {
                
                NSData *data = [[info draggingPasteboard] dataForType:SBLibraryTableViewDataType];
                NSArray *tracksURIs = [NSKeyedUnarchiver unarchiveObjectWithData:data]; 
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
        NSArray *tracksURIs = [NSKeyedUnarchiver unarchiveObjectWithData:data]; 
        
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
    
    if([[item representedObject] isKindOfClass:[SBTracklist class]])
        return NO;
    
    if([[item representedObject] isKindOfClass:[SBSection class]])
        return NO;
    
    if([[item representedObject] isKindOfClass:[SBPlaylist class]] && ((SBPlaylist *)[item representedObject]).server != nil)
        return NO;
    
    return YES;

}

- (NSMenu*)sourceList:(SBSourceList *)aSourceList menuForEvent:(NSEvent*)theEvent item:(id)item {
    
	if ([theEvent type] == NSRightMouseDown || ([theEvent type] == NSLeftMouseDown && ([theEvent modifierFlags] & NSControlKeyMask) == NSControlKeyMask)) {
    
        
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
                
                return [m autorelease];
                
            } else if([resource isKindOfClass:[SBServer class]]) {
                
                NSMenu * m = [[NSMenu alloc] init];
                
                [m addItemWithTitle:@"Add Playlist to Server" action:@selector(addRemotePlaylist:) keyEquivalent:@""];
                [m addItemWithTitle:@"Reload Server" action:@selector(reloadServer:) keyEquivalent:@""];
                [m addItem:[NSMenuItem separatorItem]];
                [m addItemWithTitle:@"Open Home Page" action:@selector(openHomePage:) keyEquivalent:@""];
                [m addItemWithTitle:@"Configure Server" action:@selector(editItem:) keyEquivalent:@""];
                [m addItem:[NSMenuItem separatorItem]];
                [m addItemWithTitle:@"Remove Server" action:@selector(removeItem:) keyEquivalent:@""];
                
                
                return [m autorelease];
            }
            
        } else {
            NSMenu * m = [[NSMenu alloc] init];
            
            [m addItemWithTitle:@"Add Playlist" action:@selector(addPlaylist:) keyEquivalent:@""];
            [m addItemWithTitle:@"Add Server" action:@selector(addServer:) keyEquivalent:@""];
            
            return [m autorelease];
        }
	}
	return nil;
}


- (id)sourceList:(SBSourceList *)aSourceList persistentObjectForItem:(id)item {
    return [[[[item representedObject] objectID] URIRepresentation] absoluteString];
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
	if([tracklistPopover isShown])
		[self toggleTrackList:nil];
}

- (void)windowWillMove:(NSNotification *)notification {
    containerView.frame = rightVC.view.safeAreaRect;
    if([tracklistPopover isShown]) {
        [self toggleTrackList:nil];
    }
}

- (void)windowWillStartLiveResize:(NSNotification *)notification {
    containerView.frame = rightVC.view.safeAreaRect;
    if([tracklistPopover isShown]) {
        [self toggleTrackList:nil];
    }
}


- (void)windowWillMiniaturize:(NSNotification *)notification {
    if([tracklistPopover isShown]) {
        [self toggleTrackList:nil];
    }
}


@end




