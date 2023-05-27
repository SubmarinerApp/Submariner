//
//  SBSubsonicMessage.m
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

#import "SBAppDelegate.h"
#import "SBSubsonicParsingOperation.h"
#import "SBClientController.h"


#import "NSManagedObjectContext+Fetch.h"

#import "Submariner-Swift.h"


NSString *SBSubsonicConnectionFailedNotification        = @"SBSubsonicConnectionFailedNotification";
NSString *SBSubsonicConnectionSucceededNotification     = @"SBSubsonicConnectionSucceededNotification";
NSString *SBSubsonicIndexesUpdatedNotification          = @"SBSubsonicIndexesUpdatedNotification";
NSString *SBSubsonicAlbumsUpdatedNotification           = @"SBSubsonicAlbumsUpdatedNotification";
NSString *SBSubsonicTracksUpdatedNotification           = @"SBSubsonicTracksUpdatedNotification";
NSString *SBSubsonicCoversUpdatedNotification           = @"SBSubsonicCoversUpdatedNotification";
NSString *SBSubsonicPlaylistsUpdatedNotification        = @"SBSubsonicPlaylistsUpdatedNotification";
NSString *SBSubsonicPlaylistUpdatedNotification         = @"SBSubsonicPlaylistUpdatedNotification";
NSString *SBSubsonicChatMessageAddedNotification        = @"SBSubsonicChatMessageAddedNotification";
NSString *SBSubsonicNowPlayingUpdatedNotification       = @"SBSubsonicNowPlayingUpdatedNotification";
NSString *SBSubsonicUserInfoUpdatedNotification         = @"SBSubsonicUserInfoUpdatedNotification";
NSString *SBSubsonicPlaylistsCreatedNotification        = @"SBSubsonicPlaylistsCreatedNotification";
NSString *SBSubsonicCacheDownloadStartedNotification    = @"SBSubsonicCacheDownloadStartedNotification";
NSString *SBSubsonicSearchResultUpdatedNotification     = @"SBSubsonicSearchResultUpdatedNotification";
NSString *SBSubsonicPodcastsUpdatedNotification         = @"SBSubsonicPodcastsUpdatedNotification";


@interface SBSubsonicParsingOperation (Private)

- (SBGroup *)createGroupWithAttribute:(NSDictionary *)attributeDict;
- (SBArtist *)createArtistWithAttribute:(NSDictionary *)attributeDict;
- (SBAlbum *)createAlbumWithAttribute:(NSDictionary *)attributeDict;
- (SBTrack *)createTrackWithAttribute:(NSDictionary *)attributeDict;
- (SBCover *)createCoverWithAttribute:(NSDictionary *)attributeDict;
- (SBPlaylist *)createPlaylistWithAttribute:(NSDictionary *)attributeDict;
- (SBNowPlaying *)createNowPlayingWithAttribute:(NSDictionary *)attributeDict;
- (SBPodcast *)createPodcastWithAttribute:(NSDictionary *)attributeDict;
- (SBEpisode *)createEpisodeWithAttribute:(NSDictionary *)attributeDict;

- (SBGroup *)fetchGroupWithName:(NSString *)groupName;
- (SBArtist *)fetchArtistWithID:(NSString *)artistID orName:(NSString *)artistName;
- (SBAlbum *)fetchAlbumWithID:(NSString *)albumID orName:(NSString *)albumName forArtist:(SBArtist *)artist;
- (SBTrack *)fetchTrackWithID:(NSString *)trackID orTitle:(NSString *)trackTitle forAlbum:(SBAlbum *)album;
- (SBPlaylist *)fetchPlaylistWithID:(NSString *)playlistID orName:(NSString *)playlistName;
- (SBCover *)fetchCoverWithName:(NSString *)coverID;
- (SBSection *)fetchSectionWithName:(NSString *)sectionName;
- (SBPodcast *)fetchPodcastWithID:(NSString *)channelID;
- (SBEpisode *)fetchEpisodeWithID:(NSString *)episodeID;

@end




@implementation SBSubsonicParsingOperation



@synthesize currentArtist;
@synthesize currentAlbum;
@synthesize currentCoverID;
@synthesize currentPlaylist;
@synthesize currentSearch;
@synthesize currentPodcast;



#pragma mark -
#pragma mark SBParsingOperation

- (id)initWithManagedObjectContext:(NSManagedObjectContext*)mainContext 
                            client:(SBClientController *)client
                       requestType:(SBSubsonicRequestType)type
                            server:(SBServerID *)objectID
                               xml:(NSData *)xml
                          mimeType:(NSString *)mimeType
{
    self = [super initWithManagedObjectContext:mainContext];
    if (self) {
        // Initialization code here.
        clientController    = client;
        serverID            = objectID;
        xmlData             = xml;
        MIMEType            = mimeType;
        nc                  = [NSNotificationCenter defaultCenter];

        requestType         = type;
        numberOfChildrens   = 0;
        playlistIndex       = 0;
    }
    
    return self;
}



#pragma mark -
#pragma mark NSOperation

