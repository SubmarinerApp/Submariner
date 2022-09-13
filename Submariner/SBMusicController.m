//
//  SBMusicController.m
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

#import "SBMusicController.h"
#import "SBDatabaseController.h"
#import "SBPrioritySplitViewDelegate.h"
#import "SBMergeArtistsController.h"
#import "SBIndex.h"
#import "SBGroup.h"
#import "SBArtist.h"
#import "SBAlbum.h"
#import "SBTrack.h"
#import "SBPlayer.h"



// main split view constant
#define LEFT_VIEW_INDEX 0
#define LEFT_VIEW_PRIORITY 2
#define LEFT_VIEW_MINIMUM_WIDTH 175.0

#define MAIN_VIEW_INDEX 1
#define MAIN_VIEW_PRIORITY 0
#define MAIN_VIEW_MINIMUM_WIDTH 200.0




@implementation SBMusicController

+ (NSString *)nibName {
    return @"Music";
}


- (NSString*)title {
    return @"Local Library";
}

@synthesize artistSortDescriptor;
@synthesize trackSortDescriptor;
@synthesize databaseController;
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
    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:@"coverSize"];
    [albumsController removeObserver:self forKeyPath:@"selectedObjects"];
    
}

- (void)loadView {
    [super loadView];
    
    //[artistSplitView setPosition:LEFT_VIEW_MINIMUM_WIDTH ofDividerAtIndex:0];
    
    [splitViewDelegate setPriority:LEFT_VIEW_PRIORITY forViewAtIndex:LEFT_VIEW_INDEX];
	[splitViewDelegate setMinimumLength:LEFT_VIEW_MINIMUM_WIDTH forViewAtIndex:LEFT_VIEW_INDEX];
    
	[splitViewDelegate setPriority:MAIN_VIEW_PRIORITY forViewAtIndex:MAIN_VIEW_INDEX];
	[splitViewDelegate setMinimumLength:MAIN_VIEW_MINIMUM_WIDTH forViewAtIndex:MAIN_VIEW_INDEX];
    
    [artistSplitView setDelegate:splitViewDelegate];

    // add drag and drop support
    [tracksTableView registerForDraggedTypes:[NSArray arrayWithObject:SBLibraryTableViewDataType]];
    
    [tracksTableView setTarget:self];
    [tracksTableView setDoubleAction:@selector(trackDoubleClick:)];
    
    [mergeArtistsController setParentWindow:[databaseController window]];

    [albumsBrowserView setZoomValue:[[NSUserDefaults standardUserDefaults] floatForKey:@"coverSize"]];

    // observer browser zoom value
    [[NSUserDefaults standardUserDefaults] addObserver:self
                                            forKeyPath:@"coverSize" 
                                               options:NSKeyValueObservingOptionNew
                                               context:nil];
    
    // Observe album for saving. Artist isn't observed because it triggers after for some reason.
    [albumsController addObserver:self
                      forKeyPath:@"selectedObjects"
                      options:NSKeyValueObservingOptionNew
                      context:nil];
}


