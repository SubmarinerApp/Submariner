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
#import "SBServer.h"
#import "SBResource.h"
#import "SBHome.h"
#import "SBSection.h"
#import "SBLibrary.h"
#import "SBGroup.h"
#import "SBTrack.h"
#import "SBPlaylist.h"
#import "SBArtist.h"
#import "SBAlbum.h"
#import "SBCover.h"
#import "SBNowPlaying.h"
#import "SBSearchResult.h"
#import "SBPodcast.h"
#import "SBEpisode.h"


#import "NSManagedObjectContext+Fetch.h"
#import "NSURL+Parameters.h"


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





/**
 * Returns the image content-type for image raw data 
 * (JPEG, PNG, GIF or TIFF)
 * NOTE : needs to be move in a better place
 */
+ (NSString *)contentTypeForImageData:(NSData *)data {
    uint8_t c;
    [data getBytes:&c length:1];
    
    switch (c) {
        case 0xFF:
            return @"image/jpeg";
        case 0x89:
            return @"image/png";
        case 0x47:
            return @"image/gif";
        case 0x49:
        case 0x4D:
            return @"image/tiff";
    }
    return nil;
}



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
{
    self = [super initWithManagedObjectContext:mainContext];
    if (self) {
        // Initialization code here.
        clientController    = client;
        serverID            = objectID;
        xmlData             = xml;
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
            
            NSString *xmlString = [[NSString alloc] initWithData:xmlData encoding:NSUTF8StringEncoding];
            server = (SBServer *)[[self threadedContext] objectWithID:serverID];
            
            @synchronized(server) {   
                
                // if xml, parse
                if(xmlString && [xmlString rangeOfString:@"xml"].location != NSNotFound) {
                    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:xmlData];
                    [parser setDelegate:self];
                    [parser parse];
                    
                    // if data, cover, stream...
                } else {
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
                        
                        if([[SBSubsonicParsingOperation contentTypeForImageData:xmlData] isEqualToString:@"image/png"]) {
                            filePath = [coversDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.png", currentCoverID]];
                            [xmlData writeToFile:filePath atomically:YES];
                        } else if([[SBSubsonicParsingOperation contentTypeForImageData:xmlData] isEqualToString:@"image/jpeg"]) {
                            filePath = [coversDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.jpeg", currentCoverID]];
                            [xmlData writeToFile:filePath atomically:YES];
                        } else if([[SBSubsonicParsingOperation contentTypeForImageData:xmlData] isEqualToString:@"image/gif"]) {
                            filePath = [coversDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.gif", currentCoverID]];
                            [xmlData writeToFile:filePath atomically:YES];
                        } else if([[SBSubsonicParsingOperation contentTypeForImageData:xmlData] isEqualToString:@"image/tiff"]) {
                            filePath = [coversDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.tiff", currentCoverID]];
                            [xmlData writeToFile:filePath atomically:YES];
                        }
                        
                        // fetch cover
                        SBCover *cover = [self fetchCoverWithName:currentCoverID];
                        
                        // add image path to cover object
                        if(cover != nil) {  
                            [cover setImagePath:filePath]; 
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
#pragma mark NSXMLParserDelegate

- (void)parserDidStartDocument:(NSXMLParser *)parser {

}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict {
    
    if([[attributeDict objectForKey:@"status"] isEqualToString:@"failed"]) {
        // connection failed   
        [nc postNotificationName:SBSubsonicConnectionFailedNotification object:serverID];
        return;
    }
    
    // subsonic response handler
    if([elementName isEqualToString:@"subsonic-response"]) {
        if(numberOfChildrens == 0) {
            // connection succeeded
            NSString *apiVersion = [attributeDict valueForKey:@"version"];
            [server setApiVersion:apiVersion];
        }
        return;
    }
    
    // count number of subsonic-response children
    numberOfChildrens++;
    
    
    // check subsonic error
    if([elementName isEqualToString:@"error"]) {
#if DEBUG
        NSLog(@"ERROR : %@", attributeDict);
#endif
        [nc postNotificationName:SBSubsonicConnectionFailedNotification object:attributeDict];
        return;
    }
    
    
    if([elementName isEqualToString:@"indexes"]) {
        NSNumber *timestamp = [attributeDict valueForKey:@"lastModified"];
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:[timestamp doubleValue]];
        [server setLastIndexesDate:date];
    }
    
    
    // build group index
    if([elementName isEqualToString:@"index"]) {
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
                return;
            }
        }
    }
    
    // build artist index
    if([elementName isEqualToString:@"artist"]) {
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
            
            return;
        }
    }
    
    // check directory
    if([elementName isEqualToString:@"directory"]) {
        // get albums
        if(requestType == SBSubsonicRequestGetAlbumDirectory) {
            
            SBArtist *parentArtist = [self fetchArtistWithID:[attributeDict valueForKey:@"id"] orName:nil];
            // try to fetch artist of album
            if(parentArtist != nil)
                currentArtist = parentArtist;
            
            return;
            
            // get tracks   
        } else if(requestType == SBSubsonicRequestGetTrackDirectory) {
            
            SBAlbum *parentAlbum = [self fetchAlbumWithID:[attributeDict valueForKey:@"id"] orName:nil forArtist:currentArtist];
            // try to fetch artist of album
            if(parentAlbum != nil)
                currentAlbum = parentAlbum;
            
            return;
        }
        // theorically, album may exists already...
    }
    
    
    // check child item
    if([elementName isEqualToString:@"child"]) {
        // the child is an album
        if(requestType == SBSubsonicRequestGetAlbumDirectory) {
            if(currentArtist) {
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
                    
                    if(!newAlbum.cover) {
#if DEBUG
                        NSLog(@"Create new cover");
#endif
                        newCover = [self createCoverWithAttribute:attributeDict];
                        [newCover setId:[attributeDict valueForKey:@"coverArt"]];
                        [newCover setAlbum:newAlbum];
                        [newAlbum setCover:newCover];
                    }
                    
                    if(!newAlbum.cover.imagePath || ![[NSFileManager defaultManager] fileExistsAtPath:newAlbum.cover.imagePath]) {
                        [clientController getCoverWithID:[attributeDict valueForKey:@"coverArt"]];
                    }
                }
            }
            
            // the child is a track
        } else if(requestType == SBSubsonicRequestGetTrackDirectory) {
            if(currentAlbum) {
                
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
                }
            }
        }
        return;
    }
    
    
    // get albums list (Home)
    if([elementName isEqualToString:@"albumList"]) {
        
        // clear current home albums
        [server.home setAlbums:nil];
        return;
    }
    
    // get album entries
    if([elementName isEqualToString:@"album"]) {
        
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
        
        return;
    }
    
    
    if([elementName isEqualToString:@"playlists"]) {
        if(requestType == SBSubsonicRequestGetPlaylists) {
            //SBSection *remotePlaylistsSection = [self fetchSectionWithName:@"PLAYLISTS"];
            //[remotePlaylistsSection setResources:nil];
            
            return;
        } else if(requestType == SBSubsonicRequestGetPlaylist) {
            return;
        }
    }
    
    
    if([elementName isEqualToString:@"playlist"]) {
        if(requestType == SBSubsonicRequestGetPlaylists) {
            
            // check if playlist exists
            SBPlaylist *newPlaylist = [self fetchPlaylistWithID:[attributeDict valueForKey:@"id"] orName:nil];
            
            // if playlist not found, create it
            if(newPlaylist == nil) {
                
                // try with name
                newPlaylist = [self fetchPlaylistWithID:nil orName:[attributeDict valueForKey:@"name"]];
#if DEBUG
                NSLog(@"Create new playlist : %@", [attributeDict valueForKey:@"name"]);
#endif
                if(!newPlaylist)
                    newPlaylist = [self createPlaylistWithAttribute:attributeDict];
            }

            [server willChangeValueForKey:@"playlist"];
            [[server mutableSetValueForKey: @"resources"] addObject: newPlaylist];
            [server didChangeValueForKey:@"playlist"];
            
            return;
        } else if(requestType == SBSubsonicRequestGetPlaylist) {
            currentPlaylist = [self fetchPlaylistWithID:[attributeDict valueForKey:@"id"] orName:nil];
//            if(currentPlaylist)
//                [currentPlaylist setTracks:nil];
        }
    }
    
    
    // check playlist entries
    if([elementName isEqualToString:@"entry"]) { 
        if(requestType == SBSubsonicRequestGetPlaylist) {
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
                    
                    if(!exists) {
                        [currentPlaylist addTracksObject:track];
                        [track setPlaylist:currentPlaylist];
                    }
                // no track found    
                } else {
                    // create it
                    track = [self createTrackWithAttribute:attributeDict];
                    [currentPlaylist addTracksObject:track];
                    [track setServer:server];
                    [track setPlaylist:currentPlaylist];
                }
                
                // increment playlist index
                return;
            }
        } else if(requestType == SBSubsonicRequestGetNowPlaying) {
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
            
            return;
        }
    }
    
    if([elementName isEqualToString:@"chatMessage"]) {
#if DEBUG
        NSLog(@"Create new chat message");
#endif
        NSLog(@"Chat is no longer supported.");
    }
    
    if([elementName isEqualToString:@"user"]) {
        [nc postNotificationName:SBSubsonicUserInfoUpdatedNotification object:attributeDict];
    }
    
    
    // check for search2 result (song parsing)
    if([elementName isEqualToString:@"song"]) { 
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
                return;
            }
        }
    }
    
    
    // get license result
    if([elementName isEqualToString:@"license"]) { 
        
        BOOL valid              = ([[attributeDict valueForKey:@"valid"] isEqualToString:@"true"]) ? YES : NO;
        NSString *licenseEmail  = [attributeDict valueForKey:@"email"];
        NSDate *licenseDate     = [NSDate dateWithNaturalLanguageString:[attributeDict valueForKey:@"date"]];
        
        [server setIsValidLicense:[NSNumber numberWithBool:valid]];
        [server setLicenseEmail:licenseEmail];
        [server setLicenseDate:licenseDate];
    
        return;
    }
    
    // podcasts
    if([elementName isEqualToString:@"channel"]) { 
        
        SBPodcast *podcast = nil;
        
        // fetch podcast with ID
        podcast = [self fetchPodcastWithID:[attributeDict valueForKey:@"id"]];
        if(!podcast) {
            podcast = [self createPodcastWithAttribute:attributeDict];
        }
        
        [self setCurrentPodcast:podcast];
    }
    
    // podcast episodes
    if([elementName isEqualToString:@"episode"]) { 
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
            
            return;
        }
    }
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    if([elementName isEqualToString:@"subsonic-response"]) {
        
    }
    
    // check end of indexes
    if([elementName isEqualToString:@"indexes"]) {

    }
    
    if([elementName isEqualToString:@"directory"]) {
        
    }
    
    if([elementName isEqualToString:@"albumList"]) {
    }
    
    if([elementName isEqualToString:@"playlists"]) {
        
    }
    
    if([elementName isEqualToString:@"channel"]) {
        if(currentPodcast) {
            currentPodcast = nil;
        }
    }
    
    if([elementName isEqualToString:@"playlist"]) {
        // MOVED TO parserDidEndDocument:
//        if(requestType == SBSubsonicRequestGetPlaylist) {
//            if(currentPlaylist) {
//                [currentPlaylist release];
//                currentPlaylist = nil;
//            }
//        }
        playlistIndex = 0;
    }
    
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    
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

