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

#import "Submariner-Swift.h"


@implementation SBPlaylistController


@synthesize playlist;
@synthesize playlistSortDescriptors;
@synthesize databaseController;



#pragma mark - 
#pragma mark LifeCycle

+ (NSString *)nibName {
    return @"Playlist";
}


- (NSString*)title {
    return [NSString stringWithFormat: @"Playlist \"%@\"", self.playlist.resourceName];
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
    
    [tracksTableView registerForDraggedTypes: @[SBLibraryTableViewDataType, SBLibraryItemTableViewDataType]];
    
    [tracksController addObserver:self
                      forKeyPath:@"selectedObjects"
                      options:NSKeyValueObservingOptionNew
                      context:nil];
}


- (void)dealloc {
    [tracksController removeObserver:self forKeyPath:@"selectedObjects"];
}


- (void)viewDidAppear {
    [super viewDidAppear];
    [[NSNotificationCenter defaultCenter] postNotificationName: @"SBTrackSelectionChanged"
                                                        object: tracksController.selectedObjects];
}


- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if (object == tracksController && [keyPath isEqualToString:@"selectedObjects"] && self.view.window != nil) {
        [[NSNotificationCenter defaultCenter] postNotificationName: @"SBTrackSelectionChanged"
                                                            object: tracksController.selectedObjects];
    }
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
        [[SBPlayer sharedInstance] playTracks: [tracksController arrangedObjects] startingAt: selectedRow];
    }
}

- (IBAction)playSelected:(id)sender {
    [self trackDoubleClick:sender];
}

- (IBAction)addSelectedToTracklist:(id)sender {
    NSIndexSet *indexSet = [tracksTableView selectedRowIndexes];
    NSMutableArray *tracks = [NSMutableArray array];
    
    [indexSet enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        [tracks addObject:[[tracksController arrangedObjects] objectAtIndex:idx]];
    }];
    
    [[SBPlayer sharedInstance] addTrackArray:tracks replace:NO];
}

- (IBAction)removeTrack:(id)sender {
    NSInteger selectedRow = [tracksTableView selectedRow];
    
    if(selectedRow != -1) {
        SBTrack *selectedTrack = [[tracksController arrangedObjects] objectAtIndex:selectedRow];
        if(selectedTrack != nil) {
            NSAlert *alert = [[NSAlert alloc] init];
            [alert addButtonWithTitle:@"Remove"];
            [alert addButtonWithTitle:@"Cancel"];
            [alert setMessageText:@"Remove the selected tracks?"];
            [alert setInformativeText:@"The selected tracks will be removed from this playlist."];
            [alert setAlertStyle:NSAlertStyleWarning];
            
            [alert beginSheetModalForWindow: [[self view] window] completionHandler:^(NSModalResponse returnCode) {
                [self removeTrackAlertDidEnd: alert returnCode: returnCode contextInfo: nil];
            }];
        }
    }
}


- (IBAction)delete:(id)sender {
    [self removeTrack: sender];
}


- (void)removeTrackAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSAlertFirstButtonReturn) {
        NSIndexSet *selectedRows = [tracksTableView selectedRowIndexes];
        
        // delete each indiviually
        [selectedRows enumerateIndexesWithOptions: NSEnumerationReverse usingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
            SBTrack *selectedTrack = [[tracksController arrangedObjects] objectAtIndex: idx];
            if (selectedTrack != nil) {
                [playlist removeTracksObject:selectedTrack];
            }
        }];
        
        // delete all the rows at once in the server
        if (playlist.server) {
            NSArray *selectedRowsArray = [selectedRows toArray];
            [playlist.server updatePlaylistWithID: playlist.itemId
                                             name: nil
                                          comment: nil
                                        appending: nil
                                         removing: selectedRowsArray];
        }
    }
}