- (void)observeValueForKeyPath:(NSString *)keyPath 
                      ofObject:(id)object 
                        change:(NSDictionary *)change 
                       context:(void *)context {
    
    if(object == [NSUserDefaults standardUserDefaults] && [keyPath isEqualToString:@"coverSize"]) {
        [albumsBrowserView setZoomValue:[[NSUserDefaults standardUserDefaults] floatForKey:@"coverSize"]];
        [albumsBrowserView setNeedsDisplay:YES];
    } else if (object == albumsController && [keyPath isEqualToString:@"selectedObjects"]) {
        SBAlbum *album = albumsController.selectedObjects.firstObject;
        if (album != nil) {
            NSString *urlString = album.objectID.URIRepresentation.absoluteString;
            [[NSUserDefaults standardUserDefaults] setObject: urlString forKey: @"LastViewedResource"];
        }
    } else if (object == artistsController && [keyPath isEqualToString:@"content"]) {
        // see reasoning in showAlbumInLibrary
        [artistsController removeObserver: self forKeyPath: @"content"];
        SBAlbum *album = (SBAlbum*)CFBridgingRelease(context);
        // avoid a loop, but do release the refcount we have on a transfer
        if (((NSArray*)artistsController.content).count > 0) {
            [self showAlbumInLibrary: album];
        }
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
#pragma mark IBAction


- (IBAction)filterArtist:(id)sender {
    
    NSPredicate *predicate = nil;
    NSString *searchString = nil;
    
    searchString = [sender stringValue];
    
    if(searchString != nil && [searchString length] > 0) {
        predicate = [NSPredicate predicateWithFormat:@"(itemName CONTAINS[cd] %@) && (server == %@)", searchString, nil];
        [artistsController setFilterPredicate:predicate];
    } else {
        predicate = [NSPredicate predicateWithFormat:@"(server == %@)", nil];
        [artistsController setFilterPredicate:predicate];
    }
}

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


- (IBAction)playSelected:(id)sender {
    NSResponder *responder = self.databaseController.window.firstResponder;
    if (responder == tracksTableView) {
        [self trackDoubleClick: self];
    } else if (responder == albumsBrowserView) {
        // XXX
        //[self albumDoubleClick: self];
        [self imageBrowser:albumsBrowserView cellWasDoubleClickedAtIndex:-1];
    }
}


- (IBAction)removeArtist:(id)sender {
    NSInteger selectedRow = [artistsTableView selectedRow];
    
    if(selectedRow != -1) {
        SBArtist *selectedArtist = [[artistsController arrangedObjects] objectAtIndex:selectedRow];
        if(selectedArtist != nil) {
            if([selectedArtist.isLinked boolValue] == NO) {
                NSAlert *alert = [[NSAlert alloc] init];
                [alert addButtonWithTitle:@"Remove"];
                [alert addButtonWithTitle:@"Cancel"];
                [alert addButtonWithTitle:@"Delete"];
                [alert setMessageText:@"Delete the selected artist ?"];
                [alert setInformativeText:@"This artist has been copied to Submariner database. If you choose Delete, the artist will be removed from the database and deleted from your file system. If you choose Remove, copied files will be preserved."];
                [alert setAlertStyle:NSAlertStyleWarning];
                
                [alert beginSheetModalForWindow: [[self view] window] completionHandler:^(NSModalResponse returnCode) {
                    [self removeArtistAlertDidEnd: alert returnCode: returnCode contextInfo: nil];
                }];
                
            } else {
                NSAlert *alert = [[NSAlert alloc] init];
                [alert addButtonWithTitle:@"OK"];
                [alert addButtonWithTitle:@"Cancel"];
                [alert setMessageText:@"Remove the selected artist ?"];
                [alert setInformativeText:@"Removed artists cannot be restored."];
                [alert setAlertStyle:NSAlertStyleWarning];
                
                [alert beginSheetModalForWindow: [[self view] window] completionHandler:^(NSModalResponse returnCode) {
                    [self removeArtistAlertDidEnd: alert returnCode: returnCode contextInfo: nil];
                }];
            }
        }
    }
}

- (IBAction)removeAlbum:(id)sender {
    NSIndexSet *indexSet = [albumsBrowserView selectionIndexes];
    NSInteger selectedRow = [indexSet firstIndex];
    
    if(selectedRow != -1) {
        SBAlbum *selectedAlbum = [[albumsController arrangedObjects] objectAtIndex:selectedRow];
        if(selectedAlbum != nil) {
            if([selectedAlbum.isLinked boolValue] == NO) {
                
                NSAlert *alert = [[NSAlert alloc] init];
                [alert addButtonWithTitle:@"Remove"];
                [alert addButtonWithTitle:@"Cancel"];
                [alert addButtonWithTitle:@"Delete"];
                [alert setMessageText:@"Delete the selected album ?"];
                [alert setInformativeText:@"This album has been copied to Submariner database. If you choose Delete, the artist will be removed from the database and deleted from your file system. If you choose Remove, copied files will be preserved."];
                [alert setAlertStyle:NSAlertStyleWarning];
                
                [alert beginSheetModalForWindow: [[self view] window] completionHandler:^(NSModalResponse returnCode) {
                    [self removeAlbumAlertDidEnd: alert returnCode: returnCode contextInfo: nil];
                }];
                
            } else {
                NSAlert *alert = [[NSAlert alloc] init];
                [alert addButtonWithTitle:@"OK"];
                [alert addButtonWithTitle:@"Cancel"];
                [alert setMessageText:@"Remove the selected album ?"];
                [alert setInformativeText:@"Removed album cannot be restored."];
                [alert setAlertStyle:NSAlertStyleWarning];
                
                [alert beginSheetModalForWindow: [[self view] window] completionHandler:^(NSModalResponse returnCode) {
                    [self removeAlbumAlertDidEnd: alert returnCode: returnCode contextInfo: nil];
                }];
            }
        }
    }
}

- (IBAction)removeTrack:(id)sender {
    NSInteger selectedRow = [tracksTableView selectedRow];
    
    if(selectedRow != -1) {
        SBTrack *selectedTrack = [[tracksController arrangedObjects] objectAtIndex:selectedRow];
        if(selectedTrack != nil) {
            if([selectedTrack.isLinked boolValue] == NO) {
                NSAlert *alert = [[NSAlert alloc] init];
                [alert addButtonWithTitle:@"Remove"];
                [alert addButtonWithTitle:@"Cancel"];
                [alert addButtonWithTitle:@"Delete"];
                [alert setMessageText:@"Delete the selected track ?"];
                [alert setInformativeText:@"This track has been copied to Submariner database. If you choose Delete, the track will be removed from the database and deleted from your file system. If you choose Remove, copied files will be preserved."];
                [alert setAlertStyle:NSAlertStyleWarning];
                
                [alert beginSheetModalForWindow: [[self view] window] completionHandler:^(NSModalResponse returnCode) {
                    [self removeTrackAlertDidEnd: alert returnCode: returnCode contextInfo: nil];
                }];
                
            } else {
                NSAlert *alert = [[NSAlert alloc] init];
                [alert addButtonWithTitle:@"OK"];
                [alert addButtonWithTitle:@"Cancel"];
                [alert setMessageText:@"Remove the selected track ?"];
                [alert setInformativeText:@"Removed tracks cannot be restored."];
                [alert setAlertStyle:NSAlertStyleWarning];
                
                [alert beginSheetModalForWindow: [[self view] window] completionHandler:^(NSModalResponse returnCode) {
                    [self removeTrackAlertDidEnd: alert returnCode: returnCode contextInfo: nil];
                }];
            }
        }
    }
}


- (IBAction)delete:(id)sender {
    NSResponder *responder = self.databaseController.window.firstResponder;
    if (responder == tracksTableView) {
        [self removeTrack: self];
    } else if (responder == albumsBrowserView) {
        [self removeAlbum: self];
    } else if (responder == artistsTableView) {
        [self removeArtist: self];
    }
}



- (IBAction)showArtistInFinder:(in)sender {
    NSMutableArray *urls = [NSMutableArray array];
    
    [artistsTableView.selectedRowIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        SBArtist *artist = [[artistsController arrangedObjects] objectAtIndex:idx];
        NSURL *trackURL = [NSURL fileURLWithPath: artist.path];
        [urls addObject: trackURL];
    }];
    
    if ([urls count] > 0) {
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs: urls];
    }
}

