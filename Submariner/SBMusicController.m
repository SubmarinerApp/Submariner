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

#import "Submariner-Swift.h"




@implementation SBMusicController

+ (NSString *)nibName {
    return @"Music";
}


- (NSString*)title {
    return @"Local Library";
}

@synthesize artistSortDescriptor;


- (id)initWithManagedObjectContext:(NSManagedObjectContext *)context {
    self = [super initWithManagedObjectContext:context];
    if (self) {
        NSSortDescriptor *artistDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"itemName" ascending:YES selector: @selector(artistListCompare:)];
        artistSortDescriptor = [NSArray arrayWithObject:artistDescriptor];
        
        NSSortDescriptor *albumYearDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"year" ascending:YES];
        NSSortDescriptor *albumNameDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"itemName" ascending:YES selector: @selector(caseInsensitiveCompare:)];
        albumSortDescriptor = @[albumYearDescriptor, albumNameDescriptor];
        
        NSSortDescriptor *trackNumberDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"trackNumber" ascending:YES];
        NSSortDescriptor *discNumberDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"discNumber" ascending:YES];
        trackSortDescriptor = @[discNumberDescriptor, trackNumberDescriptor];
    }
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    self->compensatedSplitView = self->rightSplitView;
    // so it doesn't resize unless the user does so
    artistSplitView.delegate = self;
}


- (void)viewDidAppear {
    [super viewDidAppear];
    [[NSNotificationCenter defaultCenter] postNotificationName: @"SBTrackSelectionChanged"
                                                        object: tracksController.selectedObjects];
}

- (void)dealloc
{
    [[NSUserDefaults standardUserDefaults] removeObserver: self forKeyPath: @"albumSortOrder"];
    [artistsController removeObserver:self forKeyPath:@"selectedObjects"];
    [albumsController removeObserver:self forKeyPath:@"selectedObjects"];
    [tracksController removeObserver:self forKeyPath:@"selectedObjects"];
}

- (void)loadView {
    [super loadView];
    
    // this has to be registered at load, not awake time
    [albumsCollectionView registerClass: SBAlbumViewItem.class forItemWithIdentifier: @"SBAlbumViewItem"];
    
    [mergeArtistsController setParentWindow:[databaseController window]];
    
    // Observe album for saving. Artist isn't observed for saving because it triggers after for some reason.
    [artistsController addObserver:self
                       forKeyPath:@"selectedObjects"
                       options:NSKeyValueObservingOptionNew
                       context:nil];
    
    [albumsController addObserver:self
                      forKeyPath:@"selectedObjects"
                      options:NSKeyValueObservingOptionNew
                      context:nil];
    
    [tracksController addObserver:self
                      forKeyPath:@"selectedObjects"
                      options:NSKeyValueObservingOptionNew
                      context:nil];
    
    [[NSUserDefaults standardUserDefaults] addObserver: self
                                            forKeyPath: @"albumSortOrder"
                                               options: NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial
                                               context: nil];
}


- (void)observeValueForKeyPath:(NSString *)keyPath 
                      ofObject:(id)object 
                        change:(NSDictionary *)change 
                       context:(void *)context {
    
    if (object == albumsController && [keyPath isEqualToString:@"selectedObjects"]) {
        SBAlbum *album = albumsController.selectedObjects.firstObject;
        if (album != nil) {
            NSString *urlString = album.objectID.URIRepresentation.absoluteString;
            [[NSUserDefaults standardUserDefaults] setObject: urlString forKey: @"LastViewedResource"];
        }
        [albumsCollectionView setSelectionIndexes: albumsController.selectionIndexes];
    } else if (object == artistsController && [keyPath isEqualToString:@"selectedObjects"]) {
        // albums collection view has no way to know otherwise
        [albumsCollectionView reloadData];
        [albumsCollectionView setSelectionIndexes: albumsController.selectionIndexes];
    } else if (object == tracksController && [keyPath isEqualToString:@"selectedObjects"] && self.view.window != nil) {
        [[NSNotificationCenter defaultCenter] postNotificationName: @"SBTrackSelectionChanged"
                                                            object: tracksController.selectedObjects];
    } else if (object == [NSUserDefaults standardUserDefaults] && [keyPath isEqualToString: @"albumSortOrder"]) {
        albumSortDescriptor = [self sortDescriptorsForPreference];
        albumsController.sortDescriptors = albumSortDescriptor;
    }
}