- (IBAction)showSelectedInFinder:(id)sender {
    NSInteger selectedRow = [tracksTableView selectedRow];
    
    if(selectedRow == -1) {
        return;
    }
    
    [self showTracksInFinder: tracksController.arrangedObjects selectedIndices: tracksTableView.selectedRowIndexes];
}


- (IBAction)downloadSelected:(id)sender {
    NSInteger selectedRow = [tracksTableView selectedRow];
    
    if(selectedRow != -1) {
        [self downloadTracks: tracksController.arrangedObjects selectedIndices: tracksTableView.selectedRowIndexes databaseController: nil];
    }
}


- (IBAction)createNewLocalPlaylistWithSelectedTracks:(id)sender {
    NSInteger selectedRow = [tracksTableView selectedRow];
    
    if(selectedRow == -1) {
        return;
    }
    
    [self createLocalPlaylistWithSelected: tracksController.arrangedObjects selectedIndices: tracksTableView.selectedRowIndexes databaseController: nil];
}


- (IBAction)showSelectedInLibrary:(id)sender {
    NSInteger selectedRow = [tracksTableView selectedRow];
    
    if(selectedRow == -1) {
        return;
    }
    
    // only makes sense to have a single track, imho
    NSUInteger index = tracksTableView.selectedRowIndexes.firstIndex;
    SBTrack *track = (SBTrack*)[tracksController.arrangedObjects objectAtIndex: index];
    [[self databaseController] goToTrack: track];
}




#pragma mark -
#pragma mark NSTableView (Drag & Drop)

- (id<NSPasteboardWriting>)tableView:(NSTableView *)tableView pasteboardWriterForRow:(NSInteger)row {
    if (tableView == tracksTableView) {
        SBTrack *track = tracksController.arrangedObjects[row];
        return [[SBLibraryItemPasteboardWriter alloc] initWithItem: track index: row];
    }
    return nil;
}

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)op
{
    if (row == -1)
        return NSDragOperationNone;
    
    if (op == NSTableViewDropAbove) {
        // internal drop track
        if ([info.draggingPasteboard libraryItems] != nil) {
            return NSDragOperationMove;
        }
    }
    
    return NSDragOperationNone;
}


- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info
              row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation
{
    NSArray<SBTrack*> *tracks = [info.draggingPasteboard libraryItemsWithManagedObjectContext: self.managedObjectContext];
    
    // internal drop track
    if (tracks != nil) {
        NSInteger sourceRow = 0;
        NSInteger destinationRow = 0;
        
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
        NSArray<SBTrack*> *reversedArray = [[tracks reverseObjectEnumerator] allObjects];
        
        // add reversed track at index
        for(SBTrack *track in reversedArray) {
            if(row > [[tracksController arrangedObjects] count])
                row--;
            
            [track setPlaylistIndex:[NSNumber numberWithInteger:row]];
        }
        
        
        [tracksController rearrangeObjects];
        [tracksTableView reloadData];
        
        // submit changes to server, this uses createPlaylist behind the scenes since we can reorder with it
        if (playlist.server) {
            [playlist.server updatePlaylistWithID: playlist.itemId tracks: tracksController.arrangedObjects];
        }
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
                    NSString *trackID = [clickedTrack itemId];
                    
                    [clickedTrack.server setRating:rating forID:trackID];
                }
            }
        }
    }
}



#pragma mark -
#pragma mark UI Validator

- (BOOL)validateUserInterfaceItem: (id<NSValidatedUserInterfaceItem>) item {
    SEL action = [item action];
    
    NSInteger tracksSelected = tracksTableView.selectedRowIndexes.count;
    
    SBSelectedRowStatus selectedTrackRowStatus = 0;
    selectedTrackRowStatus = [self selectedRowStatus: tracksController.arrangedObjects selectedIndices: tracksTableView.selectedRowIndexes];
    
    if (action == @selector(addSelectedToTracklist:)
        || action == @selector(playSelected:)
        || action == @selector(createNewLocalPlaylistWithSelectedTracks:)) {
        return tracksSelected;
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
