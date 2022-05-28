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


#import "_SBServer.h"
#import "SBSubsonicParsingOperation.h"

@class SBClientController;
@class SBArtist;
@class SBAlbum;

@interface SBServer : _SBServer {
    SBClientController *clientController;
    NSSet *resources;
    
    NSInteger selectedTabIndex;
}

@property (weak) NSSet *resources;
@property (readonly, strong) SBClientController *clientController;

@property (readwrite) NSInteger selectedTabIndex;


// accessors
- (NSImage *)licenseImage;


// login management
- (void)connect;
- (void)getServerLicense;
- (void)getBaseParameters: (NSMutableDictionary*)parameters;

// retrieve server data
- (void)getServerIndexes;
- (void)getAlbumsForArtist:(SBArtist *)artist;
- (void)getAlbumListForType:(SBSubsonicRequestType)type;
- (void)getTracksForAlbum:(SBAlbum *)album;
- (void)getTracksForAlbumID:(NSString *)albumID;

// playlist management
- (void)getServerPlaylists;
- (void)getPlaylistTracks:(SBPlaylist *)playlist;
- (void)createPlaylistWithName:(NSString *)playlistName tracks:(NSArray *)tracks;
- (void)updatePlaylistWithID:(NSString *)playlistID tracks:(NSArray *)tracks;
- (void)deletePlaylistWithID:(NSString *)playlistID;

// podcasts
- (void)getServerPodcasts;

// now playing
- (void)getNowPlaying;

// search
- (void)searchWithQuery:(NSString *)query;

// rating
- (void)setRating:(NSInteger)rating forID:(NSString *)anID;

@end