- (SBTrack *)createTrackWithAttribute:(NSDictionary *)attributeDict {
    SBTrack *newTrack = [SBTrack insertInManagedObjectContext:[self threadedContext]];
    [newTrack setId:[attributeDict valueForKey:@"id"]];
    [newTrack setIsLocal:[NSNumber numberWithBool:NO]];
    [newTrack setServer:server];
    [server addTracksObject:newTrack];
    
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
        NSISO8601DateFormatter *formatter = [[NSISO8601DateFormatter alloc] init];
        [newEpisode setPublishDate:[formatter dateFromString:[attributeDict valueForKey:@"publishDate"]]];
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
    
    NSArray *groups = [[self threadedContext] fetchEntitiesNammed:@"Group" withPredicate:predicate error:&error];
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
    
    NSArray *artists = [[self threadedContext] fetchEntitiesNammed:@"Artist" withPredicate:predicate error:&error];
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
    
    NSArray *albums = [[self threadedContext] fetchEntitiesNammed:@"Album" withPredicate:predicate error:&error];
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
    
    NSArray *tracks = [[self threadedContext] fetchEntitiesNammed:@"Track" withPredicate:predicate error:&error];
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
    
    NSArray *playlists = [[self threadedContext] fetchEntitiesNammed:@"Playlist" withPredicate:predicate error:&error];
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
    
    NSArray *covers = [[self threadedContext] fetchEntitiesNammed:@"Cover" withPredicate:predicate error:&error];
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
    
    NSArray *sections = [[self threadedContext] fetchEntitiesNammed:@"Section" withPredicate:predicate error:&error];
    if(sections && [sections count] > 0) {
        return (SBSection *)[[self threadedContext] objectWithID:[[sections objectAtIndex:0] objectID]];
    }
    return nil;
}

- (SBPodcast *)fetchPodcastWithID:(NSString *)channelID {
    
    NSError *error = nil;
    NSPredicate *predicate = nil;
    
    if(channelID)
        predicate = [NSPredicate predicateWithFormat: @"(id == %@)", channelID];
    
    NSArray *podcasts = [[self threadedContext] fetchEntitiesNammed:@"Podcast" withPredicate:predicate error:&error];
    if(podcasts && [podcasts count] > 0) {
        return (SBPodcast *)[[self threadedContext] objectWithID:[[podcasts objectAtIndex:0] objectID]];
    }
    return nil;
}


- (SBEpisode *)fetchEpisodeWithID:(NSString *)episodeID {
    
    NSError *error = nil;
    NSPredicate *predicate = nil;
    
    if(episodeID)
        predicate = [NSPredicate predicateWithFormat: @"(id == %@)", episodeID];
    
    NSArray *episodes = [[self threadedContext] fetchEntitiesNammed:@"Episode" withPredicate:predicate error:&error];
    if(episodes && [episodes count] > 0) {
        return (SBEpisode *)[[self threadedContext] objectWithID:[[episodes objectAtIndex:0] objectID]];
    }
    return nil;
}

@end