- (void)main {
    @autoreleasepool {
    
        @try {
            server = (SBServer *)[[self threadedContext] objectWithID:serverID];
            
            @synchronized(server) {   
                
                // if xml, parse
                // Navidrome uses application/xml, Subsonic uses text/xml
                if([MIMEType containsString: @"xml"]) {
                    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:xmlData];
                    [parser setDelegate:self];
                    [parser parse];
                    
                    // if data, cover, stream...
                } else if ([MIMEType hasPrefix: @"image/"]) {
                    if(requestType == SBSubsonicRequestGetCoverArt) {
                        // build paths
                        NSString *coversDir = [[[SBAppDelegate sharedInstance] coverDirectory] stringByAppendingPathComponent:server.resourceName];
                        
                        // check cover dir
                        if(![[NSFileManager defaultManager] fileExistsAtPath:coversDir])
                            [[NSFileManager defaultManager] createDirectoryAtPath:coversDir 
                                                      withIntermediateDirectories:YES 
                                                                       attributes:nil 
                                                                            error:nil];
                        
                        // write cover image on the disk
                        NSString *filePath = nil;
                        NSString *fileName = nil;
                        // trust what subsonic returns, instead of looking at contents
                        // but if we don't have any, what usually gets attached in ID3 is JPEG, AFAIK
                        UTType *fileType = [UTType typeWithMIMEType: MIMEType] ?: UTTypeJPEG;
                        NSString *fileExtension = [fileType preferredFilenameExtension];
                        fileName = [NSString stringWithFormat:@"%@.%@", currentCoverID, fileExtension];
                        
                        if (fileName != nil) {
                            filePath = [coversDir stringByAppendingPathComponent: fileName];
                            [xmlData writeToFile:filePath atomically:YES];
                        }
                        
                        // fetch cover
                        SBCover *cover = [self fetchCoverWithName:currentCoverID];
                        
                        // add image path to cover object
                        if(cover != nil && fileName != nil) {
                            // use the relative path when possible
                            [cover setImagePath: fileName];
                        }
                        
                        [self saveThreadedContext];
                        [[NSNotificationCenter defaultCenter] postNotificationName:SBSubsonicCoversUpdatedNotification object:nil];
                    
                    }
                }
            }
            
        }
        @catch (NSException *exception) {
            NSLog(@"EXCEPTION : %@ in %s, %@, %@", exception, __PRETTY_FUNCTION__, [exception reason], [exception userInfo]);
        }
        @finally {
            [self finish];
            [self saveThreadedContext];
        }
    
    
    }
}




#pragma mark -
#pragma mark XML Elements

- (void)parseElementSubsonicResponse: (NSDictionary<NSString*,NSString*> *)attributeDict {
    NSString *status = attributeDict[@"status"];
    if ([status isEqualToString: @"ok"]) {
        NSString *apiVersion = [attributeDict valueForKey:@"version"];
        [server setApiVersion:apiVersion];
        // The end of document method will send the ping notification.
    }
    // The error element will send the notification instead.
}

- (void)parseElementError: (NSDictionary<NSString*,NSString*> *)attributeDict {
#if DEBUG
    NSLog(@"ERROR : %@", attributeDict);
#endif
    [nc postNotificationName:SBSubsonicConnectionFailedNotification object:attributeDict];
}

- (void)parseElementIndexes: (NSDictionary<NSString*,NSString*> *)attributeDict {
    NSString *timestamp = [attributeDict valueForKey:@"lastModified"];
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:[timestamp doubleValue]];
    [server setLastIndexesDate:date];
}

- (void)parseElementIndex: (NSDictionary<NSString*,NSString*> *)attributeDict {
    NSString *indexName = [attributeDict valueForKey:@"name"];
    if(indexName) {
        // fetch for existing groups
        SBGroup *group = [self fetchGroupWithName:indexName];
        if(group == nil) {
            group = [self createGroupWithAttribute:attributeDict];
#if DEBUG
            NSLog(@"Create new index group : %@", group.itemName);
#endif
            [server addIndexesObject:group];
            [group setServer:server];
        }
    }
}

- (void)parseElementArtist: (NSDictionary<NSString*,NSString*> *)attributeDict {
    // fetch for artists
    SBArtist *newArtist = [self fetchArtistWithID:[attributeDict valueForKey:@"id"] orName:nil];
    
    if(newArtist == nil) {
#if DEBUG
        NSLog(@"Create new artist : %@", [attributeDict valueForKey:@"name"]);
#endif
        // if artist doesn't exists create it
        newArtist = [self createArtistWithAttribute:attributeDict];
        [newArtist setServer:server];
        [server addIndexesObject:newArtist];
    }
}

- (void)parseElementDirectory: (NSDictionary<NSString*,NSString*> *)attributeDict {
    // get albums
    if(requestType == SBSubsonicRequestGetAlbumDirectory) {
        
        SBArtist *parentArtist = [self fetchArtistWithID:[attributeDict valueForKey:@"id"] orName:nil];
        // try to fetch artist of album
        if(parentArtist != nil)
            currentArtist = parentArtist;
        
        // get tracks
    } else if(requestType == SBSubsonicRequestGetTrackDirectory) {
        
        SBAlbum *parentAlbum = [self fetchAlbumWithID:[attributeDict valueForKey:@"id"] orName:nil forArtist:currentArtist];
        // try to fetch artist of album
        if(parentAlbum != nil)
            currentAlbum = parentAlbum;
    }
    // theorically, album may exists already...
}

- (void)parseElementChildForAlbumDirectory: (NSDictionary<NSString*,NSString*> *)attributeDict {
    // Try not to consume an object that doesn't make sense. For now, we assume a hierarchy of
    // Artist/Album/Track.ext. Navidrome is happy to oblige us and make up a hierarchy, but
    // Subsonic doesn't guarantee it when it gives you the real FS layout.
    if (currentArtist && [attributeDict[@"isDir"] isEqualToString: @"true"]) {
        // try to fetch album
        SBAlbum *newAlbum = [self fetchAlbumWithID:[attributeDict valueForKey:@"id"] orName:nil forArtist:currentArtist];
        
        // if album not found, create it
        if(newAlbum == nil) {
#if DEBUG
            NSLog(@"Create new album : %@", [attributeDict valueForKey:@"title"]);
#endif
            
            newAlbum = [self createAlbumWithAttribute:attributeDict];
            [newAlbum setArtist:currentArtist];
            [currentArtist addAlbumsObject:newAlbum];
        }
        
        // get album covers
        if(newAlbum && [attributeDict valueForKey:@"coverArt"]) {
            SBCover *newCover = nil;
            SBCover *maybeExistingCover = [self fetchCoverWithName:[attributeDict valueForKey:@"coverArt"]];
            
            if(!newAlbum.cover && maybeExistingCover == nil) {
#if DEBUG
                NSLog(@"Create new cover");
#endif
                newCover = [self createCoverWithAttribute:attributeDict];
                [newCover setId:[attributeDict valueForKey:@"coverArt"]];
                [newCover setAlbum:newAlbum];
                [newAlbum setCover:newCover];
            } else if (!newAlbum.cover) {
                // assign the existing one to our new album
                [maybeExistingCover setAlbum:newAlbum];
                [newAlbum setCover:maybeExistingCover];
            }
            
            NSString *imagePath = newAlbum.cover.imagePath;
            if (imagePath == nil || ![[NSFileManager defaultManager] fileExistsAtPath: imagePath]) {
                if (maybeExistingCover != nil && maybeExistingCover.imagePath && [[NSFileManager defaultManager] fileExistsAtPath: maybeExistingCover.imagePath]) {
                    // this cover object is a weird dupe, patch up instead.
                    [maybeExistingCover setAlbum:newAlbum];
                    [newAlbum setCover:maybeExistingCover];
                } else {
                    [clientController getCoverWithID:[attributeDict valueForKey:@"coverArt"]];
                }
            }
        }
    }
}