/// Gets the selected track, album, or artist, in that order. Used mostly for saving state.
- (SBMusicItem*) selectedItem {
    NSInteger selectedTracks = [tracksTableView selectedRow];
    if (selectedTracks != -1) {
        return [tracksController.arrangedObjects objectAtIndex: selectedTracks];
    }
    NSIndexSet *selectedAlbums = [albumsCollectionView selectionIndexes];
    if ([selectedAlbums count] > 0) {
        return [albumsController.arrangedObjects objectAtIndex: [selectedAlbums firstIndex]];
    }
    NSInteger selectedArtists = [artistsTableView selectedRow];
    if (selectedArtists != -1) {
        return [artistsController.arrangedObjects objectAtIndex: selectedArtists];
    }
    return nil;
}


#pragma mark - Properties

- (NSArray<SBTrack*>*) tracks {
    return [tracksController arrangedObjects];
}


- (NSInteger) selectedTrackRow {
    return tracksTableView.selectedRow;
}


- (NSArray<SBTrack*>*) selectedTracks {
    return [tracksController selectedObjects];
}


- (NSArray<SBAlbum*>*) selectedAlbums {
    return [albumsController selectedObjects];
}


- (NSArray<SBArtist*>*) selectedArtists {
    return [artistsController selectedObjects];
}


