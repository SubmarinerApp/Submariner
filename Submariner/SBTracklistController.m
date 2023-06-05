//
//  SBTracklistController.m
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

#import "SBTracklistController.h"
#import "SBDatabaseController.h"

#import "Submariner-Swift.h"




@interface SBTracklistController ()
- (void)playerPlaylistUpdatedNotification:(NSNotification *)notification;
@end



@implementation SBTracklistController

+ (NSString *)nibName {
    return @"Tracklist";
}


- (NSString*)title {
    return @"Tracklist";
}


@synthesize databaseController;



- (void)dealloc {
    // remove player observer
    [[NSNotificationCenter defaultCenter] removeObserver:self name: @"SBPlayerPlaylistUpdatedNotification" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self forKeyPath:@"playlist"];
}



- (void)loadView {
    [super loadView];
    
    [playlistTableView setTarget:self];
    [playlistTableView setDoubleAction:@selector(trackDoubleClick:)];
    [playlistTableView registerForDraggedTypes:[NSArray arrayWithObjects:SBTracklistTableViewDataType, SBLibraryTableViewDataType, nil]];
    
    // observer playlist change
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerPlaylistUpdatedNotification:)
                                                 name:@"SBPlayerPlaylistUpdatedNotification"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                           forKeyPath:@"playlist"  
                                              options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld) 
                                              context:(__bridge void*)[SBPlayer sharedInstance]];
}





#pragma mark -
#pragma mark Observers

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if([keyPath isEqualToString:@"playlist"]) {
        [playlistTableView reloadData];
    }
}





#pragma mark -
#pragma mark IBActions

- (IBAction)trackDoubleClick:(id)sender {
    NSInteger selectedRow = [playlistTableView selectedRow];
    if(selectedRow != -1) {
        SBTrack *clickedTrack = [[[SBPlayer sharedInstance] playlist] objectAtIndex:selectedRow];
        if(clickedTrack) {
            
            // stop current playing tracks
            [[SBPlayer sharedInstance] stop];
            
            // play track
            [[SBPlayer sharedInstance] playTrack:clickedTrack];
        }
    }
}




- (IBAction)removeTrack:(id)sender {
    NSInteger selectedRow = [playlistTableView selectedRow];
    
    if(selectedRow != -1) {
        [[SBPlayer sharedInstance] removeTrackIndexSet: [playlistTableView selectedRowIndexes]];
        [playlistTableView reloadData];
    }
}


- (IBAction)cleanTracklist:(id)sender {
    [[SBPlayer sharedInstance] clear];
    [playlistTableView reloadData];
}


- (IBAction)closeTracklist:(id)sender {
    [databaseController toggleTrackList:sender];
}


- (IBAction)delete: (id)sender {
    [self removeTrack: sender];
}


- (IBAction)showSelectedInFinder:(id)sender {
    NSInteger selectedRow = [playlistTableView selectedRow];
    
    if(selectedRow == -1) {
        return;
    }
    
    [self showTracksInFinder: [[SBPlayer sharedInstance] playlist] selectedIndices: playlistTableView.selectedRowIndexes];
}


- (IBAction)showSelectedInLibrary:(id)sender {
    NSInteger selectedRow = [playlistTableView selectedRow];
    
    if(selectedRow == -1) {
        return;
    }
    
    // only makes sense to have a single track, imho
    NSUInteger index = playlistTableView.selectedRowIndexes.firstIndex;
    SBTrack *track = (SBTrack*)[[[SBPlayer sharedInstance] playlist] objectAtIndex: index];
    [[self databaseController] goToTrack: track];
}


- (IBAction)downloadSelected:(id)sender {
    NSInteger selectedRow = [playlistTableView selectedRow];
    
    if(selectedRow != -1) {
        [self downloadTracks: [[SBPlayer sharedInstance] playlist] selectedIndices: playlistTableView.selectedRowIndexes databaseController: databaseController];
    }
}


- (IBAction)createNewLocalPlaylistWithSelectedTracks:(id)sender {
    NSInteger selectedRow = [playlistTableView selectedRow];
    
    if(selectedRow == -1) {
        return;
    }
    
    [self createLocalPlaylistWithSelected: [[SBPlayer sharedInstance] playlist] selectedIndices: playlistTableView.selectedRowIndexes databaseController: self.databaseController];
}


#pragma mark -
#pragma mark Player Notifications

- (void)playerPlaylistUpdatedNotification:(NSNotification *)notification {

    [playlistTableView reloadData];
}





#pragma mark -
#pragma mark NSTableView DataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [[[SBPlayer sharedInstance] playlist] count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    id value = nil;
    
    if([[tableColumn identifier] isEqualToString:@"isPlaying"]) {
        SBTrack *track = (SBTrack *)[[[SBPlayer sharedInstance] playlist] objectAtIndex:row];
        if([[track isPlaying] boolValue]) {
            value = [NSImage imageWithSystemSymbolName: @"speaker.fill" accessibilityDescription: @"Playing"];
        }
    }
    if([[tableColumn identifier] isEqualToString:@"title"])
        value = [[[[SBPlayer sharedInstance] playlist] objectAtIndex:row] itemName];
    
    if([[tableColumn identifier] isEqualToString:@"artist"]) {
        SBTrack *track = [[[SBPlayer sharedInstance] playlist] objectAtIndex:row];
        if (track.artistName == nil || [track.artistName isEqualToString: @""]) {
            value = track.album.artist.itemName;
        } else {
            value = track.artistName;
        }
    }
    
    if([[tableColumn identifier] isEqualToString:@"duration"])
        value = [[[[SBPlayer sharedInstance] playlist] objectAtIndex:row] durationString];
    
    if([[tableColumn identifier] isEqualToString:@"online"]) {
        SBTrack *track = (SBTrack *)[[[SBPlayer sharedInstance] playlist] objectAtIndex:row];
        if (track.localTrack != nil || track.isLocal.boolValue == YES) {
            value = [NSImage imageWithSystemSymbolName: @"bolt.horizontal.fill" accessibilityDescription: @"Cached"];
        } else {
            value = [NSImage imageWithSystemSymbolName: @"bolt.horizontal" accessibilityDescription: @"Online"];
        }
    }
    return value;
}




