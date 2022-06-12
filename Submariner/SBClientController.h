//
//  SBClient.h
//  Sub
//
//  Created by Rafaël Warnault on 14/05/11.
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
#import <CoreData/CoreData.h>
#import "SBSubsonicParsingOperation.h"


@protocol SBClientDelegate;
@class SBServer;
@class SBSection;
@class SBHome;
@class SBLibrary;
@class SBTrack;
@class SBPlaylist;
@class SBArtist;
@class SBArtistID;
@class SBAlbum;


@interface SBClientController : NSObject  {
@private
    NSManagedObjectContext *managedObjectContext;
    NSOperationQueue *queue;
    NSMutableDictionary *parameters;
    id<SBClientDelegate> delegate;
    
    SBServer    *server;
    SBSection   *librarySection;
    SBSection   *remotePlaylistsSection;
    SBSection   *podcastsSection;
    SBSection   *radiosSection;
    SBSection   *searchsSection;
    SBHome      *home;
    SBLibrary   *library;
    
    BOOL isConnecting;
    BOOL connected;
    NSInteger numberOfElements;
}

@property (readwrite, strong) NSManagedObjectContext *managedObjectContext;
@property (readwrite, strong) id<SBClientDelegate> delegate;
@property (readwrite, strong) NSOperationQueue *queue;
@property (readwrite, strong) SBServer *server;
@property (readwrite, strong) SBSection *librarySection;
@property (readwrite, strong) SBSection *remotePlaylistsSection;
@property (readwrite, strong) SBSection *podcastsSection;
@property (readwrite, strong) SBSection *radiosSection;
@property (readwrite, strong) SBSection *searchsSection;
@property (readwrite, strong) SBLibrary *library;
@property (readwrite, strong) SBHome *home;


@property (readwrite) BOOL connected;
@property (readwrite) BOOL isConnecting;

- (id)initWithManagedObjectContext:(NSManagedObjectContext *)context;

- (void)connectToServer:(SBServer *)aServer;
- (void)getLicense;

- (void)getIndexes;
- (void)getIndexesSince:(NSDate *)date;
- (void)getAlbumsForArtist:(SBArtist *)artist;
- (void)getAlbumListForType:(SBSubsonicRequestType)type;
- (void)getTracksForAlbumID:(NSString *)albumID;
- (void)getCoverWithID:(NSString *)coverID;

- (void)getPlaylists;
- (void)getPlaylist:(SBPlaylist *)playlist;

- (void)getPodcasts;

- (void)deletePlaylistWithID:(NSString *)playlistID;
- (void)createPlaylistWithName:(NSString *)playlistName tracks:(NSArray *)tracks;
- (void)updatePlaylistWithID:(NSString *)playlistID tracks:(NSArray *)tracks;

- (void)getNowPlaying;
- (void)getUserWithName:(NSString *)username;

- (void)search:(NSString *)query;
- (void)setRating:(NSInteger)rating forID:(NSString *)anID;
- (void)scrobble:(NSString *)anID;

@end