- (NSArray<id<SBStarrable>>*) selectedMusicItems {
    NSResponder *responder = self.databaseController.window.firstResponder;
    if (responder == tracksTableView) {
        return [tracksController selectedObjects];
    } else if (responder == albumsCollectionView) {
        return [albumsController selectedObjects];
    } else if (responder == artistsTableView) {
        return [artistsController selectedObjects];
    }
    return @[];
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

- (IBAction)removeArtist:(id)sender {
    NSInteger selectedRow = [artistsTableView selectedRow];
    
    if(selectedRow != -1) {
        SBArtist *selectedArtist = [[artistsController arrangedObjects] objectAtIndex:selectedRow];
        if(selectedArtist != nil) {
            if([selectedArtist.isLinked boolValue] == NO) {
                NSAlert *alert = [[NSAlert alloc] init];
                NSButton *removeButton = [alert addButtonWithTitle: @"Remove from Database"];
                removeButton.hasDestructiveAction = YES;
                [alert addButtonWithTitle:@"Cancel"];
                NSButton *deleteButton = [alert addButtonWithTitle: @"Delete Files"];
                deleteButton.hasDestructiveAction = YES;
                [alert setMessageText:@"Delete the selected artist?"];
                [alert setInformativeText:@"This artist has been copied into the Submariner database. If you choose Delete, the artist will be removed from the database and deleted from the file system. If you choose Remove, the copied files will be preserved."];
                [alert setAlertStyle:NSAlertStyleWarning];
                
                [alert beginSheetModalForWindow: [[self view] window] completionHandler:^(NSModalResponse returnCode) {
                    [self removeArtistAlertDidEnd: alert returnCode: returnCode contextInfo: nil];
                }];
                
            } else {
                NSAlert *alert = [[NSAlert alloc] init];
                NSButton *removeButton = [alert addButtonWithTitle:@"Remove"];
                removeButton.hasDestructiveAction = YES;
                [alert addButtonWithTitle:@"Cancel"];
                [alert setMessageText:@"Remove the selected artist?"];
                [alert setInformativeText:@"This can't be undone."];
                [alert setAlertStyle:NSAlertStyleWarning];
                
                [alert beginSheetModalForWindow: [[self view] window] completionHandler:^(NSModalResponse returnCode) {
                    [self removeArtistAlertDidEnd: alert returnCode: returnCode contextInfo: nil];
                }];
            }
        }
    }
}

- (IBAction)removeAlbum:(id)sender {
    NSIndexSet *indexSet = [albumsCollectionView selectionIndexes];
    NSInteger selectedRow = [indexSet firstIndex];
    
    if(selectedRow != -1) {
        SBAlbum *selectedAlbum = [[albumsController arrangedObjects] objectAtIndex:selectedRow];
        if(selectedAlbum != nil) {
            if([selectedAlbum.isLinked boolValue] == NO) {
                
                NSAlert *alert = [[NSAlert alloc] init];
                NSButton *removeButton = [alert addButtonWithTitle: @"Remove from Database"];
                removeButton.hasDestructiveAction = YES;
                [alert addButtonWithTitle:@"Cancel"];
                NSButton *deleteButton = [alert addButtonWithTitle: @"Delete Files"];
                deleteButton.hasDestructiveAction = YES;
                [alert setMessageText:@"Delete the selected album?"];
                [alert setInformativeText:@"This album has been copied into the Submariner database. If you choose Delete, the album will be removed from the database and deleted from the file system. If you choose Remove, the copied files will be preserved."];
                [alert setAlertStyle:NSAlertStyleWarning];
                
                [alert beginSheetModalForWindow: [[self view] window] completionHandler:^(NSModalResponse returnCode) {
                    [self removeAlbumAlertDidEnd: alert returnCode: returnCode contextInfo: nil];
                }];
                
            } else {
                NSAlert *alert = [[NSAlert alloc] init];
                NSButton *removeButton = [alert addButtonWithTitle: @"Remove"];
                removeButton.hasDestructiveAction = YES;
                [alert addButtonWithTitle:@"Cancel"];
                [alert setMessageText:@"Remove the selected album?"];
                [alert setInformativeText:@"This can't be undone."];
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
                NSButton *removeButton = [alert addButtonWithTitle: @"Remove from Database"];
                removeButton.hasDestructiveAction = YES;
                [alert addButtonWithTitle:@"Cancel"];
                NSButton *deleteButton = [alert addButtonWithTitle: @"Delete Files"];
                deleteButton.hasDestructiveAction = YES;
                [alert setMessageText:@"Delete the selected track?"];
                [alert setInformativeText:@"This track has been copied into the Submariner database. If you choose Delete, the track will be removed from the database and deleted from the file system. If you choose Remove, the copied files will be preserved."];
                [alert setAlertStyle:NSAlertStyleWarning];
                
                [alert beginSheetModalForWindow: [[self view] window] completionHandler:^(NSModalResponse returnCode) {
                    [self removeTrackAlertDidEnd: alert returnCode: returnCode contextInfo: nil];
                }];
                
            } else {
                NSAlert *alert = [[NSAlert alloc] init];
                NSButton *removeButton = [alert addButtonWithTitle: @"Remove"];
                removeButton.hasDestructiveAction = YES;
                [alert addButtonWithTitle:@"Cancel"];
                [alert setMessageText:@"Remove the selected track?"];
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
    } else if (responder == albumsCollectionView) {
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
    NSIndexSet *indexSet = [albumsCollectionView selectionIndexes];
    NSInteger selectedRow = [indexSet firstIndex];
    
    if(selectedRow != -1) {
        SBAlbum *album = [[albumsController arrangedObjects] objectAtIndex:selectedRow];
        if(album != nil && album.path != nil && ![album.path isEqualToString:@""]) {
            [[NSWorkspace sharedWorkspace] selectFile:album.path inFileViewerRootedAtPath:@""];
        }
    }
}


// Overrides the SBViewController implementation, as we have local artists and albums
- (IBAction)showSelectedInFinder:(id)sender {
    NSResponder *responder = self.databaseController.window.firstResponder;
    if (responder == tracksTableView) {
        [self showTrackInFinder: self];
    } else if (responder == albumsCollectionView) {
        [self showAlbumInFinder: self];
    } else if (responder == artistsTableView) {
        [self showArtistInFinder: self];
    }
}


- (IBAction)mergeArtists:(id)sender {
    NSIndexSet *indexSet = [artistsTableView selectedRowIndexes];
    if(indexSet && [indexSet count]) {
        
        
        NSArray *artists = [[artistsController arrangedObjects] objectsAtIndexes:[artistsTableView selectedRowIndexes]];
        
        [mergeArtistsController setArtists:artists];
        [mergeArtistsController openSheet:sender];  
    }
}


- (void)showTrackInLibrary:(SBTrack*)track {
    [artistsController setSelectedObjects: @[track.album.artist]];
    [artistsTableView scrollRowToVisible: [artistsTableView selectedRow]];
    [albumsController setSelectedObjects: @[track.album]];
    [albumsCollectionView scrollToItemsInIndices: albumsController.selectionIndexes scrollPosition: NSCollectionViewScrollPositionCenteredVertically];
    [tracksController setSelectedObjects: @[track]];
    [tracksTableView scrollRowToVisible: [tracksTableView selectedRow]];
}


- (void)showAlbumInLibrary:(SBAlbum*)album {
    // HACK: We're called when the content of the controller is empty.
    // As such, we can't set it until it's loaded.
    // For some reason, the server library controller is loaded early enough.
    // I'm guessing that's because the bindings in the nib set content explicitly,
    // whereas here it's implied through the MOC.
    // This means we'll just keep trying until we give up.
    // It means the first album will flash for a bit until we're ready.
    // Avoid getting stuck in a loop. The fact it's static doesn't matter,
    // as we only care about the initial case.
    static int tries = 10;
    if ((artistsController.content == nil  || ((NSArray*)artistsController.content).count < 1) && tries-- > 0) {
        [self performSelector: @selector(showAlbumInLibrary:) withObject: album afterDelay: 0.1];
        return;
    }
    [artistsController setSelectedObjects: @[album.artist]];
    [artistsTableView scrollRowToVisible: [artistsTableView selectedRow]];
    [albumsController setSelectedObjects: @[album]];
    [albumsCollectionView scrollToItemsInIndices: albumsController.selectionIndexes scrollPosition: NSCollectionViewScrollPositionCenteredVertically];
}


- (void)showArtistInLibrary:(SBArtist*)artist {
    [artistsController setSelectedObjects: @[artist]];
    [artistsTableView scrollRowToVisible: [artistsTableView selectedRow]];
}


- (IBAction)createNewLocalPlaylistWithSelectedTracks:(id)sender {
    NSInteger selectedRow = [tracksTableView selectedRow];
    
    if(selectedRow == -1) {
        return;
    }
    
    [self createLocalPlaylistWithSelected: tracksController.arrangedObjects selectedIndices: tracksTableView.selectedRowIndexes databaseController: self.databaseController];
}




#pragma mark -
#pragma mark NSAlert Sheet support


- (void)removeTrackAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSAlertSecondButtonReturn) {
        return;
    }
    NSIndexSet *selectedRows = [tracksTableView selectedRowIndexes];
    NSMutableArray *tracksToDelete = [NSMutableArray arrayWithCapacity: [selectedRows count]];
    [selectedRows enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
        SBTrack *selectedTrack = [[tracksController arrangedObjects] objectAtIndex: idx];
        [tracksToDelete addObject: selectedTrack];
    }];
    BOOL deleteFile = returnCode == NSAlertThirdButtonReturn;
    [tracksToDelete enumerateObjectsUsingBlock:^(SBTrack*  _Nonnull selectedTrack, NSUInteger idx, BOOL * _Nonnull stop) {
        NSError *error = nil;
        
        NSString *trackPath = selectedTrack.path;
        if (deleteFile && ![[NSFileManager defaultManager] removeItemAtPath:trackPath error:&error]) {
            [NSApp presentError:error];
        }
        
        // remove from context
        [self.managedObjectContext deleteObject:selectedTrack];
    }];
    [self.managedObjectContext processPendingChanges];
    [self.managedObjectContext save:nil];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey: @"LastViewedResource"];
}