- (void)parseElementChildForTrackDirectory: (NSDictionary<NSString*,NSString*> *)attributeDict {
    if (currentAlbum && [attributeDict[@"isDir"] isEqualToString: @"false"]) {
        
        // check if track exists
        SBTrack *newTrack = [self fetchTrackWithID:[attributeDict valueForKey:@"id"] orTitle:nil forAlbum:currentAlbum];
        
        // if track not found, create it
        if(newTrack == nil) {
#if DEBUG
            NSLog(@"Create new track %@ to %@", [attributeDict valueForKey:@"path"], currentAlbum.itemName);
#endif
            newTrack = [self createTrackWithAttribute:attributeDict];
            [newTrack setAlbum:currentAlbum];
            [currentAlbum addTracksObject:newTrack];
        } else {
#if DEBUG
            NSLog(@"Update existing track %@ to %@", [attributeDict valueForKey:@"path"], currentAlbum.itemName);
#endif
            // XXX: What else to set?
            // XXX: Do we need to update the local track too?
            [self updateTrackWithAttributes: newTrack attributes: attributeDict];
        }
    }
}

- (void)parseElementChild: (NSDictionary<NSString*,NSString*> *)attributeDict {
    // is the child for a track, or an album?
    if(requestType == SBSubsonicRequestGetAlbumDirectory) {
        [self parseElementChildForAlbumDirectory: attributeDict];
    } else if (requestType == SBSubsonicRequestGetTrackDirectory) {
        [self parseElementChildForTrackDirectory: attributeDict];
    }
}

- (void)parseElementAlbumList: (NSDictionary<NSString*,NSString*> *)attributeDict {
    // clear current home albums
    [server.home setAlbums:nil];
}

- (void)parseElementAlbum: (NSDictionary<NSString*,NSString*> *)attributeDict {
    // XXX: Workaround for albums giving us an album we can't properly represent in the schema.
    // If we do accept it, it'll just become nil.
    // This will need adaptation for ID3 based approaches
    // (if using ID3 endpoint, use currentArtist or artistId attrib instead)
    if ([attributeDict valueForKey: @"parent"] == nil) {
        return;
    }
    
    // check artist
    SBArtist *artist = [self fetchArtistWithID:[attributeDict valueForKey:@"parent"] orName:nil];
    
    // if no artist, create it
    if(artist == nil) {
        artist = [SBArtist insertInManagedObjectContext:[self threadedContext]];
        [artist setItemName:[attributeDict valueForKey:@"artist"]];
        [artist setId:[attributeDict valueForKey:@"parent"]];
        [artist setIsLocal:[NSNumber numberWithBool:NO]];
        
        // attach artist to library
        [server addIndexesObject:artist];
        [artist setServer:server];
    }
    
    // check albums
    SBAlbum *album = [self fetchAlbumWithID:[attributeDict valueForKey:@"id"] orName:nil forArtist:nil];
    if(album != nil) {
        
        // attach album to artist
        if(album.artist == nil) {
            [artist addAlbumsObject:album];
            [album setArtist:artist];
        }
        
        // add album to home
        [server.home addAlbumsObject:album];
        [album setHome:server.home];
        
    } else {
        // create album and add it to home
        album = [self createAlbumWithAttribute:attributeDict];
        
#if DEBUG
        NSLog(@"Create new album %@", album.itemName);
#endif
        // fetch artist
        SBArtist *artist = [self fetchArtistWithID:[attributeDict valueForKey:@"parent"] orName:nil];
        
        // attach album to artist
        if(album.artist == nil) {
            [artist addAlbumsObject:album];
            [album setArtist:artist];
        }
        
        [server.home addAlbumsObject:album];
        [album setHome:server.home];
    }
    
    
    // album cover
    if(album && [attributeDict valueForKey:@"coverArt"]) {
        SBCover *newCover = nil;
        
        if(!album.cover) {
            newCover = [self createCoverWithAttribute:attributeDict];
            [newCover setId:[attributeDict valueForKey:@"coverArt"]];
            [newCover setAlbum:album];
            [album setCover:newCover];
        }
        
        if(!album.cover.imagePath) {
            [clientController getCoverWithID:[attributeDict valueForKey:@"coverArt"]];
        }
    }
}

- (void)parseElementPlaylist: (NSDictionary<NSString*,NSString*> *)attributeDict {
    if(requestType == SBSubsonicRequestGetPlaylists) {
        
        // check if playlist exists
        SBPlaylist *newPlaylist = [self fetchPlaylistWithID:[attributeDict valueForKey:@"id"] orName:nil];
        
        // if playlist not found, create it
        if(newPlaylist == nil) {
            // XXX: Usually this is a sign that somehow the playlist got renumbered or recreated.
            // Subsonic uses an incrementing integer ID, so this is possible.
            // Should we reset the ID of the playlist if so?
#if DEBUG
            NSLog(@"Failed to find playlist by ID, trying name : %@ / %@", attributeDict[@"id"], [attributeDict valueForKey:@"name"]);
#endif
            
            // try with name
            newPlaylist = [self fetchPlaylistWithID:nil orName:[attributeDict valueForKey:@"name"]];
            
            if(!newPlaylist) {
#if DEBUG
                NSLog(@"Create new playlist : %@ / %@", attributeDict[@"id"], [attributeDict valueForKey:@"name"]);
#endif
                newPlaylist = [self createPlaylistWithAttribute:attributeDict];
            }
        }

        newPlaylist.server = server;
        [server addPlaylistsObject: newPlaylist];
    } else if(requestType == SBSubsonicRequestGetPlaylist) {
        currentPlaylist = [self fetchPlaylistWithID:[attributeDict valueForKey:@"id"] orName:nil];
//            if(currentPlaylist)
//                [currentPlaylist setTracks:nil];
    }
}

