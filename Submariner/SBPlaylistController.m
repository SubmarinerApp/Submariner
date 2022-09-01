//
//  SBPlaylistController.m
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

#import "SBPlaylistController.h"
#import "SBDatabaseController.h"
#import "SBServer.h"
#import "SBTrack.h"
#import "SBPlayer.h"
#import "SBPlaylist.h"


@implementation SBPlaylistController


@synthesize playlist;
@synthesize playlistSortDescriptors;



#pragma mark - 
#pragma mark LifeCycle

+ (NSString *)nibName {
    return @"Playlist";
}


- (NSString*)title {
    // XXX: Title here
    return @"Playlist for %s";
}


- (id)initWithManagedObjectContext:(NSManagedObjectContext *)context {
    self = [super initWithManagedObjectContext:context];
    if (self) {
        NSSortDescriptor *desc = [NSSortDescriptor sortDescriptorWithKey:@"playlistIndex" ascending:YES];
        playlistSortDescriptors = [NSArray arrayWithObject:desc];
    }
    return self;
}




- (void)loadView {
    [super loadView];
    
    [tracksTableView setTarget:self];
    [tracksTableView setDoubleAction:@selector(trackDoubleClick:)];
    [tracksTableView registerForDraggedTypes:[NSArray arrayWithObject:SBLibraryTableViewDataType]];
}




#pragma mark - 
#pragma mark Utils

- (void)clearPlaylist {
    //[tracksController setContent:nil];
}





#pragma mark - 
#pragma mark IBActions

- (IBAction)trackDoubleClick:(id)sender {
    NSInteger selectedRow = [tracksTableView selectedRow];
    if(selectedRow != -1) {
        SBTrack *clickedTrack = [[tracksController arrangedObjects] objectAtIndex:selectedRow];
        if(clickedTrack) {
            
            // stop current playing tracks
            [[SBPlayer sharedInstance] stop];
            
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

- (IBAction)removeTrack:(id)sender {
    NSInteger selectedRow = [tracksTableView selectedRow];
    
    if(selectedRow != -1) {
        SBTrack *selectedTrack = [[tracksController arrangedObjects] objectAtIndex:selectedRow];
        if(selectedTrack != nil) {
            NSAlert *alert = [[NSAlert alloc] init];
            [alert addButtonWithTitle:@"OK"];
            [alert addButtonWithTitle:@"Cancel"];
            [alert setMessageText:@"Remove the selected track ?"];
            [alert setInformativeText:@"The selected track will be removed from this playlist."];
            [alert setAlertStyle:NSAlertStyleWarning];
            
            [alert beginSheetModalForWindow: [[self view] window] completionHandler:^(NSModalResponse returnCode) {
                [self removeTrackAlertDidEnd: alert returnCode: returnCode contextInfo: nil];
            }];
        }
    }
}


- (void)removeTrackAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSAlertFirstButtonReturn) { 
        NSInteger selectedRow = [tracksTableView selectedRow];
        
        if(selectedRow != -1) {
            SBTrack *selectedTrack = [[tracksController arrangedObjects] objectAtIndex:selectedRow];
            if(selectedTrack != nil) {
                [playlist removeTracksObject:selectedTrack];
            }
        }
    }
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

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)op
{
    
    if(row == -1)
        return NSDragOperationNone;
    
    if(op == NSTableViewDropAbove) {
        // internal drop track
        if ([[[info draggingPasteboard] types] containsObject:SBLibraryTableViewDataType] ) {
            return NSDragOperationMove;
        }
    }
    
    return NSDragOperationNone;
}


- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info
              row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation
{
    NSSet *allowedClasses = [NSSet setWithObjects: NSIndexSet.class, NSArray.class, NSURL.class, nil];
    NSError *error = nil;
    NSPasteboard* pboard = [info draggingPasteboard];
    
    // internal drop track
    if ([[pboard types] containsObject:SBLibraryTableViewDataType] ) {
        NSData* rowData = [pboard dataForType:SBLibraryTableViewDataType];
        NSArray *trackURIs = [NSKeyedUnarchiver unarchivedObjectOfClasses: allowedClasses fromData: rowData error: &error];
        if (error != nil) {
            NSLog(@"Error unserializing array %@", error);
            return NO;
        }
        NSMutableArray *tracks = [NSMutableArray array];
        NSArray *reversedArray  = nil;
        NSInteger sourceRow = 0;    
        NSInteger destinationRow = 0;
        
        // compute selected track
        [trackURIs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            SBTrack *track = (SBTrack *)[self.managedObjectContext objectWithID:[self.managedObjectContext.persistentStoreCoordinator managedObjectIDForURIRepresentation:obj]];
            [tracks addObject:track];
        }];
        
        // update playlist indexes 
        if([[[tracks objectAtIndex:0] playlistIndex] integerValue] < row) {
            sourceRow = [[[tracks objectAtIndex:0] playlistIndex] integerValue];
            destinationRow = row;
            
            // increment interval rows
            NSArray *trackInInterval = [[tracksController arrangedObjects] subarrayWithRange:NSMakeRange(sourceRow, destinationRow-sourceRow)];
            for(SBTrack *track in trackInInterval) {
                NSInteger playlistIndex = [[track playlistIndex] integerValue];
                playlistIndex--;
                
                [track setPlaylistIndex:[NSNumber numberWithInteger:playlistIndex]];
            }
        } else {
            sourceRow = row;
            destinationRow = [[[tracks objectAtIndex:0] playlistIndex] integerValue];
            
            // increment interval rows
            NSArray *trackInInterval = [[tracksController arrangedObjects] subarrayWithRange:NSMakeRange(sourceRow, destinationRow-sourceRow)];
            for(SBTrack *track in trackInInterval) {
                NSInteger playlistIndex = [[track playlistIndex] integerValue];
                playlistIndex++;
                
                [track setPlaylistIndex:[NSNumber numberWithInteger:playlistIndex]];
            }
        }
    
        
        // reverse track array
        reversedArray = [[tracks reverseObjectEnumerator] allObjects];
        
        // add reversed track at index
        for(SBTrack *track in reversedArray) {
            if(row > [[tracksController arrangedObjects] count])
                row--;
            
            [track setPlaylistIndex:[NSNumber numberWithInteger:row]];
        }
        
        
        [tracksController rearrangeObjects];
        [tracksTableView reloadData];
    }
    
    return YES;
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
                    
                    [clickedTrack.server setRating:rating forID:trackID];
                }
            }
        }
    }
}






#pragma mark - 
#pragma mark NSTableView delegate

- (void)tableViewEnterKeyPressedNotification:(NSNotification *)notification {
    [self trackDoubleClick:self];
}

- (void)tableViewDeleteKeyPressedNotification:(NSNotification *)notification {
    [self removeTrack:self];
}


@end