- (void)removeAlbumAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSAlertSecondButtonReturn) {
        return;
    }
    NSIndexSet *selectedRows = [albumsCollectionView selectionIndexes];
    NSMutableArray *albumsToDelete = [NSMutableArray arrayWithCapacity: [selectedRows count]];
    [selectedRows enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
        SBAlbum *selectedAlbum = [[albumsController arrangedObjects] objectAtIndex: idx];
        [albumsToDelete addObject: selectedAlbum];
    }];
    BOOL deleteFile = returnCode == NSAlertThirdButtonReturn;
    [albumsToDelete enumerateObjectsUsingBlock:^(SBAlbum*  _Nonnull selectedAlbum, NSUInteger idx, BOOL * _Nonnull stop) {
        NSError *error = nil;
        
        NSString *trackPath = selectedAlbum.path;
        if (deleteFile && ![[NSFileManager defaultManager] removeItemAtPath:trackPath error:&error]) {
            [NSApp presentError:error];
        }
        
        // XXX: remove children?
        [self.managedObjectContext deleteObject:selectedAlbum];
    }];
    [self.managedObjectContext processPendingChanges];
    [self.managedObjectContext save:nil];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey: @"LastViewedResource"];
}

- (void)removeArtistAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSAlertSecondButtonReturn) {
        return;
    }
    NSIndexSet *selectedRows = [artistsTableView selectedRowIndexes];
    NSMutableArray *artistsToDelete = [NSMutableArray arrayWithCapacity: [selectedRows count]];
    [selectedRows enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
        SBArtist *selectedArtist = [[artistsController arrangedObjects] objectAtIndex: idx];
        [artistsToDelete addObject: selectedArtist];
    }];
    BOOL deleteFile = returnCode == NSAlertThirdButtonReturn;
    [artistsToDelete enumerateObjectsUsingBlock:^(SBArtist*  _Nonnull selectedArtist, NSUInteger idx, BOOL * _Nonnull stop) {
        NSError *error = nil;
        
        NSString *artistPath = selectedArtist.path;
        if (deleteFile && ![[NSFileManager defaultManager] removeItemAtPath:artistPath error:&error]) {
            [NSApp presentError:error];
        }
        
        // XXX: remove children?
        [self.managedObjectContext deleteObject:selectedArtist];
    }];
    [self.managedObjectContext processPendingChanges];
    [self.managedObjectContext save:nil];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey: @"LastViewedResource"];
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