- (IBAction)showAlbumInFinder:(in)sender {
    NSIndexSet *indexSet = [albumsBrowserView selectionIndexes];
    NSInteger selectedRow = [indexSet firstIndex];
    
    if(selectedRow != -1) {
        SBAlbum *album = [[albumsController arrangedObjects] objectAtIndex:selectedRow];
        if(album != nil && album.path != nil && ![album.path isEqualToString:@""]) {
            [[NSWorkspace sharedWorkspace] selectFile:album.path inFileViewerRootedAtPath:@""];
        }
    }
}


- (IBAction)showTrackInFinder:(in)sender {
    NSInteger selectedRow = [tracksTableView selectedRow];
    
    if(selectedRow == -1) {
        return;
    }
    
    [self showTracksInFinder: tracksController.arrangedObjects selectedIndices: tracksTableView.selectedRowIndexes];
}


- (IBAction)showSelectedInFinder:(id)sender {
    NSResponder *responder = self.databaseController.window.firstResponder;
    if (responder == tracksTableView) {
        [self showTrackInFinder: self];
    } else if (responder == albumsBrowserView) {
        [self showAlbumInFinder: self];
    } else if (responder == artistsTableView) {
        [self showArtistInFinder: self];
    }
}


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

- (IBAction)mergeArtists:(id)sender {
    NSIndexSet *indexSet = [artistsTableView selectedRowIndexes];
    if(indexSet && [indexSet count]) {
        
        
        NSArray *artists = [[artistsController arrangedObjects] objectsAtIndexes:[artistsTableView selectedRowIndexes]];
        
        [mergeArtistsController setArtists:artists];
        [mergeArtistsController openSheet:sender];  
    }
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


- (void)showTrackInLibrary:(SBTrack*)track {
    [artistsController setSelectedObjects: @[track.album.artist]];
    [artistsTableView scrollRowToVisible: [artistsTableView selectedRow]];
    [albumsController setSelectedObjects: @[track.album]];
    [albumsBrowserView scrollIndexToVisible: [[albumsBrowserView selectionIndexes] firstIndex]];
    [tracksController setSelectedObjects: @[track]];
    [tracksTableView scrollRowToVisible: [tracksTableView selectedRow]];
}


- (void)showAlbumInLibrary:(SBAlbum*)album {
    // HACK: We're called when the content of the controller is empty.
    // As such, we can't set it until it's loaded.
    // For some reason, the server library controller is loaded early enough.
    // I'm guessing that's because the bindings in the nib set content explicitly,
    // whereas here it's implied through the MOC.
    // This means we'll just post a notification to set it again until it's ready.
    if (artistsController.content == nil  || ((NSArray*)artistsController.content).count < 1) {
        // The observer means we'll have to transfer ownership in ARC. Ugly.
        [artistsController addObserver:self
                          forKeyPath:@"content"
                          options:NSKeyValueObservingOptionNew
                          context:(void*)CFBridgingRetain(album)];
    }
    [artistsController setSelectedObjects: @[album.artist]];
    [artistsTableView scrollRowToVisible: [artistsTableView selectedRow]];
    [albumsController setSelectedObjects: @[album]];
    [albumsBrowserView scrollIndexToVisible: [[albumsBrowserView selectionIndexes] firstIndex]];
}


- (void)showArtistInLibrary:(SBArtist*)artist {
    [artistsController setSelectedObjects: @[artist]];
    [artistsTableView scrollRowToVisible: [artistsTableView selectedRow]];
}




#pragma mark -
#pragma mark NSAlert Sheet support


- (void)removeTrackAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSAlertFirstButtonReturn) {
        // just remove
        NSInteger selectedRow = [tracksTableView selectedRow];
        
        if(selectedRow != -1) {
            SBTrack *selectedTrack = [[tracksController arrangedObjects] objectAtIndex:selectedRow];
            if(selectedTrack != nil) {
                [self.managedObjectContext deleteObject:selectedTrack];
                [self.managedObjectContext processPendingChanges];
                [self.managedObjectContext save:nil];
                [[NSUserDefaults standardUserDefaults] removeObjectForKey: @"LastViewedResource"];
            }
        }
    } else if(returnCode == NSAlertThirdButtonReturn) {
        // remove then delete
        NSInteger selectedRow = [tracksTableView selectedRow];
        
        if(selectedRow != -1) {
            SBTrack *selectedTrack = [[tracksController arrangedObjects] objectAtIndex:selectedRow];
            if(selectedTrack != nil) {
                // delete from file system
                NSError *error = nil;
                
                NSString *trackPath = selectedTrack.path;
                if(![[NSFileManager defaultManager] removeItemAtPath:trackPath error:&error]) {
                    [NSApp presentError:error];
                }
                
                // remove from context
                [self.managedObjectContext deleteObject:selectedTrack];
                [self.managedObjectContext processPendingChanges];
                [self.managedObjectContext save:nil];
                [[NSUserDefaults standardUserDefaults] removeObjectForKey: @"LastViewedResource"];
            }
        }
    }
}

