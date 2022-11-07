//
//  SBServerHomeController.m
//  Submariner
//
//  Created by Rafaël Warnault on 08/06/11.
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

#import "SBServerHomeController.h"
#import "SBDatabaseController.h"
#import "SBAddServerPlaylistController.h"
#import "SBTrack.h"
#import "SBAlbum.h"
#import "SBServer.h"
#import "SBPlayer.h"
#import "SBSubsonicDownloadOperation.h"
#import "SBOperationActivity.h"
#import "NSOperationQueue+Shared.h"



// scope bar const
#define GROUP_LABEL				@"Label"			// string
#define GROUP_SEPARATOR			@"HasSeparator"		// BOOL as NSNumber
#define GROUP_SELECTION_MODE	@"SelectionMode"	// MGScopeBarGroupSelectionMode (int) as NSNumber
#define GROUP_ITEMS				@"Items"			// array of dictionaries, each containing the following keys:
#define ITEM_IDENTIFIER			@"Identifier"		// string
#define ITEM_NAME				@"Name"				// string




@interface SBServerHomeController ()
- (void)subsonicCoversUpdatedNotification:(NSNotification *)notification;
@end





@implementation SBServerHomeController



+ (NSString *)nibName {
    return @"ServerHome";
}


- (NSString*)title {
    return [NSString stringWithFormat: @"Albums on %@", self.server.resourceName];
}



@synthesize trackSortDescriptor;
@synthesize databaseController;



- (id)initWithManagedObjectContext:(NSManagedObjectContext *)context {
    self = [super initWithManagedObjectContext:context];
    if (self) {
        scopeGroups = [[NSMutableArray alloc] init];
        
        NSSortDescriptor *albumDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"itemName" ascending:YES];
        albumSortDescriptor = @[albumDescriptor];
        
        NSSortDescriptor *trackNumberDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"trackNumber" ascending:YES];
        NSSortDescriptor *discNumberDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"discNumber" ascending:YES];
        trackSortDescriptor = @[discNumberDescriptor, trackNumberDescriptor];
    }
    return self;
}


- (void)dealloc {
    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:@"coverSize"];
}

- (void)viewDidAppear {
    [super viewDidAppear];
    // XXX: see -[SBMusicController viewDidAppear]
    [albumsBrowserView setZoomValue:[[NSUserDefaults standardUserDefaults] floatForKey:@"coverSize"]];
}


- (void)loadView {
    [super loadView];
    
    // scope bar
    NSArray *items = [NSArray arrayWithObjects:
					  [NSDictionary dictionaryWithObjectsAndKeys: 
                       @"RandomItem", ITEM_IDENTIFIER, 
                       @"Random", ITEM_NAME, nil], 
					  [NSDictionary dictionaryWithObjectsAndKeys: 
                       @"NewestItem", ITEM_IDENTIFIER, 
                       @"Newest", ITEM_NAME, nil],
                      [NSDictionary dictionaryWithObjectsAndKeys: 
                       @"HighestItem", ITEM_IDENTIFIER, 
                       @"Highest", ITEM_NAME, nil],
                      [NSDictionary dictionaryWithObjectsAndKeys: 
                       @"FrequentItem", ITEM_IDENTIFIER, 
                       @"Frequent", ITEM_NAME, nil],
                      [NSDictionary dictionaryWithObjectsAndKeys: 
                       @"RecentItem", ITEM_IDENTIFIER, 
                       @"Recent", ITEM_NAME, nil],
					  nil];
	
	[scopeGroups addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                            @"Browse By:", GROUP_LABEL,
                            [NSNumber numberWithBool:NO], GROUP_SEPARATOR, 
                            [NSNumber numberWithInt:MGScopeBarGroupSelectionModeRadio], GROUP_SELECTION_MODE, // single selection group.
                            items, GROUP_ITEMS, 
                            nil]];
    
    [scopeBar setSelected:YES forItem:@"RandomItem" inGroup:0];

    [scopeBar sizeToFit];
    // This will call reloadServersWithIdentifier: for us.
    [scopeBar reloadData];

    
    // tracks double click
    [tracksTableView setTarget:self];
    [tracksTableView setDoubleAction:@selector(trackDoubleClick:)];
    [tracksTableView registerForDraggedTypes:[NSArray arrayWithObject:SBLibraryTableViewDataType]];
        
    // tracks drag & drop
    //[tracksTableView registerForDraggedTypes:[NSArray arrayWithObjects:SBLibraryTableViewDataType, nil]];
   
    [albumsBrowserView setZoomValue:[[NSUserDefaults standardUserDefaults] floatForKey:@"coverSize"]];
    
    // observe album covers
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(subsonicCoversUpdatedNotification:) 
                                                 name:SBSubsonicCoversUpdatedNotification
                                               object:nil];
    
    [[NSUserDefaults standardUserDefaults] addObserver:self
                                            forKeyPath:@"coverSize" 
                                               options:NSKeyValueObservingOptionNew
                                               context:nil];
}


