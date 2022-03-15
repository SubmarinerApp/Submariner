//
//  SBSubsonicMessage.h
//  Sub
//
//  Created by Rafaël Warnault on 23/05/11.
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
#import "SBOperation.h"


extern NSString *SBSubsonicConnectionFailedNotification;
extern NSString *SBSubsonicConnectionSucceededNotification;
extern NSString *SBSubsonicIndexesUpdatedNotification;
extern NSString *SBSubsonicAlbumsUpdatedNotification;
extern NSString *SBSubsonicTracksUpdatedNotification;
extern NSString *SBSubsonicCoversUpdatedNotification;
extern NSString *SBSubsonicPlaylistsUpdatedNotification;
extern NSString *SBSubsonicPlaylistUpdatedNotification;
extern NSString *SBSubsonicNowPlayingUpdatedNotification;
extern NSString *SBSubsonicUserInfoUpdatedNotification;
extern NSString *SBSubsonicPlaylistsCreatedNotification;
extern NSString *SBSubsonicCacheDownloadStartedNotification;
extern NSString *SBSubsonicSearchResultUpdatedNotification;
extern NSString *SBSubsonicPodcastsUpdatedNotification;


enum SBSubsonicRequestType {
    SBSubsonicRequestUnknow                 = -1,
    SBSubsonicRequestPing                   = 0,
    SBSubsonicRequestGetLicence             = 1,
    SBSubsonicRequestGetMusicFolders        = 2,
    SBSubsonicRequestGetIndexes             = 3,
    SBSubsonicRequestGetMusicDirectory      = 4,
    SBSubsonicRequestGetAlbumDirectory      = 5, 
    SBSubsonicRequestGetTrackDirectory      = 6, 
    SBSubsonicRequestGetCoverArt            = 7,
    SBSubsonicRequestStream                 = 8,
    SBSubsonicRequestGetPlaylists           = 9,
    SBSubsonicRequestGetAlbumListRandom     = 10,
    SBSubsonicRequestGetAlbumListNewest     = 11,
    SBSubsonicRequestGetAlbumListHighest    = 12,
    SBSubsonicRequestGetAlbumListFrequent   = 13,
    SBSubsonicRequestGetAlbumListRecent     = 14,
    SBSubsonicRequestGetPlaylist            = 15,
    SBSubsonicRequestDeletePlaylist         = 16,
    SBSubsonicRequestCreatePlaylist         = 17,
    SBSubsonicRequestGetChatMessages        = 18,
    SBSubsonicRequestAddChatMessage         = 19,
    SBSubsonicRequestGetNowPlaying          = 20,
    SBSubsonicRequestGetUser                = 21,
    SBSubsonicRequestSearch                 = 22,
    SBSubsonicRequestSetRating              = 23,
    SBSubsonicRequestGetLicense             = 24,
    SBSubsonicRequestGetPodcasts            = 25
} typedef SBSubsonicRequestType;



@class SBClientController;
@class SBServer;
@class SBServerID;
@class SBArtist;
@class SBAlbum;
@class SBPlaylist;
@class SBSearchResult;
@class SBPodcast;


@interface SBSubsonicParsingOperation : SBOperation <NSXMLParserDelegate> {
@protected
    // attribute
    NSNotificationCenter *nc;
    SBClientController *clientController;
    SBSubsonicRequestType requestType;
    SBServerID *serverID;
    SBServer *server;
    NSData *xmlData;
    
    // parsing support
    SBArtist *currentArtist;
    SBAlbum *currentAlbum;
    SBPlaylist *currentPlaylist;
    NSString *currentCoverID;
    SBSearchResult *currentSearch;
    SBPodcast *currentPodcast;
    
    // index counters
    NSInteger numberOfChildrens;
    NSInteger playlistIndex;
    
    BOOL hasUnread;
}

@property (readwrite, retain) SBArtist *currentArtist;
@property (readwrite, retain) SBAlbum  *currentAlbum;
@property (readwrite, retain) SBPlaylist *currentPlaylist;
@property (readwrite, retain) SBPodcast *currentPodcast;
@property (readwrite, retain) NSString *currentCoverID;
@property (readwrite, retain) SBSearchResult *currentSearch;

- (id)initWithManagedObjectContext:(NSManagedObjectContext*)mainContext 
                            client:(SBClientController *)client
                       requestType:(SBSubsonicRequestType)type
                            server:(SBServerID *)objectID
                               xml:(NSData *)xml;

@end