- (void)removeAlbumAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSAlertFirstButtonReturn) {
        // just remove
        NSIndexSet *indexSet = [albumsBrowserView selectionIndexes];
        NSInteger selectedRow = [indexSet firstIndex];
        
        if(selectedRow != -1) {
            SBAlbum *selectedAlbum = [[albumsController arrangedObjects] objectAtIndex:selectedRow];
            if(selectedAlbum != nil) {
                [self.managedObjectContext deleteObject:selectedAlbum];
                [self.managedObjectContext processPendingChanges];
                [self.managedObjectContext save:nil];
                [[NSUserDefaults standardUserDefaults] removeObjectForKey: @"LastViewedResource"];
            }
        }
        
    } else if(returnCode == NSAlertThirdButtonReturn) {
        // remove then delete
        NSIndexSet *indexSet = [albumsBrowserView selectionIndexes];
        NSInteger selectedRow = [indexSet firstIndex];
        
        if(selectedRow != -1) {
            SBAlbum *selectedAlbum = [[albumsController arrangedObjects] objectAtIndex:selectedRow];
            if(selectedAlbum != nil) {
                // delete from file system
                NSError *error = nil;
                
                NSString *trackPath = selectedAlbum.path;
                if(![[NSFileManager defaultManager] removeItemAtPath:trackPath error:&error]) {
                    [NSApp presentError:error];
                }
                
                // remove from context
                [self.managedObjectContext deleteObject:selectedAlbum];
                [self.managedObjectContext processPendingChanges];
                [self.managedObjectContext save:nil];
                [[NSUserDefaults standardUserDefaults] removeObjectForKey: @"LastViewedResource"];
            }
        }
    } 
}

