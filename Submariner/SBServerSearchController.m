//
//  SBServerServerController.m
//  Submariner
//
//  Created by Rafaël Warnault on 25/06/11.
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

#import "SBServerSearchController.h"
#import "SBDatabaseController.h"

#import "Submariner-Swift.h"


@interface SBServerSearchController (Private)
- (void)subsonicSearchResultUpdatedNotification:(NSNotification *)notification;
@end




@implementation SBServerSearchController

+ (NSString *)nibName {
    return @"ServerSearch";
}


- (NSString*)title {
    return [NSString stringWithFormat: @"Search Results on %@", self.server.resourceName];
}


@synthesize searchResult;
@synthesize databaseController;


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"SBSubsonicSearchResultUpdatedNotification" object:nil];
}

- (void)loadView {
    [super loadView];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(subsonicSearchResultUpdatedNotification:) 
                                                 name:@"SBSubsonicSearchResultUpdatedNotification"
                                               object:nil];
    
    [tracksTableView setTarget:self];
    [tracksTableView setDoubleAction:@selector(trackDoubleClick:)];
    [tracksTableView registerForDraggedTypes:[NSArray arrayWithObject:SBLibraryTableViewDataType]];
}





#pragma mark - 
#pragma mark Subsonic notification

- (void)subsonicSearchResultUpdatedNotification:(NSNotification *)notification {    
    NSLog(@"setSearchResult");
    dispatch_async(dispatch_get_main_queue(), ^{
        SBSearchResult *results = [notification object];
        // HACK: We can't use the objects that were fetched on another thread.
        // Refetch on this one from ours. Better way possible?
        [results replaceManagedInstancesForThreadWithManagedObjectContext: self.managedObjectContext];
        [self setSearchResult:[notification object]];
    });
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

- (IBAction)addTrackToTracklist:(id)sender {
    NSIndexSet *indexSet = [tracksTableView selectedRowIndexes];
    NSMutableArray *tracks = [NSMutableArray array];
    
    [indexSet enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        [tracks addObject:[[tracksController arrangedObjects] objectAtIndex:idx]];
    }];
    
    [[SBPlayer sharedInstance] addTrackArray:tracks replace:NO];
}

- (IBAction)downloadTrack:(id)sender {
    NSInteger selectedRow = [tracksTableView selectedRow];
    
    if(selectedRow != -1) {
        [self downloadTracks: tracksController.arrangedObjects selectedIndices: tracksTableView.selectedRowIndexes databaseController: nil];
    }
}


- (IBAction)playSelected:(id)sender {
    [self trackDoubleClick:sender];
}


- (IBAction)addSelectedToTracklist:(id)sender {
    [self addTrackToTracklist: sender];
}


- (IBAction)showSelectedInFinder:(id)sender {
    NSInteger selectedRow = [tracksTableView selectedRow];
    
    if(selectedRow == -1) {
        return;
    }
    
    [self showTracksInFinder: tracksController.arrangedObjects selectedIndices: tracksTableView.selectedRowIndexes];
}


- (IBAction)downloadSelected:(id)sender {
    [self downloadTrack: sender];
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


- (IBAction)createNewLocalPlaylistWithSelectedTracks:(id)sender {
    NSInteger selectedRow = [tracksTableView selectedRow];
    
    if(selectedRow == -1) {
        return;
    }
    
    [self createLocalPlaylistWithSelected: tracksController.arrangedObjects selectedIndices: tracksTableView.selectedRowIndexes databaseController: self.databaseController];
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
    
    if (action == @selector(showSelectedInLibrary:)) {
        return tracksTableView.selectedRowIndexes.count == 1;
    }

    return YES;
}



@end