#pragma mark -
#pragma mark NSTableView Delegate

- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard*)pboard
{
    // internal drop track
    NSError *error = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes requiringSecureCoding: YES error: &error];
    if (error != nil) {
        NSLog(@"Error archiving track URIs: %@", error);
        return NO;
    }
    [pboard declareTypes:[NSArray arrayWithObject:SBTracklistTableViewDataType] owner:self];
    [pboard setData:data forType:SBTracklistTableViewDataType];
    
    return YES;
}


- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)op
{
    
    if(row == -1)
        return NSDragOperationNone;
    
    if(op == NSTableViewDropAbove) {
        // internal drop track
        if ([[[info draggingPasteboard] types] containsObject:SBTracklistTableViewDataType] || [[[info draggingPasteboard] types] containsObject:SBLibraryTableViewDataType] ) {
            return NSDragOperationMove;
        }
    }
    
    return NSDragOperationNone;
}


- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info
              row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation
{
    NSPasteboard* pboard = [info draggingPasteboard];
    NSSet *allowedClasses = [NSSet setWithObjects: NSIndexSet.class, NSArray.class, NSURL.class, nil];
    NSError *error = nil;
    // internal drop track
    if ([[pboard types] containsObject:SBTracklistTableViewDataType] ) {
        NSData* rowData = [pboard dataForType:SBTracklistTableViewDataType];
        NSIndexSet* rowIndexes = [NSKeyedUnarchiver unarchivedObjectOfClasses: allowedClasses fromData: rowData error: &error];
        if (error != nil) {
            NSLog(@"Error unserializing index set %@", error);
            return NO;
        }
        NSMutableArray *tracks = [NSMutableArray array];
        NSArray *reversedArray  = nil;
        
        // get temp rows objects and remove them from the playlist
        [rowIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
            [tracks addObject:[[[SBPlayer sharedInstance] playlist] objectAtIndex:idx]];
            [[SBPlayer sharedInstance] removeTrackAtIndex: idx];
            [playlistTableView reloadData];
        }];
        
        // reverse track array
        reversedArray = [[tracks reverseObjectEnumerator] allObjects];
        
        // add reversed track at index
        for(SBTrack *track in reversedArray) {
            //NSLog(@"row : %ld", row);
            if(row > [[[SBPlayer sharedInstance] playlist] count])
                row--;
            
            [[SBPlayer sharedInstance] addTrack: track atIndex: row];
        }
        [playlistTableView reloadData];
        
    } else if([[pboard types] containsObject:SBLibraryTableViewDataType]) {
        
        NSData *data = [[info draggingPasteboard] dataForType:SBLibraryTableViewDataType];
        NSArray *tracksURIs = [NSKeyedUnarchiver unarchivedObjectOfClasses: allowedClasses fromData: data error: &error];
        if (error != nil) {
            NSLog(@"Error unserializing array %@", error);
            return NO;
        }
        
        // also add new track IDs to the array
        NSArray *reversedArray = [[tracksURIs reverseObjectEnumerator] allObjects];
        [reversedArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            SBTrack *track = (SBTrack *)[self.managedObjectContext objectWithID:[[self.managedObjectContext persistentStoreCoordinator] managedObjectIDForURIRepresentation:obj]]; 
            
            [[SBPlayer sharedInstance] addTrack: track atIndex:row];
        }];
        
        
        [playlistTableView reloadData];
    }
    
    return YES;
}

#pragma mark -
#pragma mark UI Validation


- (BOOL)validateUserInterfaceItem: (id<NSValidatedUserInterfaceItem>) item {
    SEL action = item.action;
    
    BOOL tracksSelected = playlistTableView.selectedRow != -1;
    NSUInteger tracksSelectedCount = playlistTableView.numberOfSelectedRows;
    
    SBSelectedRowStatus selectedTrackRowStatus = 0;
    selectedTrackRowStatus = [self selectedRowStatus: [[SBPlayer sharedInstance] playlist] selectedIndices: playlistTableView.selectedRowIndexes];
    
    if (action == @selector(delete:)
        || action == @selector(createNewLocalPlaylistWithSelectedTracks:)) {
        return tracksSelected;
    }
    
    if (action == @selector(showSelectedInFinder:)) {
        return selectedTrackRowStatus & SBSelectedRowShowableInFinder;
    }
    
    if (action == @selector(downloadSelected:)) {
        return selectedTrackRowStatus & SBSelectedRowDownloadable;
    }
    
    if (action == @selector(showSelectedInLibrary:)) {
        return tracksSelectedCount == 1;
    }
    
    return true;
}

@end