- (void)parseElementEntryForPlaylist: (NSDictionary<NSString*,NSString*> *)attributeDict {
    if(currentPlaylist) {
        // fetch requested track
        SBTrack *track = [self fetchTrackWithID:[attributeDict valueForKey:@"id"] orTitle:nil forAlbum:nil];
        
        // if track found
        if(track != nil) {
            BOOL exists = NO;
            for(SBTrack *existingTrack in currentPlaylist.tracks) {
                if(!exists && [track.id isEqualToString:existingTrack.id]) {
                    exists = YES;
                }
            }
            
            // limitation if the same track exists twice
            track.playlistIndex = [NSNumber numberWithInteger: playlistIndex++];
            
            if (!exists) {
                [currentPlaylist addTracksObject:track];
                [track setPlaylist:currentPlaylist];
            }
        // no track found
        } else {
            // create it
            track = [self createTrackWithAttribute:attributeDict];
            track.playlistIndex = [NSNumber numberWithInteger: playlistIndex++];
            [currentPlaylist addTracksObject:track];
            [track setServer:server];
            [track setPlaylist:currentPlaylist];
        }
    }
}

- (void)parseElementEntryForNowPlaying: (NSDictionary<NSString*,NSString*> *)attributeDict {
    // Ignore it if it isn't music - podcasts don't return their podcast metadata,
    // but ID3 as if they were a track in the music library. The resulting track
    // is weird and malformed.
    if (![attributeDict[@"type"] isEqualToString: @"music"])
        return;
    
    SBNowPlaying *nowPlaying = [self createNowPlayingWithAttribute:attributeDict];
    
    // check track
    SBTrack *attachedTrack = [self fetchTrackWithID:[attributeDict valueForKey:@"id"] orTitle:nil forAlbum:nil];
    if(attachedTrack == nil)
        attachedTrack = [self createTrackWithAttribute:attributeDict];
    
    [nowPlaying setTrack:attachedTrack];
    [attachedTrack setNowPlaying:nowPlaying];
    
    
    // check album
    SBAlbum *album = [self fetchAlbumWithID:[attributeDict valueForKey:@"parent"] orName:nil forArtist:nil];
    if(album == nil) {
        // create album
        album = [SBAlbum insertInManagedObjectContext:[self threadedContext]];
        [album setId:[attributeDict valueForKey:@"parent"]];
        [album setItemName:[attributeDict valueForKey:@"album"]];
        [album setIsLocal:[NSNumber numberWithBool:NO]];
        
        [album addTracksObject:attachedTrack];
        [attachedTrack setAlbum:album];
    }
    
    // check cover
    SBCover *cover = [self fetchCoverWithName:[attributeDict valueForKey:@"coverArt"]];
    
    if(cover.id == nil || [cover.id isEqualToString:@""]) {
        if(!album.cover) {
            cover = [self createCoverWithAttribute:attributeDict];
            [cover setId:[attributeDict valueForKey:@"coverArt"]];
            [cover setAlbum:album];
            [album setCover:cover];
        }

        [clientController performSelectorOnMainThread:@selector(getCoverWithID:) withObject:[attributeDict valueForKey:@"coverArt"] waitUntilDone:YES];
    }
    
    // check artist
    SBArtist *artist = [self fetchArtistWithID:nil orName:[attributeDict valueForKey:@"artist"]];
    if(artist == nil) {
        artist = [SBArtist insertInManagedObjectContext:[self threadedContext]];
        [artist setItemName:[attributeDict valueForKey:@"artist"]];
        [artist setServer:server];
        [artist setIsLocal:[NSNumber numberWithBool:NO]];
        [server addIndexesObject:artist];
    }
    
    [artist addAlbumsObject:album];
    [album setArtist:artist];
    
    [nowPlaying setServer:server];
    [server addNowPlayingsObject:nowPlaying];
}

- (void)parseElementEntry: (NSDictionary<NSString*,NSString*> *)attributeDict {
    if (requestType == SBSubsonicRequestGetPlaylist) {
        [self parseElementEntryForPlaylist: attributeDict];
    } else if (requestType == SBSubsonicRequestGetNowPlaying) {
        [self parseElementEntryForNowPlaying: attributeDict];
    }
}

- (void)parseElementSong: (NSDictionary<NSString*,NSString*> *)attributeDict {
    if(requestType == SBSubsonicRequestSearch) {
        if(self.currentSearch != nil) {
            // fetch requested track
            SBTrack *track = [self fetchTrackWithID:[attributeDict valueForKey:@"id"] orTitle:nil forAlbum:nil];
            
            // if track found
            if(track != nil) {
                BOOL exists = NO;
                for(SBTrack *existingTrack in currentPlaylist.tracks) {
                    if(!exists && [track.id isEqualToString:existingTrack.id]) {
                        exists = YES;
                    }
                }
                
                if(!exists) {
                    [self.currentSearch.tracks addObject:track];
                }
                // no track found
            } else {
                // create it
                track = [self createTrackWithAttribute:attributeDict];
                [self.currentSearch.tracks addObject:track];
                [track setServer:server];
            }
        }
    }
}

- (void)parseElementLicense: (NSDictionary<NSString*,NSString*> *)attributeDict {
    BOOL valid              = ([[attributeDict valueForKey:@"valid"] isEqualToString:@"true"]) ? YES : NO;
    NSString *licenseEmail  = [attributeDict valueForKey:@"email"];
    NSDate *licenseDate     = [(NSString*)[attributeDict valueForKey:@"date"] dateTimeFromISO];
    
    [server setIsValidLicense:[NSNumber numberWithBool:valid]];
    [server setLicenseEmail:licenseEmail];
    [server setLicenseDate:licenseDate];
}

- (void)parseElementChannel: (NSDictionary<NSString*,NSString*> *)attributeDict {
    SBPodcast *podcast = nil;
    
    // fetch podcast with ID
    podcast = [self fetchPodcastWithID:[attributeDict valueForKey:@"id"]];
    if(!podcast) {
        podcast = [self createPodcastWithAttribute:attributeDict];
    }
    
    [self setCurrentPodcast:podcast];
}