- (void) reloadServersWithIdentifier: (NSString*)identifier {
    if([identifier isEqualToString:@"RandomItem"]) {
        [self.server getAlbumListForType:SBSubsonicRequestGetAlbumListRandom];
    } else if([identifier isEqualToString:@"NewestItem"]) {
        [self.server getAlbumListForType:SBSubsonicRequestGetAlbumListNewest];
    } else if([identifier isEqualToString:@"HighestItem"]) {
        [self.server getAlbumListForType:SBSubsonicRequestGetAlbumListHighest];
    } else if([identifier isEqualToString:@"FrequentItem"]) {
        [self.server getAlbumListForType:SBSubsonicRequestGetAlbumListFrequent];
    } else if([identifier isEqualToString:@"RecentItem"]) {
        [self.server getAlbumListForType:SBSubsonicRequestGetAlbumListRecent];
    }
}


#pragma mark - 
#pragma mark IBActions

- (IBAction)trackDoubleClick:(id)sender {
    NSInteger selectedRow = [tracksTableView selectedRow];
    if(selectedRow != -1) {
        SBTrack *clickedTrack = [[tracksController arrangedObjects] objectAtIndex:selectedRow];
        if(clickedTrack) {
            
            // stop current playing tracks
            //[[SBPlayer sharedInstance] stop];
            
            // add track to player
            if([[NSUserDefaults standardUserDefaults] integerForKey:@"playerBehavior"] == 1) {
                [[SBPlayer sharedInstance] addTrackArray:[tracksController arrangedObjects] replace:YES];
                // play track
                [[SBPlayer sharedInstance] playTrack:clickedTrack];
            } else {
                [[SBPlayer sharedInstance] addTrackArray:[tracksController arrangedObjects] replace:NO];
                [[SBPlayer sharedInstance] playTrack:clickedTrack];
            }
        }
    }
}

- (IBAction)albumDoubleClick:(id)sender {
    NSIndexSet *indexSet = [albumsBrowserView selectionIndexes];
    NSInteger selectedRow = [indexSet firstIndex];
    if(selectedRow != -1) {
        SBAlbum *doubleClickedAlbum = [[albumsController arrangedObjects] objectAtIndex:selectedRow];
        if(doubleClickedAlbum) {
            
            NSArray *tracks = [doubleClickedAlbum.tracks sortedArrayUsingDescriptors:trackSortDescriptor];
            
            // stop current playing tracks
            //[[SBPlayer sharedInstance] stop];
            
            // add track to player
            if([[NSUserDefaults standardUserDefaults] integerForKey:@"playerBehavior"] == 1) {
                [[SBPlayer sharedInstance] addTrackArray:tracks replace:YES];
                // play track
                [[SBPlayer sharedInstance] playTrack:[tracks objectAtIndex:0]];
            } else {
                [[SBPlayer sharedInstance] addTrackArray:tracks replace:NO];
                [[SBPlayer sharedInstance] playTrack:[tracks objectAtIndex:0]];
            }
        }
    }
}


- (IBAction)playSelected:(id)sender {
    NSResponder *responder = self.databaseController.window.firstResponder;
    if (responder == tracksTableView) {
        [self trackDoubleClick: self];
    } else if (responder == albumsBrowserView) {
        [self albumDoubleClick: self];
    }
}

- (IBAction)addAlbumToTracklist:(id)sender {
    NSIndexSet *indexSet = [albumsBrowserView selectionIndexes];
    NSInteger selectedRow = [indexSet firstIndex];
    
    if(selectedRow != -1) {
        SBAlbum *album = [[albumsController arrangedObjects] objectAtIndex:selectedRow];
        [[SBPlayer sharedInstance] addTrackArray:[album.tracks sortedArrayUsingDescriptors:trackSortDescriptor] replace:NO];
    }
}


