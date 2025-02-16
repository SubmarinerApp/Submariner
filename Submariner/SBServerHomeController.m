//
//  SBServerHomeController.m
//  Submariner
//
//  Created by Rafaël Warnault on 08/06/11.
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

#import "SBServerHomeController.h"
#import "SBDatabaseController.h"

#import "Submariner-Swift.h"



// scope bar const
#define GROUP_LABEL				@"Label"			// string
#define GROUP_SEPARATOR			@"HasSeparator"		// BOOL as NSNumber
#define GROUP_SELECTION_MODE	@"SelectionMode"	// MGScopeBarGroupSelectionMode (int) as NSNumber
#define GROUP_ITEMS				@"Items"			// array of dictionaries, each containing the following keys:
#define ITEM_IDENTIFIER			@"Identifier"		// string
#define ITEM_NAME				@"Name"				// string




@interface SBServerHomeController ()
- (void)subsonicCoversUpdatedNotification:(NSNotification *)notification;
@end





@implementation SBServerHomeController



+ (NSString *)nibName {
    return @"ServerHome";
}


- (NSString*)title {
    return [NSString stringWithFormat: @"Albums on %@", self.server.resourceName];
}



- (id)initWithManagedObjectContext:(NSManagedObjectContext *)context {
    self = [super initWithManagedObjectContext:context];
    if (self) {
        scopeGroups = [[NSMutableArray alloc] init];
        
        shouldInfiniteScroll = NO;
        
        // XXX: Does it make sense to do a year sort for this view?
        NSSortDescriptor *albumYearDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"year" ascending:YES];
        NSSortDescriptor *albumNameDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"itemName" ascending:YES selector: @selector(caseInsensitiveCompare:)];
        albumSortDescriptor = @[albumYearDescriptor, albumNameDescriptor];
        
        NSSortDescriptor *trackNumberDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"trackNumber" ascending:YES];
        NSSortDescriptor *discNumberDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"discNumber" ascending:YES];
        trackSortDescriptor = @[discNumberDescriptor, trackNumberDescriptor];
    }
    return self;
}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self forKeyPath:@"SBSubsonicCoversUpdatedNotification"];
    [[NSNotificationCenter defaultCenter] removeObserver:self forKeyPath:@"SBSubsonicAlbumsUpdated"];
    [[NSNotificationCenter defaultCenter] removeObserver:self forKeyPath:NSViewBoundsDidChangeNotification];
    
    [[NSUserDefaults standardUserDefaults] removeObserver: self forKeyPath: @"albumSortOrder"];
    [albumsController removeObserver:self forKeyPath:@"arrangedObjects"];
    [tracksController removeObserver:self forKeyPath:@"selectedObjects"];
}

- (void)viewDidAppear {
    [super viewDidAppear];
    [[NSNotificationCenter defaultCenter] postNotificationName: @"SBTrackSelectionChanged"
                                                        object: tracksController.selectedObjects];
}


- (void)loadView {
    [super loadView];
    
    // scope bar
    NSArray *items = [NSArray arrayWithObjects:
					  [NSDictionary dictionaryWithObjectsAndKeys: 
                       @"RandomItem", ITEM_IDENTIFIER, 
                       @"Random", ITEM_NAME, nil], 
					  [NSDictionary dictionaryWithObjectsAndKeys: 
                       @"NewestItem", ITEM_IDENTIFIER, 
                       @"Newest", ITEM_NAME, nil],
                      // "highest" isn't supported by albumList2 in Subsonic or Navidrome for some reason...
//                      [NSDictionary dictionaryWithObjectsAndKeys:
//                       @"HighestItem", ITEM_IDENTIFIER,
//                       @"Highest", ITEM_NAME, nil],
                      [NSDictionary dictionaryWithObjectsAndKeys:
                       @"StarredItem", ITEM_IDENTIFIER,
                       @"Favourited", ITEM_NAME, nil],
                      [NSDictionary dictionaryWithObjectsAndKeys:
                       @"FrequentItem", ITEM_IDENTIFIER, 
                       @"Frequent", ITEM_NAME, nil],
                      [NSDictionary dictionaryWithObjectsAndKeys: 
                       @"RecentItem", ITEM_IDENTIFIER, 
                       @"Recent", ITEM_NAME, nil],
					  nil];
	
	[scopeGroups addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                            @"Browse By:", GROUP_LABEL,
                            [NSNumber numberWithBool:NO], GROUP_SEPARATOR, 
                            [NSNumber numberWithInt:MGScopeBarGroupSelectionModeRadio], GROUP_SELECTION_MODE, // single selection group.
                            items, GROUP_ITEMS, 
                            nil]];
    
    [scopeBar setSelected:YES forItem:@"RandomItem" inGroup:0];

    [scopeBar sizeToFit];
    // This will call reloadServersWithIdentifier: for us.
    [scopeBar reloadData];
    
    // observe album covers
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(subsonicCoversUpdatedNotification:) 
                                                 name:@"SBSubsonicCoversUpdatedNotification"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(subsonicAlbumsUpdatedNotification:)
                                                 name:@"SBSubsonicAlbumsUpdatedNotification"
                                               object:nil];
    
    [albumsController addObserver:self
                      forKeyPath:@"arrangedObjects"
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
    
    NSClipView *albumClipView = albumsCollectionView.enclosingScrollView.contentView;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(albumClipViewBoundsChanged:)
                                                 name:NSViewBoundsDidChangeNotification
                                               object:albumClipView];
}