- (void)parseElementEpisode: (NSDictionary<NSString*,NSString*> *)attributeDict {
    if(self.currentPodcast) {
        SBEpisode *episode = nil;
        
        // fetch or create episode
        episode = [self fetchEpisodeWithID:[attributeDict valueForKey:@"id"]];
        if(!episode) {
            episode = [self createEpisodeWithAttribute:attributeDict];
        }
        
        // add episode if needed
        if(![self.currentPodcast.episodes containsObject:episode]) {
            [self.currentPodcast addEpisodesObject:episode];
            
        } else {
            // if status changed, replace by the new podcast
            if(![episode.episodeStatus isEqualToString:[attributeDict valueForKey:@"status"]]) {
                
                [self.currentPodcast removeEpisodesObject:episode];
                
                episode = [self createEpisodeWithAttribute:attributeDict];
                [self.currentPodcast addEpisodesObject:episode];
            }
        }
        
        // get the attached track
        NSString *albumID = [attributeDict valueForKey:@"streamId"];
        SBTrack *track = [self fetchTrackWithID:albumID orTitle:nil forAlbum:nil];
        if(!track) {
            [clientController getTracksForAlbumID:[attributeDict valueForKey:@"parent"]];
        } else {
            [episode setTrack:track];
        }
        
        // episode cover
//            if([attributeDict valueForKey:@"coverArt"]) {
//                SBCover *newCover = nil;
//
//                newCover = [self fetchCoverWithName:[attributeDict valueForKey:@"coverArt"]];
//                if(!newCover) {
//                    newCover = [self createCoverWithAttribute:attributeDict];
//                    [newCover setId:[attributeDict valueForKey:@"coverArt"]];
//                }
//
//                if(!episode.cover) {
//                    [newCover setTrack:episode];
//                    [episode setCover:newCover];
//                }
//
//                if(!episode.cover.imagePath) {
//                    [clientController getCoverWithID:[attributeDict valueForKey:@"coverArt"]];
//                }
//            }
        
        // add track to server
        [episode setServer:server];
    }
}


#pragma mark -
#pragma mark NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary<NSString*,NSString*> *)attributeDict {
    numberOfChildrens++;
    // This has been heavily refactored.
    if ([elementName isEqualToString:@"subsonic-response"]) {
        // not counting ourself
        numberOfChildrens--;
        [self parseElementSubsonicResponse: attributeDict];
    } else if ([elementName isEqualToString:@"error"]) {
        [self parseElementError: attributeDict];
    } else if ([elementName isEqualToString:@"indexes"]) {
        [self parseElementIndexes: attributeDict];
    } else if ([elementName isEqualToString:@"index"]) { // build group index
        [self parseElementIndex: attributeDict];
    } else if ([elementName isEqualToString:@"artist"]) { // build artist index
        [self parseElementArtist: attributeDict];
    } else if ([elementName isEqualToString:@"directory"]) { // check directory
        [self parseElementDirectory: attributeDict];
    } else if ([elementName isEqualToString:@"child"]) { // check child item
        [self parseElementChild: attributeDict];
    } else if ([elementName isEqualToString:@"albumList"]) { // get albums list (Home)
        [self parseElementAlbumList: attributeDict];
    } else if ([elementName isEqualToString:@"album"]) { // get album entries
        [self parseElementAlbum: attributeDict];
    } else if ([elementName isEqualToString:@"playlists"]) {
        // nothing anymore
    } else if ([elementName isEqualToString:@"playlist"]) {
        [self parseElementPlaylist: attributeDict];
    } else if ([elementName isEqualToString:@"entry"]) { // check playlist/now playing entries
        [self parseElementEntry: attributeDict];
    } else if ([elementName isEqualToString:@"chatMessage"]) {
        NSLog(@"Chat is no longer supported.");
    } else if ([elementName isEqualToString:@"user"]) {
        [nc postNotificationName:SBSubsonicUserInfoUpdatedNotification object:attributeDict];
    } else if ([elementName isEqualToString:@"song"]) { // check for search2 result (song parsing)
        [self parseElementSong: attributeDict];
    } else if ([elementName isEqualToString:@"license"]) { // get license result
        [self parseElementLicense: attributeDict];
    } else if ([elementName isEqualToString:@"channel"]) { // podcasts
        [self parseElementChannel: attributeDict];
    } else if ([elementName isEqualToString:@"episode"]) { // podcast episodes
        [self parseElementEpisode: attributeDict];
    } else if ([elementName isEqualToString:@"nowPlaying"]) {
        // nothing
    } else {
        NSLog(@"An unknown element was encountered parsing, and ignored. <%@ %@>", elementName, attributeDict);
    }
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    if([elementName isEqualToString:@"channel"]) {
        if(currentPodcast) {
            currentPodcast = nil;
        }
    }
    
    else if([elementName isEqualToString:@"playlist"]) {
        playlistIndex = 0;
    }
    
}

- (void)parserDidEndDocument:(NSXMLParser *)parser {
    
    [[self threadedContext] processPendingChanges];
    [self saveThreadedContext];
    
    if(requestType == SBSubsonicRequestPing) {
        if(numberOfChildrens == 0) {
            // connection succeeded
            [nc postNotificationName:SBSubsonicConnectionSucceededNotification object:serverID];
        }
    } else if(requestType == SBSubsonicRequestDeletePlaylist) {
        // reload playlists on delete
        [nc postNotificationName:SBSubsonicPlaylistsUpdatedNotification object:serverID];
        
    } else if(requestType == SBSubsonicRequestCreatePlaylist) {
        // reload playlists on create
        [nc postNotificationName:SBSubsonicPlaylistsCreatedNotification object:serverID];
        
    } else if(requestType == SBSubsonicRequestGetIndexes) {
        // reload indexes
        [nc postNotificationName:SBSubsonicIndexesUpdatedNotification object:serverID];
        
    } else if(requestType == SBSubsonicRequestGetAlbumDirectory) {
        [nc postNotificationName:SBSubsonicAlbumsUpdatedNotification object:serverID];
        
    } else if(requestType == SBSubsonicRequestGetTrackDirectory) {
        [nc postNotificationName:SBSubsonicTracksUpdatedNotification object:serverID];
        
    } else if(requestType == SBSubsonicRequestGetPlaylists) {
        [nc postNotificationName:SBSubsonicPlaylistsUpdatedNotification object:serverID];
    } else if(requestType == SBSubsonicRequestGetPlaylist) {

        if(currentPlaylist) {
            currentPlaylist = nil;
        }
    } else if (requestType == SBSubsonicRequestGetNowPlaying) {
        [nc postNotificationName:SBSubsonicNowPlayingUpdatedNotification object:serverID];
        
    } else if (requestType == SBSubsonicRequestSearch) {
        NSLog(@"SBSubsonicSearchResultUpdatedNotification");
        [nc postNotificationName:SBSubsonicSearchResultUpdatedNotification object:currentSearch];
        
    } else if (requestType == SBSubsonicRequestGetPodcasts) {
        [nc postNotificationName:SBSubsonicPodcastsUpdatedNotification object:serverID];
    }
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSApp presentError: parseError];
    });
}







