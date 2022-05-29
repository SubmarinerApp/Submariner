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
#import "SBPlayer.h"
#import "SBMusicItem.h"
#import "SBTrack.h"
#import "SBAlbum.h"
#import "SBArtist.h"




@interface SBTracklistController ()
- (void)playerPlaylistUpdatedNotification:(NSNotification *)notification;
@end



@implementation SBTracklistController

+ (NSString *)nibName {
    return @"Tracklist";
}


- (NSString*)title {
    return @"Tracklist for %s";
}


@synthesize databaseController;



- (void)dealloc {
    // remove player observer
    [[NSNotificationCenter defaultCenter] removeObserver:self name:SBPlayerPlaylistUpdatedNotification object:nil];
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
                                                 name:SBPlayerPlaylistUpdatedNotification
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

- (IBAction)playPause:(id)sender {
    if([[SBPlayer sharedInstance] isPlaying] || [[SBPlayer sharedInstance] isPaused]) {
        // player is already running
        [[SBPlayer sharedInstance] playPause];
    }
}

- (IBAction)nextTrack:(id)sender {
    [[SBPlayer sharedInstance] next];
}

- (IBAction)previousTrack:(id)sender {
    [[SBPlayer sharedInstance] previous];
}

- (IBAction)shuffle:(id)sender {
    if([sender state] == NSControlStateValueOn) {
        [[SBPlayer sharedInstance] setIsShuffle:YES];
        
    } else if([sender state] == NSControlStateValueOff) {
        [[SBPlayer sharedInstance] setIsShuffle:YES];
    }
}

- (IBAction)repeat:(id)sender {
    
    if([sender state] == NSControlStateValueOn) {
        [[SBPlayer sharedInstance] setRepeatMode:SBPlayerRepeatAll];
        [sender setAlternateImage:[NSImage imageNamed:@"repeat_on"]];
    } 
    if([sender state] == NSControlStateValueOff) {
        [[SBPlayer sharedInstance] setRepeatMode:SBPlayerRepeatNo];
    } 
    if([sender state] == NSControlStateValueMixed) {
        [[SBPlayer sharedInstance] setRepeatMode:SBPlayerRepeatOne];
        [sender setAlternateImage:[NSImage imageNamed:@"repeat_one_on"]];
    }
}

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
        SBTrack *track = [[[SBPlayer sharedInstance] playlist] objectAtIndex:selectedRow];
        if(track) {
            [[SBPlayer sharedInstance] removeTrack:track];
            [playlistTableView reloadData];
        }
    }
}


- (IBAction)cleanTracklist:(id)sender {
    [[SBPlayer sharedInstance] clear];
    [playlistTableView reloadData];
}


- (IBAction)closeTracklist:(id)sender {
    [databaseController toggleTrackList:sender];
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
            value = [NSImage imageNamed:@"playing_white"];
        }
    }
    if([[tableColumn identifier] isEqualToString:@"title"])
        value = [[[[SBPlayer sharedInstance] playlist] objectAtIndex:row] itemName];
    
    if([[tableColumn identifier] isEqualToString:@"artist"])
        value = [[[[SBPlayer sharedInstance] playlist] objectAtIndex:row] artistString];
    
    if([[tableColumn identifier] isEqualToString:@"duration"])
        value = [[[[SBPlayer sharedInstance] playlist] objectAtIndex:row] durationString];
    
    if([[tableColumn identifier] isEqualToString:@"online"]) {
        SBTrack *track = (SBTrack *)[[[SBPlayer sharedInstance] playlist] objectAtIndex:row];
        if(![[track isLocal] boolValue]) {
            if(track.localTrack != nil) {
                value = [NSImage imageNamed:@"cached_white"];
            } else {
                value = [NSImage imageNamed:@"online_white"];
            }
        }
    }
    return value;
}




#pragma mark -
#pragma mark NSTableView Delegate

- (void)tableViewEnterKeyPressedNotification:(NSNotification *)notification {
    [self trackDoubleClick:self];
}

- (void)tableViewDeleteKeyPressedNotification:(NSNotification *)notification {
    [self removeTrack:self];
}

- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard*)pboard
{
    // internal drop track
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];
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
    
    // internal drop track
    if ([[pboard types] containsObject:SBTracklistTableViewDataType] ) {
        NSData* rowData = [pboard dataForType:SBTracklistTableViewDataType];
        NSIndexSet* rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData:rowData];    
        NSMutableArray *tracks = [NSMutableArray array];
        NSArray *reversedArray  = nil;
        
        // get temp rows objects and remove them from the playlist
        [rowIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
            [tracks addObject:[[[SBPlayer sharedInstance] playlist] objectAtIndex:idx]];
            [[[SBPlayer sharedInstance] playlist] removeObject:[[[SBPlayer sharedInstance] playlist] objectAtIndex:idx]];
            [playlistTableView reloadData];
        }];
        
        // reverse track array
        reversedArray = [[tracks reverseObjectEnumerator] allObjects];
        
        // add reversed track at index
        for(SBTrack *track in reversedArray) {
            //NSLog(@"row : %ld", row);
            if(row > [[[SBPlayer sharedInstance] playlist] count])
                row--;
            
            [[[SBPlayer sharedInstance] playlist] insertObject:track atIndex:row];
        }
        [playlistTableView reloadData];
        
    } else if([[pboard types] containsObject:SBLibraryTableViewDataType]) {
        
        NSData *data = [[info draggingPasteboard] dataForType:SBLibraryTableViewDataType];
        NSArray *tracksURIs = [NSKeyedUnarchiver unarchiveObjectWithData:data]; 
        
        // also add new track IDs to the array
        [tracksURIs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            SBTrack *track = (SBTrack *)[self.managedObjectContext objectWithID:[[self.managedObjectContext persistentStoreCoordinator] managedObjectIDForURIRepresentation:obj]]; 
            
            [[[SBPlayer sharedInstance] playlist] addObject:track];
        }];
        
        
        [playlistTableView reloadData];
    }
    
    return YES;
}

@end
