//
//  SBServerController.m
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

#import "SBServerLibraryController.h"
#import "SBDatabaseController.h"
#import "SBAddServerPlaylistController.h"
#import "SBSubsonicParsingOperation.h"
#import "SBSubsonicDownloadOperation.h"
#import "SBPlayer.h"
#import "SBTableView.h"
#import "SBServer.h"
#import "SBIndex.h"
#import "SBGroup.h"
#import "SBArtist.h"
#import "SBAlbum.h"
#import "SBTrack.h"
#import "SBOperationActivity.h"
#import "SBPrioritySplitViewDelegate.h"
#import "NSOperationQueue+Shared.h"


// main split view constant
#define LEFT_VIEW_INDEX 0
#define LEFT_VIEW_PRIORITY 2
#define LEFT_VIEW_MINIMUM_WIDTH 175.0

#define MAIN_VIEW_INDEX 1
#define MAIN_VIEW_PRIORITY 0
#define MAIN_VIEW_MINIMUM_WIDTH 200.0




@interface SBServerLibraryController ()
- (void)subsonicCoversUpdatedNotification:(NSNotification *)notification;
- (void)subsonicTracksUpdatedNotification:(NSNotification *)notification;
@end





@implementation SBServerLibraryController



+ (NSString *)nibName {
    return @"ServerLibrary";
}


- (NSString*)title {
    return [NSString stringWithFormat: @"Artists on %@", self.server.resourceName];
}


@synthesize databaseController;
@synthesize artistSortDescriptor;
@synthesize trackSortDescriptor;

@dynamic artistCellSelectedAttributes;
@dynamic artistCellUnselectedAttributes;



- (id)initWithManagedObjectContext:(NSManagedObjectContext *)context {
    self = [super initWithManagedObjectContext:context];
    if (self) {
        NSSortDescriptor *artistDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"itemName" ascending:YES];
        artistSortDescriptor = [NSArray arrayWithObject:artistDescriptor];
        
        NSSortDescriptor *trackNumberDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"trackNumber" ascending:YES];
        NSSortDescriptor *discNumberDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"discNumber" ascending:YES];
        trackSortDescriptor = @[discNumberDescriptor, trackNumberDescriptor];
        
        splitViewDelegate = [[SBPrioritySplitViewDelegate alloc] init];
        
    }
    return self;
}

- (void)dealloc
{
    // remove subsonic observers
    [[NSNotificationCenter defaultCenter] removeObserver:self name:SBSubsonicCoversUpdatedNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:SBSubsonicTracksUpdatedNotification object:nil];
    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:@"coverSize"];
    
    
}

- (void)loadView {
    [super loadView];
        
    //[artistSplitView setPosition:LEFT_VIEW_MINIMUM_WIDTH ofDividerAtIndex:0];
    
    [splitViewDelegate setPriority:LEFT_VIEW_PRIORITY forViewAtIndex:LEFT_VIEW_INDEX];
	[splitViewDelegate setMinimumLength:LEFT_VIEW_MINIMUM_WIDTH forViewAtIndex:LEFT_VIEW_INDEX];
    
	[splitViewDelegate setPriority:MAIN_VIEW_PRIORITY forViewAtIndex:MAIN_VIEW_INDEX];
	[splitViewDelegate setMinimumLength:MAIN_VIEW_MINIMUM_WIDTH forViewAtIndex:MAIN_VIEW_INDEX];
    
    [artistSplitView setDelegate:splitViewDelegate];
    
    [tracksTableView registerForDraggedTypes:[NSArray arrayWithObject:SBLibraryTableViewDataType]];
    [tracksTableView setTarget:self];
    [tracksTableView setDoubleAction:@selector(trackDoubleClick:)];

    [albumsBrowserView setZoomValue:[[NSUserDefaults standardUserDefaults] floatForKey:@"coverSize"]];
    
    // observer browser zoom value
    [[NSUserDefaults standardUserDefaults] addObserver:self
                                            forKeyPath:@"coverSize" 
                                               options:NSKeyValueObservingOptionNew
                                               context:nil];
    
    // observe album covers
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(subsonicCoversUpdatedNotification:) 
                                                 name:SBSubsonicCoversUpdatedNotification
                                               object:nil];
    
    // observe tracks
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(subsonicTracksUpdatedNotification:) 
                                                 name:SBSubsonicTracksUpdatedNotification
                                               object:nil];
}