#pragma mark -
#pragma mark Create Core Data Objects

- (SBGroup *)createGroupWithAttribute:(NSDictionary *)attributeDict {
    SBGroup *newGroup = [SBGroup insertInManagedObjectContext:[self threadedContext]];
    if([attributeDict valueForKey:@"name"])
        [newGroup setItemName:[attributeDict valueForKey:@"name"]];
    
    return newGroup;
}


- (SBArtist *)createArtistWithAttribute:(NSDictionary *)attributeDict {
    SBArtist *newArtist = [SBArtist insertInManagedObjectContext:[self threadedContext]];
    if([attributeDict valueForKey:@"name"])
        [newArtist setItemName:[attributeDict valueForKey:@"name"]];
    
    if([attributeDict valueForKey:@"artist"])
        [newArtist setItemName:[attributeDict valueForKey:@"artist"]];
    
    if([attributeDict valueForKey:@"id"])
        [newArtist setId:[attributeDict valueForKey:@"id"]];
    
    [newArtist setIsLocal:[NSNumber numberWithBool:NO]];
    
    return newArtist;
}


- (SBAlbum *)createAlbumWithAttribute:(NSDictionary *)attributeDict {
    SBAlbum *newAlbum = [SBAlbum insertInManagedObjectContext:[self threadedContext]];
    
    if([attributeDict valueForKey:@"id"])
        [newAlbum setId:[attributeDict valueForKey:@"id"]];
    
    if([attributeDict valueForKey:@"title"])
        [newAlbum setItemName:[attributeDict valueForKey:@"title"]];
    
    // prepare cover
    if(newAlbum.cover == nil || newAlbum.cover.imagePath == nil || ![[NSFileManager defaultManager] fileExistsAtPath:newAlbum.cover.imagePath]) {
        NSLog(@"no cover");
        newAlbum.cover = [self createCoverWithAttribute:attributeDict];
    } else {
        NSLog(@"yes cover");
    }
    [newAlbum setIsLocal:[NSNumber numberWithBool:NO]];
    
    return newAlbum;
}

- (void) updateTrackWithAttributes:(SBTrack*)newTrack attributes:(NSDictionary*)attributeDict {
    if([attributeDict valueForKey:@"title"])
        [newTrack setItemName:[attributeDict valueForKey:@"title"]];
    if([attributeDict valueForKey:@"artist"])
        [newTrack setArtistName:[attributeDict valueForKey:@"artist"]];
    if([attributeDict valueForKey:@"album"])
        [newTrack setAlbumName:[attributeDict valueForKey:@"album"]];
    if([attributeDict valueForKey:@"track"])
        [newTrack setTrackNumber:[NSNumber numberWithInt:[[attributeDict valueForKey:@"track"] intValue]]];
    if([attributeDict valueForKey:@"discNumber"])
        [newTrack setDiscNumber:[NSNumber numberWithInt:[[attributeDict valueForKey:@"discNumber"] intValue]]];
    if([attributeDict valueForKey:@"year"])
        [newTrack setYear:[NSNumber numberWithInt:[[attributeDict valueForKey:@"year"] intValue]]];
    if([attributeDict valueForKey:@"genre"])
        [newTrack setGenre:[attributeDict valueForKey:@"genre"]];
    if([attributeDict valueForKey:@"size"])
        [newTrack setSize:[NSNumber numberWithInt:[[attributeDict valueForKey:@"size"] intValue]]];
    if([attributeDict valueForKey:@"contentType"])
        [newTrack setContentType:[attributeDict valueForKey:@"contentType"]];
    if([attributeDict valueForKey:@"contentSuffix"])
        [newTrack setContentSuffix:[attributeDict valueForKey:@"contentSuffix"]];
    if([attributeDict valueForKey:@"transcodedContentType"])
        [newTrack setTranscodedType:[attributeDict valueForKey:@"transcodedContentType"]];
    if([attributeDict valueForKey:@"transcodedSuffix"])
        [newTrack setTranscodeSuffix:[attributeDict valueForKey:@"transcodedSuffix"]];
    if([attributeDict valueForKey:@"duration"])
        [newTrack setDuration:[NSNumber numberWithInt:[[attributeDict valueForKey:@"duration"] intValue]]];
    if([attributeDict valueForKey:@"bitRate"])
        [newTrack setBitRate:[NSNumber numberWithInt:[[attributeDict valueForKey:@"bitRate"] intValue]]];
    if([attributeDict valueForKey:@"path"])
        [newTrack setPath:[attributeDict valueForKey:@"path"]];
}

- (SBTrack *)createTrackWithAttribute:(NSDictionary *)attributeDict {
    SBTrack *newTrack = [SBTrack insertInManagedObjectContext:[self threadedContext]];
    [newTrack setId:[attributeDict valueForKey:@"id"]];
    [newTrack setIsLocal:[NSNumber numberWithBool:NO]];
    [newTrack setServer:server];
    [server addTracksObject:newTrack];
    
    [self updateTrackWithAttributes: newTrack attributes: attributeDict];
        
    return newTrack;
}

- (SBCover *)createCoverWithAttribute:(NSDictionary *)attributeDict {
    SBCover *newCover = [SBCover insertInManagedObjectContext:[self threadedContext]];
    
    if([attributeDict valueForKey:@"coverArt"])
        [newCover setId:[attributeDict valueForKey:@"coverArt"]];
    
    return newCover;
}