- (void)removeArtistAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo { 
    if (returnCode == NSAlertFirstButtonReturn) {
        // just remove
        NSInteger selectedRow = [artistsTableView selectedRow];
        
        if(selectedRow != -1) {
            SBArtist *selectedArtist = [[artistsController arrangedObjects] objectAtIndex:selectedRow];
            if(selectedArtist != nil) {
                [self.managedObjectContext deleteObject:selectedArtist];
                [self.managedObjectContext processPendingChanges];
                [self.managedObjectContext save:nil];
                [[NSUserDefaults standardUserDefaults] removeObjectForKey: @"LastViewedResource"];
            }
        }
        
    } else if(returnCode == NSAlertThirdButtonReturn) {
        // remove then delete
        NSInteger selectedRow = [artistsTableView selectedRow];
        
        if(selectedRow != -1) {
            SBArtist *selectedArtist = [[artistsController arrangedObjects] objectAtIndex:selectedRow];
            if(selectedArtist != nil) {
                // delete from file system
                NSError *error = nil;
                
                NSString *artistPath = selectedArtist.path;
                if(![[NSFileManager defaultManager] removeItemAtPath:artistPath error:&error]) {
                    [NSApp presentError:error];
                }
                
                // remove from context
                [self.managedObjectContext deleteObject:selectedArtist];
                [self.managedObjectContext processPendingChanges];
                [self.managedObjectContext save:nil];
                [[NSUserDefaults standardUserDefaults] removeObjectForKey: @"LastViewedResource"];
            }
        }
    }
}




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
            if(index && ![index isKindOfClass:[SBGroup class]])
                return 22.0f;
            if(index && [index isKindOfClass:[SBGroup class]])
                return 20.0f;
        }
    }
    return 17.0f;
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


- (NSMenu *)tableView:(id)tableView menuForEvent:(NSEvent *)event {
    if(tableView == tracksTableView) {
        NSMenu*  menu = nil;
        NSMenuItem *item = nil;
        
        menu = [[NSMenu alloc] initWithTitle:@"trackMenu"];
        [menu setAutoenablesItems:NO];
        
        item = [[NSMenuItem alloc] initWithTitle:@"Play" action:nil keyEquivalent:@""];
        [item setTarget:self];
        [menu addItem:item];
        
        item = [[NSMenuItem alloc] initWithTitle:@"Add to Tracklist" action:@selector(addTrackToTracklist:) keyEquivalent:@""];
        [item setTarget:self];
        [menu addItem:item];
        
        item = [[NSMenuItem alloc] initWithTitle:@"Show in Finder" action:@selector(showTrackInFinder:) keyEquivalent:@""];
        [item setTarget:self];
        [menu addItem:item];
        
        [menu addItem:[NSMenuItem separatorItem]];
        
        item = [[NSMenuItem alloc] initWithTitle:@"Remove Track" action:@selector(removeTrack:) keyEquivalent:@""];
        [item setTarget:self];
        [menu addItem:item];
                
        return menu;
        
    } else if(tableView == artistsTableView) {
        NSMenu*  menu = nil;
        NSMenuItem *item = nil;
        
        menu = [[NSMenu alloc] initWithTitle:@"artistMenu"];
        [menu setAutoenablesItems:NO];
        
//        item = [[[NSMenuItem alloc] initWithTitle:@"Play" action:nil keyEquivalent:@""] autorelease];
//        [item setTarget:self];
//        [menu addItem:item];
        
        item = [[NSMenuItem alloc] initWithTitle:@"Add to Tracklist" action:@selector(addArtistToTracklist:) keyEquivalent:@""];
        [item setTarget:self];
        [menu addItem:item];
        
        item = [[NSMenuItem alloc] initWithTitle:@"Show in Finder" action:@selector(showArtistInFinder:) keyEquivalent:@""];
        [item setTarget:self];
        [menu addItem:item];
        
        
        // multiple selection ?
        if([[artistsTableView selectedRowIndexes] count] > 1) {
            [menu addItem:[NSMenuItem separatorItem]];
            
            item = [[NSMenuItem alloc] initWithTitle:@"Merge Artists" action:@selector(mergeArtists:) keyEquivalent:@""];
            [item setTarget:self];
            [menu addItem:item];
        }
        
        [menu addItem:[NSMenuItem separatorItem]];
        
        item = [[NSMenuItem alloc] initWithTitle:@"Remove Artist" action:@selector(removeArtist:) keyEquivalent:@""];
        [item setTarget:self];
        [menu addItem:item];
        
        return menu;
        
    }
    return nil;
}