- (void)observeValueForKeyPath:(NSString *)keyPath 
                      ofObject:(id)object 
                        change:(NSDictionary *)change 
                       context:(void *)context {
    
    if(object == [NSUserDefaults standardUserDefaults] && [keyPath isEqualToString:@"coverSize"]) {
        [albumsBrowserView setZoomValue:[[NSUserDefaults standardUserDefaults] floatForKey:@"coverSize"]];
        [albumsBrowserView setNeedsDisplay:YES];
    }
}

- (NSDictionary *)artistCellSelectedAttributes {
    if(artistCellSelectedAttributes == nil) {
        artistCellSelectedAttributes = [NSMutableDictionary dictionary];
        
        return artistCellSelectedAttributes;
    }
    return artistCellSelectedAttributes;
}

- (NSDictionary *)artistCellUnselectedAttributes {
    if(artistCellUnselectedAttributes == nil) {
        artistCellUnselectedAttributes = [NSMutableDictionary dictionary];
        
        return artistCellUnselectedAttributes;
    }
    return artistCellUnselectedAttributes;
}





#pragma mark - 
#pragma mark Notification

- (void)subsonicCoversUpdatedNotification:(NSNotification *)notification {
    [albumsBrowserView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
}

- (void)subsonicTracksUpdatedNotification:(NSNotification *)notification {
    [tracksTableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
}


#pragma mark - 
#pragma mark IBActions

- (IBAction)addArtistToTracklist:(id)sender {
    NSInteger selectedRow = [artistsTableView selectedRow];
    
    if(selectedRow != -1) {
        SBArtist *artist = [[artistsController arrangedObjects] objectAtIndex:selectedRow];
        NSMutableArray *tracks = [NSMutableArray array];
        
        for(SBAlbum *album in artist.albums) {
            [tracks addObjectsFromArray:[album.tracks sortedArrayUsingDescriptors:trackSortDescriptor]];
        }
        
        [[SBPlayer sharedInstance] addTrackArray:tracks replace:NO];
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
    } else if (responder == artistsTableView) {
        [self addArtistToTracklist: self];
    }
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


- (IBAction)filterArtist:(id)sender {
    
    NSPredicate *predicate = nil;
    NSString *searchString = nil;
    
    searchString = [sender stringValue];
    
    if(searchString != nil && [searchString length] > 0) {
        predicate = [NSPredicate predicateWithFormat:@"(itemName CONTAINS[cd] %@) && (server == %@)", searchString, self.server];
        [artistsController setFilterPredicate:predicate];
    } else {
        predicate = [NSPredicate predicateWithFormat:@"(server == %@)", self.server];
        [artistsController setFilterPredicate:predicate];
    }
}

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


- (IBAction)showSelectedInFinder:(in)sender {
    NSInteger selectedRow = [tracksTableView selectedRow];
    
    if(selectedRow == -1) {
        return;
    }
    
    [self showTracksInFinder: tracksController.arrangedObjects selectedIndices: tracksTableView.selectedRowIndexes];
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
            
			[databaseController showDownloadView];
			
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


- (void)showTrackInLibrary:(SBTrack*)track {
    [artistsController setSelectedObjects: @[track.album.artist]];
    [albumsController setSelectedObjects: @[track.album]];
    [tracksController setSelectedObjects: @[track]];
}





#pragma mark - 
#pragma mark Observers






#pragma mark -
#pragma mark NoodleTableView Delegate (Artist Indexes)

- (BOOL)tableView:(NSTableView *)tableView isGroupRow:(NSInteger)row {
    BOOL ret = NO;
    
    if(tableView == artistsTableView) {
        if(row > -1) {
            SBGroup *group = [[artistsController arrangedObjects] objectAtIndex:row];
            if(group && [group isKindOfClass:[SBGroup class]])
                ret = YES;
        }
    }
	return ret;
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row {
    BOOL ret = YES;
    
    if(tableView == artistsTableView) {
        if(row > -1) {
            SBGroup *group = [[artistsController arrangedObjects] objectAtIndex:row];
            if(group && [group isKindOfClass:[SBGroup class]])
                ret = NO;
        }
    }
	return ret;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    
    if(tableView == artistsTableView) {
        if(row != -1) {
            SBIndex *index = [[artistsController arrangedObjects] objectAtIndex:row];
            if(index && [index isKindOfClass:[SBArtist class]])
                return 22.0f;
            else if(index && [index isKindOfClass:[SBGroup class]])
                return 20.0f;
        }
    }
    return 17.0f;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    
    if([notification object] == artistsTableView) {
        NSInteger selectedRow = [[notification object] selectedRow];
        if(selectedRow != -1) {
            SBArtist *selectedArtist = [[artistsController arrangedObjects] objectAtIndex:selectedRow];
            if(selectedArtist && [selectedArtist isKindOfClass:[SBArtist class]]) {
                [self.server getAlbumsForArtist:selectedArtist];
                [albumsBrowserView setSelectionIndexes:nil byExtendingSelection:NO];
            }
        }
    }
}

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if(tableView == artistsTableView) {
        if(row > -1) {
            SBIndex *index = [[artistsController arrangedObjects] objectAtIndex:row];
            if(index && [index isKindOfClass:[SBArtist class]]) {

                NSDictionary *attr = (row == [tableView selectedRow]) ? self.artistCellSelectedAttributes : self.artistCellUnselectedAttributes;
                NSAttributedString *newString = [[NSAttributedString alloc] initWithString:index.itemName attributes:attr];
                
                [cell setAttributedStringValue:newString];
            }
        }
    }
}



#pragma mark -
#pragma mark NSTableView (Menu)

- (NSMenu *)tableView:(id)tableView menuForEvent:(NSEvent *)event {
    if(tableView == tracksTableView) {
        NSMenu*  menu = nil;
        NSMenuItem *item = nil;
        
        menu = [[NSMenu alloc] initWithTitle:@"trackMenu"];
        [menu setAutoenablesItems:NO];
        
        item = [[NSMenuItem alloc] initWithTitle:@"Play Track" action:@selector(trackDoubleClick:) keyEquivalent:@""];
        [item setTarget:self];
        [menu addItem:item];
                
        item = [[NSMenuItem alloc] initWithTitle:@"Add to Tracklist" action:@selector(addTrackToTracklist:) keyEquivalent:@""];
        [item setTarget:self];
        [menu addItem:item];
        
        item = [[NSMenuItem alloc] initWithTitle:@"New Server Playlist with Selected Track(s)" action:@selector(createNewPlaylistWithSelectedTracks:) keyEquivalent:@""];
        [item setTarget:self];
        [menu addItem:item];
        
        [menu addItem:[NSMenuItem separatorItem]];
        
        item = [[NSMenuItem alloc] initWithTitle:@"Download Track" action:@selector(downloadTrack:) keyEquivalent:@""];
        [item setTarget:self];
        [menu addItem:item];
        
        return menu;
        
    } else if(tableView == artistsTableView) {
        NSMenu*  menu = nil;
        NSMenuItem *item = nil;
        
        menu = [[NSMenu alloc] initWithTitle:@"artistMenu"];
        [menu setAutoenablesItems:NO];
        
        item = [[NSMenuItem alloc] initWithTitle:@"Add to Tracklist" action:@selector(addArtistToTracklist:) keyEquivalent:@""];
        [item setTarget:self];
        [menu addItem:item];
        
        return menu;
        
    }
    return nil;
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
#pragma mark NSTableView (enter & delete)

- (void)tableViewEnterKeyPressedNotification:(NSNotification *)notification {
    [self trackDoubleClick:self];
}




#pragma mark -
#pragma mark IKImageBrowserViewDelegate

- (void)imageBrowserSelectionDidChange:(IKImageBrowserView *)aBrowser {
    
    // get tracks
    NSInteger selectedRow = [[aBrowser selectionIndexes] firstIndex];
    if(selectedRow != -1 && selectedRow < [[albumsController arrangedObjects] count]) {
        
        [tracksController setContent:nil];
        
        SBAlbum *album = [[albumsController arrangedObjects] objectAtIndex:selectedRow];
        if(album) {
            
            [self.server getTracksForAlbumID:album.id];
            
            if([album.tracks count] == 0) {                
                // wait for new tracks
//                [album addObserver:self
//                        forKeyPath:@"tracks"
//                           options:(NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionPrior | NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld)
//                           context:NULL];

            } else {
                [tracksController setContent:album.tracks];
            }
        } else {
            [tracksController setContent:nil];
        }
    } else {
        [tracksController setContent:nil];
    }
}

- (void)imageBrowser:(IKImageBrowserView *)aBrowser cellWasRightClickedAtIndex:(NSUInteger)index withEvent:(NSEvent *)event {
    //contextual menu for item index
    NSMenu*  menu = nil;
    NSMenuItem *item = nil;
    
    menu = [[NSMenu alloc] initWithTitle:@"albumsMenu"];
    [menu setAutoenablesItems:NO];
    
    item = [[NSMenuItem alloc] initWithTitle:@"Play Album" action:@selector(albumDoubleClick:) keyEquivalent:@""];
    [item setTarget:self];
    [menu addItem:item];
    
    item = [[NSMenuItem alloc] initWithTitle:@"Add to Tracklist" action:@selector(addAlbumToTracklist:) keyEquivalent:@""];
    [item setTarget:self];
    [menu addItem:item];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    item = [[NSMenuItem alloc] initWithTitle:@"Download Album" action:@selector(downloadAlbum:) keyEquivalent:@""];
    [item setTarget:self];
    [menu addItem:item];
    
    [NSMenu popUpContextMenu:menu withEvent:event forView:aBrowser];
    
}

- (void)imageBrowser:(IKImageBrowserView *)aBrowser cellWasDoubleClickedAtIndex:(NSUInteger)index {
    [self albumDoubleClick:nil];
}



#pragma mark -
#pragma mark UI Validator

- (BOOL)validateUserInterfaceItem: (id<NSValidatedUserInterfaceItem>) item {
    SEL action = [item action];
    
    NSInteger artistsSelected = artistsTableView.selectedRowIndexes.count;
    NSInteger albumSelected = albumsBrowserView.selectionIndexes.count;
    NSInteger tracksSelected = tracksTableView.selectedRowIndexes.count;
    
    NSResponder *responder = self.databaseController.window.firstResponder;
    BOOL tracksActive = responder == tracksTableView;
    BOOL albumsActive = responder == albumsBrowserView;
    BOOL artistsActive = responder == artistsTableView;
    
    SBSelectedRowStatus selectedTrackRowStatus = 0;
    if (tracksActive) {
        selectedTrackRowStatus = [self selectedRowStatus: tracksController.arrangedObjects selectedIndices: tracksTableView.selectedRowIndexes];
    }
    
    if (action == @selector(addSelectedToTracklist:)
        || action == @selector(playSelected:)) {
        return (albumSelected > 0 || tracksSelected > 0) && (albumsActive || tracksActive);
    }
    
    if (action == @selector(createNewPlaylistWithSelectedTracks:)) {
        return tracksSelected > 0 && tracksActive;
    }
    
    if (action == @selector(showSelectedInFinder:)) {
        return selectedTrackRowStatus & SBSelectedRowShowableInFinder;
    }
    
    if (action == @selector(downloadSelected:)) {
        return selectedTrackRowStatus & SBSelectedRowDownloadable;
    }

    return YES;
}


@end