- (SBPlaylist *)createPlaylistWithAttribute:(NSDictionary *)attributeDict {
    SBPlaylist * newPlaylist = [SBPlaylist insertInManagedObjectContext:[self threadedContext]];
    
    if([attributeDict valueForKey:@"id"])
        [newPlaylist setId:[attributeDict valueForKey:@"id"]];
    if([attributeDict valueForKey:@"name"])
        [newPlaylist setResourceName:[attributeDict valueForKey:@"name"]];
    
    return newPlaylist;
}


- (SBNowPlaying *)createNowPlayingWithAttribute:(NSDictionary *)attributeDict {
    SBNowPlaying * nowPlaying = [SBNowPlaying insertInManagedObjectContext:[self threadedContext]];
    
    if([attributeDict valueForKey:@"username"])
        [nowPlaying setUsername:[attributeDict valueForKey:@"username"]];
    
    if([attributeDict valueForKey:@"minutesAgo"])
        [nowPlaying setMinutesAgo:[NSNumber numberWithInt:[[attributeDict valueForKey:@"minutesAgo"] intValue]]];
    
    return nowPlaying;
}


- (SBPodcast *)createPodcastWithAttribute:(NSDictionary *)attributeDict {
    NSLog(@"Create new podcast : %@", [attributeDict valueForKey:@"title"]);
    
    SBPodcast *newPodcast = [SBPodcast insertInManagedObjectContext:[self threadedContext]];
    
    [newPodcast setId:[attributeDict valueForKey:@"id"]];
    [newPodcast setIsLocal:[NSNumber numberWithBool:NO]];
    [newPodcast setServer:server];
    [server addPodcastsObject:newPodcast];
    
    if([attributeDict valueForKey:@"title"])
        [newPodcast setItemName:[attributeDict valueForKey:@"title"]];
    
    if([attributeDict valueForKey:@"description"])
        [newPodcast setChannelDescription:[attributeDict valueForKey:@"description"]];
    
    if([attributeDict valueForKey:@"status"])
        [newPodcast setChannelStatus:[attributeDict valueForKey:@"status"]];
    
    if([attributeDict valueForKey:@"url"])
        [newPodcast setChannelURL:[attributeDict valueForKey:@"url"]];
        
    if([attributeDict valueForKey:@"errorMessage"])
        [newPodcast setErrorMessage:[attributeDict valueForKey:@"errorMessage"]];
    
    if([attributeDict valueForKey:@"path"])
        [newPodcast setPath:[attributeDict valueForKey:@"path"]];
    
    return newPodcast;
}

- (SBEpisode *)createEpisodeWithAttribute:(NSDictionary *)attributeDict {
    NSLog(@"Create new episode : %@", [attributeDict valueForKey:@"description"]);
    
    SBEpisode *newEpisode = [SBEpisode insertInManagedObjectContext:[self threadedContext]];
    [newEpisode setId:[attributeDict valueForKey:@"id"]];
    [newEpisode setIsLocal:[NSNumber numberWithBool:NO]];

    if([attributeDict valueForKey:@"streamId"])
        [newEpisode setStreamID:[attributeDict valueForKey:@"streamId"]];
    
    if([attributeDict valueForKey:@"title"])
        [newEpisode setItemName:[attributeDict valueForKey:@"title"]];
    
    if([attributeDict valueForKey:@"description"])
        [newEpisode setEpisodeDescription:[attributeDict valueForKey:@"description"]];
    
    if([attributeDict valueForKey:@"status"])
        [newEpisode setEpisodeStatus:[attributeDict valueForKey:@"status"]];
    
    if([attributeDict valueForKey:@"publishDate"]) {
        [newEpisode setPublishDate: [[attributeDict valueForKey:@"publishDate"] dateTimeFromRFC3339]];
    }
    
    if([attributeDict valueForKey:@"year"])
        [newEpisode setYear:[NSNumber numberWithInt:[[attributeDict valueForKey:@"year"] intValue]]];
    
    if([attributeDict valueForKey:@"genre"])
        [newEpisode setGenre:[attributeDict valueForKey:@"genre"]];
    
    if([attributeDict valueForKey:@"size"])
        [newEpisode setSize:[NSNumber numberWithInt:[[attributeDict valueForKey:@"size"] intValue]]];
    
    if([attributeDict valueForKey:@"contentType"])
        [newEpisode setContentType:[attributeDict valueForKey:@"contentType"]];
    
    if([attributeDict valueForKey:@"suffix"])
        [newEpisode setContentSuffix:[attributeDict valueForKey:@"suffix"]];
    
    if([attributeDict valueForKey:@"duration"])
        [newEpisode setDuration:[NSNumber numberWithInt:[[attributeDict valueForKey:@"duration"] intValue]]];
    
    if([attributeDict valueForKey:@"bitRate"])
        [newEpisode setBitRate:[NSNumber numberWithInt:[[attributeDict valueForKey:@"bitRate"] intValue]]];
    
    if([attributeDict valueForKey:@"coverArt"])
        [newEpisode setCoverID:[attributeDict valueForKey:@"coverArt"]];
    
    if([attributeDict valueForKey:@"path"])
        [newEpisode setPath:[attributeDict valueForKey:@"path"]];
    
    return newEpisode;
}




#pragma mark -
#pragma mark Fetch Objects


- (SBGroup *)fetchGroupWithName:(NSString *)groupName {
    NSError *error = nil;
    NSPredicate *predicate = nil;
    
    if(groupName)
        predicate = [NSPredicate predicateWithFormat: @"(itemName == %@) && (server == %@)", groupName, server];
    
    NSArray<SBGroup*> *groups = [[self threadedContext] fetchEntitiesNammed:@"Group" withPredicate:predicate error:&error];
    if(groups && [groups count] > 0) {
        return (SBGroup *)[[self threadedContext] objectWithID:[[groups objectAtIndex:0] objectID]];
    }
    return nil;
}