- (SBAlbumListType)albumListTypeForIdentifier: (NSString*)identifier {
    if ([identifier isEqualToString:@"RandomItem"]) {
        return SBSubsonicRequestGetAlbumListRandom;
    } else if ([identifier isEqualToString:@"NewestItem"]) {
        return SBSubsonicRequestGetAlbumListNewest;
    } else if ([identifier isEqualToString:@"HighestItem"]) {
        return SBSubsonicRequestGetAlbumListHighest;
    } else if ([identifier isEqualToString:@"FrequentItem"]) {
        return SBSubsonicRequestGetAlbumListFrequent;
    } else if ([identifier isEqualToString:@"StarredItem"]) {
        return SBSubsonicRequestGetAlbumListStarred;
    } else if ([identifier isEqualToString:@"RecentItem"]) {
        return SBSubsonicRequestGetAlbumListRecent;
    }
    // fallback
    return SBSubsonicRequestGetAlbumListRandom;
}


- (SBAlbumListType)currentAlbumListType {
    NSArray *nested = scopeBar.selectedItems.firstObject;
    NSString *identifier = nested.firstObject;
    return [self albumListTypeForIdentifier:identifier];
}


- (void) reloadServersWithType: (SBAlbumListType)albumListType {
    [self.server getAlbumListForType:albumListType];
}


#pragma mark - Properties

- (NSArray<SBTrack*>*) tracks {
    return [tracksController arrangedObjects];
}


- (NSArray<SBTrack*>*) selectedTracks {
    return [tracksController selectedObjects];
}


- (NSInteger) selectedTrackRow {
    return tracksTableView.selectedRow;
}


- (NSArray<SBAlbum*>*) selectedAlbums {
    return [albumsController selectedObjects];
}


- (NSArray<id<SBStarrable>>*) selectedMusicItems {
    NSResponder *responder = self.databaseController.window.firstResponder;
    if (responder == tracksTableView) {
        return [tracksController selectedObjects];
    } else if (responder == albumsCollectionView) {
        return [albumsController selectedObjects];
    }
    return @[];
}


#pragma mark - 
#pragma mark IBActions


- (IBAction)reloadSelected: (id)sender {
    [self reloadServersWithType:[self currentAlbumListType]];
}


#pragma mark - 
#pragma mark Observers

- (void)observeValueForKeyPath:(NSString *)keyPath 
                      ofObject:(id)object 
                        change:(NSDictionary *)change 
                       context:(void *)context {
    
    if(object && [keyPath isEqualToString:@"tracks"] && [object isKindOfClass:[SBAlbum class]]) {
        
        NSSet *set = [object valueForKey:@"tracks"];
        if(set && [set count] > 0) {
            [tracksController setContent:[object valueForKey:@"tracks"]];
            [tracksTableView reloadData];
            
            [object removeObserver:self forKeyPath:@"tracks"];
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



#pragma mark - 
#pragma mark Notification

- (void)loadWhenAtBottom {
    if (!self->shouldInfiniteScroll) {
        return;
    }
    
    NSScrollView *scrollView = self->albumsCollectionView.enclosingScrollView;
    NSView *documentView = scrollView.documentView;
    NSClipView *clipView = scrollView.contentView;
    
    CGFloat verticalPosition = clipView.bounds.origin.y + clipView.bounds.size.height;
    if (verticalPosition == documentView.bounds.size.height) {
        self->shouldInfiniteScroll = NO;
        [self.server updateAlbumListForType: [self currentAlbumListType]];
    }
}

- (void)albumClipViewBoundsChanged:(NSNotification *)notification {
    [self loadWhenAtBottom];
}

- (void)subsonicAlbumsUpdatedNotification:(NSNotification *)notification {
    // No need to reload with observation, but do increment our infinite scroll state
    NSNumber *count = notification.userInfo[@"count"];
    shouldInfiniteScroll = count.intValue > 0;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self loadWhenAtBottom];
    });
}

