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
#import "SBSubsonicParsingOperation.h"
#import "SBDatabaseController.h"
#import "SBPlayer.h"
#import "SBTrack.h"
#import "SBSearchResult.h"
#import "SBSubsonicDownloadOperation.h"
#import "NSOperationQueue+Shared.h"


@interface SBServerSearchController (Private)
- (void)subsonicSearchResultUpdatedNotification:(NSNotification *)notification;
@end




@implementation SBServerSearchController

+ (NSString *)nibName {
    return @"ServerSearch";
}


@synthesize searchResult;


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:SBSubsonicSearchResultUpdatedNotification object:nil];
}

- (void)loadView {
    [super loadView];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(subsonicSearchResultUpdatedNotification:) 
                                                 name:SBSubsonicSearchResultUpdatedNotification 
                                               object:nil];
    
    [tracksTableView setTarget:self];
    [tracksTableView setDoubleAction:@selector(trackDoubleClick:)];
    [tracksTableView registerForDraggedTypes:[NSArray arrayWithObject:SBLibraryTableViewDataType]];
}





#pragma mark - 
#pragma mark Subsonic notification

- (void)subsonicSearchResultUpdatedNotification:(NSNotification *)notification {    
    NSLog(@"setSearchResult");
    [self setSearchResult:[notification object]];
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
    __weak NSMutableArray *tracks = [NSMutableArray array];
    
    [indexSet enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        [tracks addObject:[[tracksController arrangedObjects] objectAtIndex:idx]];
    }];
    
    [[SBPlayer sharedInstance] addTrackArray:tracks replace:NO];
}

- (IBAction)downloadTrack:(id)sender {
    NSInteger selectedRow = [tracksTableView selectedRow];
    
    if(selectedRow != -1) {
        SBTrack *track = [[tracksController arrangedObjects] objectAtIndex:selectedRow];
        if(track != nil) {
            SBSubsonicDownloadOperation *op = [[SBSubsonicDownloadOperation alloc] initWithManagedObjectContext:self.managedObjectContext];
            [op setTrackID:(SBTrackID *)[track objectID]];
            
            [[NSOperationQueue sharedDownloadQueue] addOperation:op];
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
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:trackURIs];
        
        // register data to pastboard
        [pboard declareTypes:[NSArray arrayWithObject:SBLibraryTableViewDataType] owner:self];
        [pboard setData:data forType:SBLibraryTableViewDataType];
        ret = YES;
    }
    return ret;
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
        
        [menu addItem:[NSMenuItem separatorItem]];
        
        item = [[NSMenuItem alloc] initWithTitle:@"Download Track" action:@selector(downloadTrack:) keyEquivalent:@""];
        [item setTarget:self];
        [menu addItem:item];
        
        return menu;
        
    }
    return nil;
}





#pragma mark - 
#pragma mark NSTableView delegate

- (void)tableViewEnterKeyPressedNotification:(NSNotification *)notification {
    [self trackDoubleClick:self];
}



@end