- (SBArtist *)fetchArtistWithID:(NSString *)artistID orName:(NSString *)artistName {
    NSError *error = nil;
    NSPredicate *predicate = nil;
    
    if(artistID) {
        predicate = [NSPredicate predicateWithFormat: @"(id == %@) && (server == %@)", artistID, server];
    } else {
        predicate = [NSPredicate predicateWithFormat: @"(itemName == %@) && (server == %@)", artistName, server];
    }
    
    NSArray<SBArtist*> *artists = [[self threadedContext] fetchEntitiesNammed:@"Artist" withPredicate:predicate error:&error];
    if(artists && [artists count] > 0) {
        return (SBArtist *)[[self threadedContext] objectWithID:[[artists objectAtIndex:0] objectID]];
    }
    return nil;
}


- (SBAlbum *)fetchAlbumWithID:(NSString *)albumID orName:(NSString *)albumName forArtist:(SBArtist *)artist {
    NSError *error = nil;
    NSPredicate *predicate = nil;
    
    if(albumID && artist) {
        predicate = [NSPredicate predicateWithFormat: @"(id == %@) && (artist == %@)", albumID, artist];
        
    } else if(albumName && artist) {
        predicate = [NSPredicate predicateWithFormat: @"(itemName == %@) && (artist == %@)", albumName, artist];
        
    } else if(albumID && !artist) {
        predicate = [NSPredicate predicateWithFormat: @"(id == %@)", albumID];
        
    } else if(albumName && !artist) {
        predicate = [NSPredicate predicateWithFormat: @"(itemName == %@)", albumName];
    }
    
    NSArray<SBAlbum*> *albums = [[self threadedContext] fetchEntitiesNammed:@"Album" withPredicate:predicate error:&error];
    if(albums && [albums count] > 0) {
        return (SBAlbum *)[[self threadedContext] objectWithID:[[albums objectAtIndex:0] objectID]];
    }
    return nil;
}


- (SBTrack *)fetchTrackWithID:(NSString *)trackID orTitle:(NSString *)trackTitle forAlbum:(SBAlbum *)album {
    NSError *error = nil;
    NSPredicate *predicate = nil;
    
    if(album && trackID) {
        predicate = [NSPredicate predicateWithFormat: @"(id == %@) && (album == %@)", trackID, album];
        
    } else if(album && trackTitle) {
        predicate = [NSPredicate predicateWithFormat: @"(itemName == %@) && (album == %@)", trackTitle, album];
        
    } else if(!album  && trackID) {
        predicate = [NSPredicate predicateWithFormat: @"(id == %@)", trackID];
        
    } else if(!album  && trackTitle) {
        predicate = [NSPredicate predicateWithFormat: @"(itemName == %@)", trackTitle];
    }
    
    NSArray<SBTrack*> *tracks = [[self threadedContext] fetchEntitiesNammed:@"Track" withPredicate:predicate error:&error];
    if(tracks && [tracks count] > 0) {
        return (SBTrack *)[[self threadedContext] objectWithID:[[tracks objectAtIndex:0] objectID]];
    }
    return nil;
}


- (SBPlaylist *)fetchPlaylistWithID:(NSString *)playlistID orName:(NSString *)playlistName {
    NSError *error = nil;
    NSPredicate *predicate = nil;

    if(playlistID) {
        predicate = [NSPredicate predicateWithFormat:@"(id == %@) && (server == %@)", playlistID, server];
    } else {
        predicate = [NSPredicate predicateWithFormat:@"(resourceName == %@) && (server == %@)", playlistName, server];
    }
    
    NSArray<SBPlaylist*> *playlists = [[self threadedContext] fetchEntitiesNammed:@"Playlist" withPredicate:predicate error:&error];
    if(playlists && [playlists count] > 0) {
        return (SBPlaylist *)[[self threadedContext] objectWithID:[[playlists objectAtIndex:0] objectID]];
    }
    
    return nil;
}



- (SBCover *)fetchCoverWithName:(NSString *)coverID {
    NSError *error = nil;
    NSPredicate *predicate = nil;
    
    if(coverID)
        predicate = [NSPredicate predicateWithFormat: @"(id == %@)", coverID];
    
    NSArray<SBCover*> *covers = [[self threadedContext] fetchEntitiesNammed:@"Cover" withPredicate:predicate error:&error];
    if(covers && [covers count] > 0) {
        return (SBCover *)[[self threadedContext] objectWithID:[[covers objectAtIndex:0] objectID]];
    }
    return nil;
}


- (SBSection *)fetchSectionWithName:(NSString *)sectionName {
    NSError *error = nil;
    NSPredicate *predicate = nil;
    
    if(sectionName)
        predicate = [NSPredicate predicateWithFormat: @"(resourceName == %@) && (server == %@)", sectionName, server];
    
    NSArray<SBSection*> *sections = [[self threadedContext] fetchEntitiesNammed:@"Section" withPredicate:predicate error:&error];
    if(sections && [sections count] > 0) {
        return (SBSection *)[[self threadedContext] objectWithID:[[sections objectAtIndex:0] objectID]];
    }
    return nil;
}

- (SBPodcast *)fetchPodcastWithID:(NSString *)channelID {
    
    NSError *error = nil;
    NSPredicate *predicate = nil;
    
    if(channelID)
        predicate = [NSPredicate predicateWithFormat: @"(id == %@) && (server == %@)", channelID, server];
    
    NSArray<SBPodcast*> *podcasts = [[self threadedContext] fetchEntitiesNammed:@"Podcast" withPredicate:predicate error:&error];
    if(podcasts && [podcasts count] > 0) {
        return (SBPodcast *)[[self threadedContext] objectWithID:[[podcasts objectAtIndex:0] objectID]];
    }
    return nil;
}


- (SBEpisode *)fetchEpisodeWithID:(NSString *)episodeID {
    
    NSError *error = nil;
    NSPredicate *predicate = nil;
    
    if(episodeID)
        predicate = [NSPredicate predicateWithFormat: @"(id == %@) && (server == %@)", episodeID, server];
    
    NSArray<SBEpisode*> *episodes = [[self threadedContext] fetchEntitiesNammed:@"Episode" withPredicate:predicate error:&error];
    if(episodes && [episodes count] > 0) {
        return (SBEpisode *)[[self threadedContext] objectWithID:[[episodes objectAtIndex:0] objectID]];
    }
    return nil;
}

@end
