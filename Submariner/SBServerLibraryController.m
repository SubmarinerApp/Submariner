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
#import "SBTableView.h"

#import "Submariner-Swift.h"




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


@synthesize artistSortDescriptor;



- (id)initWithManagedObjectContext:(NSManagedObjectContext *)context {
    self = [super initWithManagedObjectContext:context];
    if (self) {
        groupEntity = [NSEntityDescription entityForName: @"Group" inManagedObjectContext: managedObjectContext];
        
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
    
    // set initial filter, we can perhaps persist between launches by storing in the text for filter
    [self filterArtist: filterView];
    
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
    // remove subsonic observers
    [[NSUserDefaults standardUserDefaults] removeObserver: self forKeyPath: @"albumSortOrder"];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"SBSubsonicCoversUpdatedNotification" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"SBSubsonicTracksUpdatedNotification" object:nil];
    [albumsController removeObserver:self forKeyPath:@"arrangedObjects"];
    [albumsController removeObserver:self forKeyPath:@"selectedObjects"];
    [tracksController removeObserver:self forKeyPath:@"selectedObjects"];
}

- (void)loadView {
    [super loadView];
    
    // observe album covers
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(subsonicCoversUpdatedNotification:) 
                                                 name:@"SBSubsonicCoversUpdatedNotification"
                                               object:nil];
    
    // observe tracks
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(subsonicTracksUpdatedNotification:) 
                                                 name:@"SBSubsonicTracksUpdatedNotification"
                                               object:nil];
    
    // Observe album for saving. Artist isn't observed for saving because it triggers after for some reason.
    [albumsController addObserver:self
                      forKeyPath:@"arrangedObjects"
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
    } else if (object == tracksController && [keyPath isEqualToString:@"selectedObjects"] && self.view.window != nil) {
        [[NSNotificationCenter defaultCenter] postNotificationName: @"SBTrackSelectionChanged"
                                                            object: tracksController.selectedObjects];
    } else if (object == albumsController && [keyPath isEqualToString:@"arrangedObjects"]) {
        [albumsCollectionView reloadData];
        [albumsCollectionView setSelectionIndexes: albumsController.selectionIndexes];
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
    NSIndexSet *selectedAlbums = [albumsController selectionIndexes];
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
#pragma mark Notification

- (void)subsonicCoversUpdatedNotification:(NSNotification *)notification {
    [albumsCollectionView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
}

- (void)subsonicTracksUpdatedNotification:(NSNotification *)notification {
    [tracksTableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
}


#pragma mark - 
#pragma mark IBActions


- (IBAction)filterArtist:(id)sender {
    
    NSPredicate *predicate = nil;
    NSString *searchString = nil;
    
    searchString = [sender stringValue];
    
    // Including server is redundant, since the artistController dervives from server's own indexSet
    // Filter out nil ids to avoid confusing user, since only thing that can make those is i.e. playlist from index-based IDs
    // If we don't include group, we won't have the headers
    if(searchString != nil && [searchString length] > 0) {
        // We don't need to worry about filtering group names here.
        // If we do want groups, then we should reverse the search if it's a group (%@ begins with itemName)
        predicate = [NSPredicate predicateWithFormat:@"(itemName CONTAINS[cd] %@ && itemId != nil)", searchString];
        [artistsController setFilterPredicate:predicate];
    } else {
        predicate = [NSPredicate predicateWithFormat:@"(itemId != nil || entity == %@)", groupEntity];
        [artistsController setFilterPredicate:predicate];
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
    [artistsController setSelectedObjects: @[album.artist]];
    [albumsCollectionView scrollToItemsInIndices: albumsController.selectionIndexes scrollPosition: NSCollectionViewScrollPositionCenteredVertically];
    [albumsController setSelectedObjects: @[album]];
    [artistsTableView scrollRowToVisible: [artistsTableView selectedRow]];
}


- (void)showArtistInLibrary:(SBArtist*)artist {
    [artistsController setSelectedObjects: @[artist]];
    [artistsTableView scrollRowToVisible: [artistsTableView selectedRow]];
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
                [self.server getArtist:selectedArtist];
                [albumsCollectionView deselectAll: self];
            }
        }
    }
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
                    
                    [self.server setRating:rating forID:trackID];
                }
            }
        }
    }
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


#pragma mark - NSCollectionView Data Source

- (NSInteger)collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [albumsController.arrangedObjects count];
}

- (NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath {
    SBAlbum *album = albumsController.arrangedObjects[indexPath.item];
    // XXX: Insane Objective-C exception, or nonsensical lifecycle (becomes ready before the representation)
    //SBAlbumViewItem *item = [albumsCollectionView makeItemWithIdentifier: @"SBAlbumViewItem" forIndexPath: indexPath];
    SBAlbumViewItem *item = [[SBAlbumViewItem alloc] init];
    item.unowningCollectionView = collectionView;
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
    
    // get tracks
    NSInteger selectedRow = [[albumsController selectionIndexes] firstIndex];
    if(selectedRow != -1 && selectedRow < [[albumsController arrangedObjects] count]) {
        
        [tracksController setContent:nil];
        
        SBAlbum *album = [[albumsController arrangedObjects] objectAtIndex:selectedRow];
        if(album) {
            
            [self.server getAlbum: album];
            
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
    
    if (action == @selector(showSelectedInLibrary:)) {
        // We're already in the library, so it doesn't make sense to show this...
        return NO;
    }

    return [super validateUserInterfaceItem: item];
}


@end