#pragma mark -
#pragma mark Tracks NSTableView Delegate (Tracks Drag & Drop)

- (id<NSPasteboardWriting>)tableView:(NSTableView *)tableView pasteboardWriterForRow:(NSInteger)row {
    if (tableView == tracksTableView) {
        SBTrack *track = tracksController.arrangedObjects[row];
        return [[SBLibraryItemPasteboardWriter alloc] initWithItem: track index: row];
    }
    return nil;
}


#pragma mark -
#pragma mark NSTableView Sort Descriptor Override


- (void)tableView:(NSTableView *)tableView didClickTableColumn:(NSTableColumn *)tableColumn {
    if (tableView == tracksTableView && tableColumn == tableView.tableColumns[0]) {
        // Make sure we're using the sort order for disc then track for track column
        // We have to build a new array because NSTableView appends.
        BOOL asc = (tracksController.sortDescriptors[0].ascending);
        NSSortDescriptor *trackNumberDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"trackNumber" ascending: !asc];
        NSSortDescriptor *discNumberDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"discNumber" ascending: !asc];
        tracksController.sortDescriptors = @[discNumberDescriptor, trackNumberDescriptor];
    }
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


#pragma mark - NSCollectionView Data Source

- (NSInteger)collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [albumsController.arrangedObjects count];
}

- (NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath {
    SBAlbum *album = albumsController.arrangedObjects[indexPath.item];
    SBAlbumViewItem *item = [albumsCollectionView makeItemWithIdentifier: @"SBAlbumViewItem" forIndexPath: indexPath];
    item.representedObject = album;
    return item;
}

- (void)collectionView:(NSCollectionView *)collectionView didDeselectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths {
    // we only have a single selection
    [albumsController setSelectionIndexes: [[NSIndexSet alloc] init]];
}

- (void)collectionView:(NSCollectionView *)collectionView didSelectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths {
    NSInteger index = indexPaths.anyObject.item;
    [albumsController setSelectionIndex: index];
}

- (BOOL)collectionView:(NSCollectionView *)collectionView canDragItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths withEvent:(NSEvent *)event {
    return YES;
}

- (id<NSPasteboardWriting>)collectionView:(NSCollectionView *)collectionView pasteboardWriterForItemAtIndexPath:(NSIndexPath *)indexPath {
    SBAlbum *album = [[albumsController arrangedObjects] objectAtIndex: indexPath.item];
    NSArray<SBTrack*>* tracks = [album.tracks sortedArrayUsingDescriptors: tracksController.sortDescriptors];
    return [[SBLibraryPasteboardWriter alloc] initWithItems: tracks];
}

#pragma mark -
#pragma mark NSSplitViewDelegate

- (BOOL)splitView:(NSSplitView *)splitView shouldAdjustSizeOfSubview:(NSView *)view {
    if (splitView == artistSplitView) {
        return view != splitView.subviews.firstObject;
    }
    return YES;
}


#pragma mark -
#pragma mark UI Validator

- (BOOL)validateUserInterfaceItem: (id<NSValidatedUserInterfaceItem>) item {
    SEL action = [item action];
    
    NSInteger artistsSelected = artistsTableView.selectedRowIndexes.count;
    NSInteger albumSelected = albumsCollectionView.selectionIndexes.count;
    NSInteger tracksSelected = tracksTableView.selectedRowIndexes.count;
    
    NSResponder *responder = self.databaseController.window.firstResponder;
    BOOL artistsActive = responder == artistsTableView;
    
    if (action == @selector(mergeArtists:)) {
        return artistsSelected > 1 && artistsActive;
    }
    
    if (action == @selector(delete:)) {
        return artistsSelected > 0 || albumSelected > 0 || tracksSelected > 0;
    }
    
    if (action == @selector(removeArtist:)) {
        return artistsSelected > 0;
    }
    
    if (action == @selector(removeAlbum:)) {
        return albumSelected > 0;
    }
    
    if (action == @selector(removeTrack:)) {
        return tracksSelected > 0;
    }
    
    if (action == @selector(showSelectedInLibrary:)) {
        // We're already in the library, so it doesn't make sense to show this...
        return NO;
    }

    return [super validateUserInterfaceItem: item];
}



@end
