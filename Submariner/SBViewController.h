//
//  SBViewController.h
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

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

// forward declare since importing is not good here
@class SBDatabaseController;
@class SBTrack, SBAlbum, SBArtist;
@protocol SBStarrable;

@interface SBViewController : NSViewController {
@protected
    NSManagedObjectContext *managedObjectContext;
    
    dispatch_once_t compensatedSplitViewToken;
    __weak NSSplitView *compensatedSplitView;
    __weak SBDatabaseController *databaseController;
}
@property (nonatomic, strong, readwrite) NSManagedObjectContext *managedObjectContext;

@property (readwrite, weak) SBDatabaseController *databaseController;

// These two have to exist for trackDoubleClick:
@property (nonatomic, strong, readonly) NSArray<SBTrack*> *tracks;
@property (readonly) NSInteger selectedTrackRow;

@property (nonatomic, strong, readonly) NSArray<SBTrack*> *selectedTracks;
@property (nonatomic, strong, readonly) NSArray<SBAlbum*> *selectedAlbums;
@property (nonatomic, strong, readonly) NSArray<SBArtist*> *selectedArtists;
@property (nonatomic, strong, readonly) NSArray<id<SBStarrable>> *selectedMusicItems;
@property (strong, readonly) NSArray<SBTrack*> *trackSortDescriptor;

+ (NSString *)nibName;
- (id)initWithManagedObjectContext:(NSManagedObjectContext *)context;

// Shared IBActions for view controllers
- (IBAction)trackDoubleClick:(id)sender;
- (IBAction)albumDoubleClick:(id)sender;
- (IBAction)playSelected:(id)sender;
- (IBAction)addArtistToTracklist:(id)sender;
- (IBAction)addAlbumToTracklist:(id)sender;
- (IBAction)addTrackToTracklist:(id)sender;
- (IBAction)addSelectedToTracklist:(id)sender;
- (IBAction)createNewLocalPlaylistWithSelectedTracks:(id)sender;
- (IBAction)downloadTrack:(id)sender;
- (IBAction)downloadAlbum:(id)sender;
- (IBAction)downloadSelected:(id)sender;
- (IBAction)showSelectedInLibrary:(id)sender;
- (IBAction)showTrackInFinder:(id)sender;
- (IBAction)showSelectedInFinder:(id)sender;

// Helper functions for library views (XXX: Is this the best place for them?)
-(void)showTracksInFinder:(NSArray<SBTrack*>*)trackList selectedIndices:(NSIndexSet*)indexSet NS_SWIFT_NAME(showTracksInFinder(_:selectedIndices:));
-(void)showTracksInFinder:(NSArray<SBTrack*>*)trackList NS_SWIFT_NAME(showTracksInFinder(_:));
-(void)downloadTracks:(NSArray<SBTrack*>*)trackList selectedIndices:(NSIndexSet*)indexSet databaseController:(SBDatabaseController*)databaseController;
-(void)downloadTracks:(NSArray<SBTrack*>*)trackList databaseController:(SBDatabaseController*)databaseController;
- (void)createLocalPlaylistWithSelected:(NSArray<SBTrack*>*)trackList selectedIndices:(NSIndexSet*)indexSet databaseController:(SBDatabaseController*)databaseController;
- (void)createLocalPlaylistWithSelected:(NSArray<SBTrack*>*)trackList databaseController:(SBDatabaseController*)databaseController;


typedef NS_OPTIONS(NSInteger, SBSelectedRowStatus) {
    SBSelectedRowNone = 0,
    SBSelectedRowDownloadable = 1,
    SBSelectedRowShowableInFinder = 2,
    SBSelectedRowFavourited = 4,
};

- (SBSelectedRowStatus) selectedRowStatus:(NSArray<SBTrack*>*)trackList selectedIndices:(NSIndexSet*)indexSet;
- (SBSelectedRowStatus) selectedRowStatus:(NSArray<SBTrack*>*)trackList;

- (NSArray<NSSortDescriptor*>*) sortDescriptorsForPreference;

@end