- (IBAction)addTrackToTracklist:(id)sender {
    NSIndexSet *indexSet = [tracksTableView selectedRowIndexes];
    NSMutableArray *tracks = [NSMutableArray array];
    
    [indexSet enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        [tracks addObject:[[tracksController arrangedObjects] objectAtIndex:idx]];
    }];
    
    [[SBPlayer sharedInstance] addTrackArray:tracks replace:NO];
}


- (IBAction)addSelectedToTracklist:(id)sender {
    NSResponder *responder = self.databaseController.window.firstResponder;
    if (responder == tracksTableView) {
        [self addTrackToTracklist: self];
    } else if (responder == albumsBrowserView) {
        [self addAlbumToTracklist: self];
    }
}


- (IBAction)createNewLocalPlaylistWithSelectedTracks:(id)sender {
    NSInteger selectedRow = [tracksTableView selectedRow];
    
    if(selectedRow == -1) {
        return;
    }
    
    [self createLocalPlaylistWithSelected: tracksController.arrangedObjects selectedIndices: tracksTableView.selectedRowIndexes databaseController: self.databaseController];
}


- (IBAction)createNewPlaylistWithSelectedTracks:(id)sender {
    // get selected rows track objects
    NSIndexSet *rowIndexes = [tracksTableView selectedRowIndexes];
    NSMutableArray *trackIDs = [NSMutableArray array];
    
    // create an IDs array
    [rowIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        [trackIDs addObject:[[[tracksController arrangedObjects] objectAtIndex:idx] id]];
    }];
    
    [databaseController.addServerPlaylistController setServer:self.server];
    [databaseController.addServerPlaylistController setTrackIDs:trackIDs];
    [databaseController.addServerPlaylistController openSheet:sender];
}

- (IBAction)downloadTrack:(id)sender {
    NSInteger selectedRow = [tracksTableView selectedRow];
    
    if(selectedRow != -1) {
        [self downloadTracks: tracksController.arrangedObjects selectedIndices: tracksTableView.selectedRowIndexes databaseController: databaseController];
    }
}


- (IBAction)downloadAlbum:(id)sender{
    NSIndexSet *indexSet = [albumsBrowserView selectionIndexes];
    NSInteger selectedRow = [indexSet firstIndex];
    if(selectedRow != -1) {
        SBAlbum *doubleClickedAlbum = [[albumsController arrangedObjects] objectAtIndex:selectedRow];
        if(doubleClickedAlbum) {
            [databaseController showDownloadView: self];
			
            NSArray *tracks = [doubleClickedAlbum.tracks sortedArrayUsingDescriptors:trackSortDescriptor];
            
            for(SBTrack *track in tracks) {
                SBSubsonicDownloadOperation *op = [[SBSubsonicDownloadOperation alloc] initWithManagedObjectContext:self.managedObjectContext];
                [op setTrackID:[track objectID]];
                [op.activity setOperationName:[NSString stringWithFormat:@"Downloading %@", track.itemName]];
                [op.activity setOperationInfo:@"Pending Request..."];
                
                [[NSOperationQueue sharedDownloadQueue] addOperation:op];
            }
        }
    }
}


- (IBAction)downloadSelected:(id)sender {
    NSResponder *responder = self.databaseController.window.firstResponder;
    if (responder == tracksTableView) {
        [self downloadTrack: self];
    } else if (responder == albumsBrowserView) {
        [self downloadAlbum: self];
    }
}


- (IBAction)showSelectedInFinder:(id)sender {
    NSInteger selectedRow = [tracksTableView selectedRow];
    
    if(selectedRow == -1) {
        return;
    }
    
    [self showTracksInFinder: tracksController.arrangedObjects selectedIndices: tracksTableView.selectedRowIndexes];
}


- (IBAction)reloadSelected: (id)sender {
    NSArray *nested = scopeBar.selectedItems.firstObject;
    NSString *identifier = nested.firstObject;
    [self reloadServersWithIdentifier: identifier];
}


#pragma mark - 
#pragma mark Observers