- (void)subsonicCoversUpdatedNotification:(NSNotification *)notification {
    [albumsCollectionView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];
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
        
        SBAlbum *album = [[albumsController arrangedObjects] objectAtIndex:selectedRow];
        if(album) {
            
            // reset current tracks
            [tracksController setContent:nil];
            [self.server getAlbum: album];
            
            if ([album.tracks count] == 0) {
                // wait for new tracks
                [album addObserver:self
                        forKeyPath:@"tracks"
                           options:(NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionPrior | NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld)
                           context:NULL];
            } else {
                [tracksController setContent:album.tracks];
            }
        }
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
#pragma mark NSTableView (Drag & Drop)

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
#pragma mark MGScopeBarDelegate methods


- (NSInteger)numberOfGroupsInScopeBar:(MGScopeBar *)theScopeBar {
	return (int)[scopeGroups count];
}


- (NSArray *)scopeBar:(MGScopeBar *)theScopeBar itemIdentifiersForGroup:(NSInteger)groupNumber {
    return [[scopeGroups objectAtIndex:groupNumber] valueForKeyPath:[NSString stringWithFormat:@"%@.%@", GROUP_ITEMS, ITEM_IDENTIFIER]];
}


- (NSString *)scopeBar:(MGScopeBar *)theScopeBar labelForGroup:(NSInteger)groupNumber {
	return [[scopeGroups objectAtIndex:groupNumber] objectForKey:GROUP_LABEL];;
}


- (NSString *)scopeBar:(MGScopeBar *)theScopeBar titleOfItem:(NSString *)identifier inGroup:(NSInteger)groupNumber {
    NSArray *items = [[scopeGroups objectAtIndex:groupNumber] objectForKey:GROUP_ITEMS];
    if (items) {
        for (NSDictionary *item in items) {
            if ([[item objectForKey:ITEM_IDENTIFIER] isEqualToString:identifier]) {
                return [item objectForKey:ITEM_NAME];
                break;
            }
        }
    } 
	return nil;
}


- (MGScopeBarGroupSelectionMode)scopeBar:(MGScopeBar *)theScopeBar selectionModeForGroup:(NSInteger)groupNumber {
	return (MGScopeBarGroupSelectionMode)[[[scopeGroups objectAtIndex:groupNumber] objectForKey:GROUP_SELECTION_MODE] intValue];
}


- (NSImage *)scopeBar:(MGScopeBar *)scopeBar imageForItem:(NSString *)identifier inGroup:(NSInteger)groupNumber {
    if ([identifier isEqualToString: @"RandomItem"]) {
        return [NSImage imageWithSystemSymbolName: @"shuffle" accessibilityDescription: @"Random"];
    } else if ([identifier isEqualToString: @"NewestItem"]) {
        return [NSImage imageWithSystemSymbolName: @"wand.and.stars" accessibilityDescription: @"Random"];
    } else if ([identifier isEqualToString: @"HighestItem"]) {
        return [NSImage imageWithSystemSymbolName: @"star.fill" accessibilityDescription: @"Highest"];
    } else if ([identifier isEqualToString: @"StarredItem"]) {
        return [NSImage imageWithSystemSymbolName: @"heart.fill" accessibilityDescription: @"Favourited"];
    } else if ([identifier isEqualToString: @"FrequentItem"]) {
        return [NSImage imageWithSystemSymbolName: @"arrowshape.up" accessibilityDescription: @"Frequent"];
    } else if ([identifier isEqualToString: @"RecentItem"]) {
        return [NSImage imageWithSystemSymbolName: @"clock.arrow.circlepath" accessibilityDescription: @"Recent"];
    }
    
	return nil;
}


- (void)scopeBar:(MGScopeBar *)theScopeBar selectedStateChanged:(BOOL)selected forItem:(NSString *)identifier inGroup:(NSInteger)groupNumber {
    [albumsController setSelectionIndexes: [[NSIndexSet alloc] init]];
    
    [self reloadServersWithType:[self currentAlbumListType]];
}


@end