#pragma mark -
#pragma mark Tracks NSTableView Delegate (Tracks Drag & Drop)

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


// No server side command to send, it's local
//#pragma mark -
//#pragma mark Tracks NSTableView DataSource (Rating)
//
//- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
//    if(aTableView == tracksTableView) {
//        if([[aTableColumn identifier] isEqualToString:@"rating"]) {
//            
//            NSInteger selectedRow = [tracksTableView selectedRow];
//            if(selectedRow != -1) {
//                SBTrack *clickedTrack = [[tracksController arrangedObjects] objectAtIndex:selectedRow];
//                
//                if(clickedTrack) {
//                    
//                    NSInteger rating = [anObject intValue];
//                    NSString *trackID = [clickedTrack id];
//                    
//                    [clickedTrack.server setRating:rating forID:trackID];
//                }
//            }
//        }
//    }
//}
//



#pragma mark - 
#pragma mark NSTableView (enter & delete)

- (void)tableViewEnterKeyPressedNotification:(NSNotification *)notification {
    [self trackDoubleClick:self];
}

- (void)tableViewDeleteKeyPressedNotification:(NSNotification *)notification {
    [self removeTrack:self];
}





#pragma mark -
#pragma mark IKImageBrowserView Delegate

- (void)imageBrowser:(IKImageBrowserView *)aBrowser cellWasRightClickedAtIndex:(NSUInteger) index withEvent:(NSEvent *)event {
    //contextual menu for item index
    NSMenu*  menu = nil;
    NSMenuItem *item = nil;
    
    menu = [[NSMenu alloc] initWithTitle:@"albumsMenu"];
    [menu setAutoenablesItems:NO];
    
    item = [[NSMenuItem alloc] initWithTitle:@"Play" action:nil keyEquivalent:@""];
    [item setTarget:self];
    [menu addItem:item];
    
    item = [[NSMenuItem alloc] initWithTitle:@"Add to Tracklist" action:@selector(addAlbumToTracklist:) keyEquivalent:@""];
    [item setTarget:self];
    [menu addItem:item];
    
    item = [[NSMenuItem alloc] initWithTitle:@"Show in Finder" action:@selector(showAlbumInFinder:) keyEquivalent:@""];
    [item setTarget:self];
    [menu addItem:item];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    item = [[NSMenuItem alloc] initWithTitle:@"Remove Album" action:@selector(removeAlbum:) keyEquivalent:@""];
    [item setTarget:self];
    [menu addItem:item];
    
    [NSMenu popUpContextMenu:menu withEvent:event forView:aBrowser];
    

}

- (void)imageBrowser:(IKImageBrowserView *)aBrowser cellWasDoubleClickedAtIndex:(NSUInteger)index {
    NSIndexSet *indexSet = [aBrowser selectionIndexes];
    NSInteger selectedRow = [indexSet firstIndex];
    if(selectedRow != -1) {
        SBAlbum *doubleClickedAlbum = [[albumsController arrangedObjects] objectAtIndex:selectedRow];
        if(doubleClickedAlbum) {
            
            NSArray *tracks = [doubleClickedAlbum.tracks sortedArrayUsingDescriptors:trackSortDescriptor];
            
            // stop current playing tracks
            [[SBPlayer sharedInstance] stop];
            
            // add track to player
            [[SBPlayer sharedInstance] addTrackArray:tracks replace:YES];
            
            // play track
            [[SBPlayer sharedInstance] playTrack:[tracks objectAtIndex:0]];
        }
    }
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
    
    if (action == @selector(mergeArtists:)) {
        return artistsSelected > 1 && artistsActive;
    }
    
    if (action == @selector(addSelectedToTracklist:)) {
        return artistsSelected > 0 || albumSelected > 0 || tracksSelected > 0;
    }
    
    if (action == @selector(playSelected:)) {
        return (albumSelected > 0 || tracksSelected > 0) && (albumsActive || tracksActive);
    }
    
    if (action == @selector(showSelectedInFinder:)) {
        return artistsActive > 0 || albumSelected > 0 || tracksSelected > 0;
    }

    return YES;
}



@end