- (void)observeValueForKeyPath:(NSString *)keyPath 
                      ofObject:(id)object 
                        change:(NSDictionary *)change 
                       context:(void *)context {
    
    if(object && [keyPath isEqualToString:@"tracks"] && [object isKindOfClass:[SBAlbum class]]) {
        
        NSSet *set = [object valueForKey:@"tracks"];
        if(set && [set count] > 0) {
            [tracksController setContent:[object valueForKey:@"tracks"]];
            [tracksTableView reloadData];
            
            [object removeObserver:self forKeyPath:@"tracks"];
        }
        
    } else if(object == [NSUserDefaults standardUserDefaults] && [keyPath isEqualToString:@"coverSize"]) {
        [albumsBrowserView setZoomValue:[[NSUserDefaults standardUserDefaults] floatForKey:@"coverSize"]];
        [albumsBrowserView setNeedsDisplay:YES];
    }
}



#pragma mark - 
#pragma mark Notification

- (void)subsonicCoversUpdatedNotification:(NSNotification *)notification {
    [albumsBrowserView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
}





#pragma mark -
#pragma mark IKImageBrowserViewDelegate

- (void)imageBrowserSelectionDidChange:(IKImageBrowserView *)aBrowser {
    
    // get tracks
    NSInteger selectedRow = [[aBrowser selectionIndexes] firstIndex];
    if(selectedRow != -1 && selectedRow < [[albumsController arrangedObjects] count]) {
        
        SBAlbum *album = [[albumsController arrangedObjects] objectAtIndex:selectedRow];
        if(album) {
            
            // reset current tracks
            [tracksController setContent:nil];
            [self.server getTracksForAlbumID:album.id];
            
            if([album.tracks count] == 0) {   
                // wait for new tracks
                [album addObserver:self
                        forKeyPath:@"tracks"
                           options:(NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionPrior | NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld)
                           context:NULL];
            } else {
                [tracksController setContent:album.tracks];
            }
        }
    }
}

- (void)imageBrowser:(IKImageBrowserView *)aBrowser cellWasDoubleClickedAtIndex:(NSUInteger)index {
    [self albumDoubleClick:nil];
}






#pragma mark -
#pragma mark NSTableView (Drag & Drop)

- (BOOL)tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard {
    
    BOOL ret = NO;
    if(tableView == tracksTableView) {
        /*** Internal drop track */
        NSMutableArray *trackURIs = [NSMutableArray array];
        
        // get tracks URIs
        [rowIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
            SBTrack *track = [[tracksController arrangedObjects] objectAtIndex:idx];
            [trackURIs addObject:[[track objectID] URIRepresentation]];
        }];
        
        // encode to data
        NSError *error = nil;
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:trackURIs requiringSecureCoding: YES error: &error];
        if (error != nil) {
            NSLog(@"Error archiving track URIs: %@", error);
            return NO;
        }
        
        // register data to pastboard
        [pboard declareTypes:[NSArray arrayWithObject:SBLibraryTableViewDataType] owner:self];
        [pboard setData:data forType:SBLibraryTableViewDataType];
        ret = YES;
    }
    return ret;
}



#pragma mark -
#pragma mark Tracks NSTableView DataSource (Rating)

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
    if(aTableView == tracksTableView) {
        if([[aTableColumn identifier] isEqualToString:@"rating"]) {
            
            NSInteger selectedRow = [tracksTableView selectedRow];
            if(selectedRow != -1) {
                SBTrack *clickedTrack = [[tracksController arrangedObjects] objectAtIndex:selectedRow];
                
                if(clickedTrack) {
                    
                    NSInteger rating = [anObject intValue];
                    NSString *trackID = [clickedTrack id];
                    
                    [self.server setRating:rating forID:trackID];
                }
            }
        }
    }
}



#pragma mark -
#pragma mark MGScopeBarDelegate methods


- (NSInteger)numberOfGroupsInScopeBar:(MGScopeBar *)theScopeBar {
	return (int)[scopeGroups count];
}


- (NSArray *)scopeBar:(MGScopeBar *)theScopeBar itemIdentifiersForGroup:(NSInteger)groupNumber {
    return [[scopeGroups objectAtIndex:groupNumber] valueForKeyPath:[NSString stringWithFormat:@"%@.%@", GROUP_ITEMS, ITEM_IDENTIFIER]];
}


- (NSString *)scopeBar:(MGScopeBar *)theScopeBar labelForGroup:(NSInteger)groupNumber {
	return [[scopeGroups objectAtIndex:groupNumber] objectForKey:GROUP_LABEL];;
}


- (NSString *)scopeBar:(MGScopeBar *)theScopeBar titleOfItem:(NSString *)identifier inGroup:(NSInteger)groupNumber {
    NSArray *items = [[scopeGroups objectAtIndex:groupNumber] objectForKey:GROUP_ITEMS];
    if (items) {
        for (NSDictionary *item in items) {
            if ([[item objectForKey:ITEM_IDENTIFIER] isEqualToString:identifier]) {
                return [item objectForKey:ITEM_NAME];
                break;
            }
        }
    } 
	return nil;
}


- (MGScopeBarGroupSelectionMode)scopeBar:(MGScopeBar *)theScopeBar selectionModeForGroup:(NSInteger)groupNumber {
	return (MGScopeBarGroupSelectionMode)[[[scopeGroups objectAtIndex:groupNumber] objectForKey:GROUP_SELECTION_MODE] intValue];
}


- (NSImage *)scopeBar:(MGScopeBar *)scopeBar imageForItem:(NSString *)identifier inGroup:(NSInteger)groupNumber {
    if ([identifier isEqualToString: @"RandomItem"]) {
        return [NSImage imageWithSystemSymbolName: @"shuffle" accessibilityDescription: @"Random"];
    } else if ([identifier isEqualToString: @"NewestItem"]) {
        return [NSImage imageWithSystemSymbolName: @"wand.and.stars" accessibilityDescription: @"Random"];
    } else if ([identifier isEqualToString: @"HighestItem"]) {
        return [NSImage imageWithSystemSymbolName: @"star.fill" accessibilityDescription: @"Highest"];
    } else if ([identifier isEqualToString: @"FrequentItem"]) {
        return [NSImage imageWithSystemSymbolName: @"heart.fill" accessibilityDescription: @"Frequent"];
    } else if ([identifier isEqualToString: @"RecentItem"]) {
        return [NSImage imageWithSystemSymbolName: @"clock.arrow.circlepath" accessibilityDescription: @"Recent"];
    }
    
	return nil;
}


- (void)scopeBar:(MGScopeBar *)theScopeBar selectedStateChanged:(BOOL)selected forItem:(NSString *)identifier inGroup:(NSInteger)groupNumber {
    
    [albumsBrowserView setSelectionIndexes:nil byExtendingSelection:NO];
    
    [self reloadServersWithIdentifier: identifier];
}



#pragma mark -
#pragma mark UI Validator

- (BOOL)validateUserInterfaceItem: (id<NSValidatedUserInterfaceItem>) item {
    SEL action = [item action];
    
    NSInteger albumSelected = albumsBrowserView.selectionIndexes.count;
    NSInteger tracksSelected = tracksTableView.selectedRowIndexes.count;
    
    NSResponder *responder = self.databaseController.window.firstResponder;
    BOOL tracksActive = responder == tracksTableView;
    BOOL albumsActive = responder == albumsBrowserView;
    
    SBSelectedRowStatus selectedTrackRowStatus = 0;
    if (tracksActive) {
        selectedTrackRowStatus = [self selectedRowStatus: tracksController.arrangedObjects selectedIndices: tracksTableView.selectedRowIndexes];
    }
    
    if (action == @selector(addSelectedToTracklist:)
        || action == @selector(playSelected:)) {
        return (albumSelected > 0 || tracksSelected > 0) && (albumsActive || tracksActive);
    }
    
    if (action == @selector(createNewPlaylistWithSelectedTracks:)
        || action == @selector(trackDoubleClick:)
        || action == @selector(addTrackToTracklist:)
        || action == @selector(createNewLocalPlaylistWithSelectedTracks:)) {
        return tracksSelected > 0 && tracksActive;
    }
    
    if (action == @selector(showSelectedInFinder:)) {
        return selectedTrackRowStatus & SBSelectedRowShowableInFinder;
    }
    
    if (action == @selector(downloadTrack:)) {
        return selectedTrackRowStatus & SBSelectedRowDownloadable;
    }
    
    if (action == @selector(downloadSelected:)) {
        return (selectedTrackRowStatus & SBSelectedRowDownloadable) || (albumSelected > 0 && albumsActive);
    }
    
    // context menu
    if (action == @selector(downloadAlbum:)
        || action == @selector(addAlbumToTracklist:)
        || action == @selector(albumDoubleClick:)) {
        return albumsActive && albumSelected > 0;
    }

    return YES;
}


@end
