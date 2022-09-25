//
//  SBImportOperation.m
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

#import "SBImportOperation.h"
#import <CoreServices/CoreServices.h>
//#import <QTKit/QTKit.h>

#import <SFBAudioEngine/SFBAttachedPicture.h>
#import <SFBAudioEngine/SFBAudioDecoder.h>
#import <SFBAudioEngine/SFBAudioFile.h>
#import <SFBAudioEngine/SFBAudioMetadata.h>
#import <SFBAudioEngine/SFBAudioProperties.h>

#import "SBAppDelegate.h"

#import "SBLibrary.h"
#import "SBArtist.h"
#import "SBAlbum.h"
#import "SBTrack.h"
#import "SBCover.h"

#import "NSURL+Parameters.h"
#import "NSManagedObjectContext+Fetch.h"




//using namespace TagLib;



@interface SBImportOperation (Private)
- (NSArray *)audioFilesAtPath:(NSString *)path;
@end



@implementation SBImportOperation



@synthesize filePaths;
@synthesize libraryID;
@synthesize copy;
@synthesize remove;
@synthesize remoteTrackID;



- (id)initWithManagedObjectContext:(NSManagedObjectContext *)mainContext {
    self = [super initWithManagedObjectContext:mainContext];
    if (self) {
        copy = NO;
        remove = NO;
    }
    return self;
}



- (void)main {
    @autoreleasepool {
    
        @try {
            
            NSMutableArray *audioFiles = [NSMutableArray array];
            
            SBLibrary *library = (SBLibrary *)[[self threadedContext] objectWithID:libraryID];
            
            for(NSString *path in self.filePaths) {
                NSLog(@"path : %@", path);
                [audioFiles addObjectsFromArray:[self audioFilesAtPath:path]];
            }
            
#if DEBUG
            NSLog(@"INFO : %ld files to import...", [audioFiles count]);
#endif
            
            for(NSString *aPath in audioFiles) {
                
                NSString *path = [[[NSURL temporaryFileURL] absoluteString] stringByAppendingPathExtension:[aPath pathExtension]];
                [[NSFileManager defaultManager] copyItemAtPath:aPath toPath:path error:nil];
                
                NSPredicate *predicate = nil;
                
                NSString *titleString       = nil;
                NSString *artistString      = nil;
                NSString *albumArtistString = nil;
                NSString *albumString       = nil;   
                NSString *genreString       = nil;  
                NSString *contentType       = nil;   
                NSNumber *trackNumber       = nil;   
                NSNumber *discNumber       = nil;   
                NSNumber *durationNumber    = nil;
                NSNumber *bitRateNumber     = nil;
                NSData   *coverData         = nil;   
                
                NSError *fetchError = nil;
                SBArtist *newArtist = nil;
                SBAlbum *newAlbum = nil;
                SBTrack *newTrack = nil;
                
                NSError *copyError = nil;
                NSString *artistPath = nil;
                NSString *albumPath = nil;
                NSString *trackPath = nil;
                
                // use SFBAudioEngine
                NSURL *fileURL = [NSURL fileURLWithPath: path];
                NSError *error = nil;
                SFBAudioFile *audioFile = [SFBAudioFile audioFileWithURL: fileURL error: &error];
                if (error) {
                    NSLog(@"Error loading audio file for import: %@", error);
                    continue;
                }
                SFBAudioMetadata *metadata = [audioFile metadata];
                SFBAudioProperties *properties = [audioFile properties];
                
                if(NULL != metadata && NULL != properties) {
                    if(!remoteTrackID) {
                        
                        // get file metadata
                        titleString       = [metadata title];
                        artistString      = [metadata artist];
                        albumArtistString = [metadata albumArtist];
                        if (albumArtistString == nil || [albumArtistString isEqualToString: @""]) {
                            albumArtistString = artistString;
                        }
                        albumString       = [metadata albumTitle];
                        genreString       = [metadata genre];
                        trackNumber       = [metadata trackNumber];
                        discNumber        = [metadata discNumber];
                        durationNumber    = [properties duration];
                        bitRateNumber     = [properties bitrate];
// XXX
                        coverData         = [[[metadata attachedPictures] anyObject] imageData];
                        
                        // if this is a cache or download data importation
                    } else {
                        // use remote track metadata
                        SBTrack *remoteTrack = (SBTrack *)[[self threadedContext] objectWithID:remoteTrackID];
                        
                        titleString       = remoteTrack.itemName;
                        artistString      = remoteTrack.artistName;
                        albumArtistString = remoteTrack.artistString;
                        if (albumArtistString == nil || [albumArtistString isEqualToString: @""]) {
                            albumArtistString = artistString;
                        }
                        albumString       = remoteTrack.albumString;
                        genreString       = remoteTrack.genre;
                        trackNumber       = remoteTrack.trackNumber;
                        discNumber        = remoteTrack.discNumber;
                        durationNumber    = remoteTrack.duration;
                        bitRateNumber     = remoteTrack.bitRate;
                        contentType       = remoteTrack.contentType;
// XXX
                        coverData         = [[[metadata attachedPictures] anyObject] imageData];
                    }
                }
                
                
                // create artist object if needed; using the album artist's name
                if(!albumArtistString || [albumArtistString isEqualToString:@""])
                    albumArtistString = @"Unknown Artist";
                
                predicate = [NSPredicate predicateWithFormat:@"(itemName == %@) && (server == nil)", albumArtistString];
                newArtist = [[self threadedContext] fetchEntityNammed:@"Artist" withPredicate:predicate error:&fetchError];
                
                if(newArtist == nil) {
                    newArtist = [SBArtist insertInManagedObjectContext:[self threadedContext]];
                    [newArtist setItemName:albumArtistString];
                }
                
                // create album if needed
                if(!albumString || [albumString isEqualToString:@""]) 
                    albumString = @"Unknown Album";
                
                predicate = [NSPredicate predicateWithFormat:@"(itemName == %@) && (artist == %@)", albumString, newArtist];
                newAlbum = [[self threadedContext] fetchEntityNammed:@"Album" withPredicate:predicate error:&fetchError];
                
                if(newAlbum == nil) {
                    newAlbum = [SBAlbum insertInManagedObjectContext:[self threadedContext]];
                    [newAlbum setItemName:albumString];
                }
                
                // create track if needed
                if(!titleString || [titleString isEqualToString:@""]) 
                    titleString = @"Unknown Track";
                
                predicate = [NSPredicate predicateWithFormat:@"(itemName == %@) && (server == nil)", titleString];
                newTrack = [[self threadedContext] fetchEntityNammed:@"Track" withPredicate:predicate error:&fetchError];
                
                if(newTrack == nil) {
                    newTrack = [SBTrack insertInManagedObjectContext:[self threadedContext]];
                    [newTrack setItemName:titleString];
                    
                    if(bitRateNumber)
                        [newTrack setBitRate:bitRateNumber];
                    
                    if(durationNumber)
                        [newTrack setDuration:durationNumber];
                    
                    if(trackNumber)
                        [newTrack setTrackNumber:trackNumber];
                    
                    if(discNumber)
                        [newTrack setDiscNumber:discNumber];
                    
                    if(genreString)
                        [newTrack setGenre:genreString];
                    
                    if(contentType)
                        [newTrack setContentType:contentType];
                    
                    // not the album artist
                    if(artistString)
                        [newTrack setArtistName:artistString];
                }
                
                if(![newAlbum.tracks containsObject:newTrack]) {
                    [newAlbum addTracksObject:newTrack];
                }
                
                if(![newArtist.albums containsObject:newAlbum]) {
                    [newArtist addAlbumsObject:newAlbum];
                }
                
                if(![library.artists containsObject:newArtist]) {
                    [library addArtistsObject:newArtist];
                }

                
                // treat copy
                if(copy == YES) {
                    artistPath = [[[SBAppDelegate sharedInstance] musicDirectory] stringByAppendingPathComponent:albumArtistString];
                    albumPath = [artistPath stringByAppendingPathComponent:albumString];
                    trackPath = [albumPath stringByAppendingPathComponent:[path lastPathComponent]];
                    
                    // create artist and album directory if needed
                    [[NSFileManager defaultManager] createDirectoryAtPath:albumPath withIntermediateDirectories:YES attributes:nil error:&copyError];
                    
                    // copy track to new destination
                    [[NSFileManager defaultManager] copyItemAtPath:path toPath:trackPath error:&copyError];
                    
                    [newTrack setPath:trackPath];
                    [newAlbum setPath:albumPath];
                    [newArtist setPath:artistPath];
                    
                } else {
                    [newTrack setPath:aPath];
                }
                
//            // work with the cover
//            if (coverData) {
//                // if file metadata contains the cover art data
//                NSString *coverDir = [[SBAppDelegate sharedInstance] coverDirectory];
//                NSString *artistCoverDir = [coverDir stringByAppendingPathComponent:albumArtistString];
//                if(![[NSFileManager defaultManager] fileExistsAtPath:artistCoverDir]) {
//                    [[NSFileManager defaultManager] createDirectoryAtPath:artistCoverDir withIntermediateDirectories:YES attributes:nil error:nil];
//                }
//                NSString *finalPath = [artistCoverDir stringByAppendingPathComponent:albumString];
//                [coverData writeToFile:finalPath atomically:YES];
//            
//                [newAlbum.cover setImagePath:finalPath];
//                [newTrack.cover setImagePath:finalPath];
//            
//            } else {
//                // else if track parent directory contains cover file
//                NSString *originalAlbumFolder = [path stringByDeletingLastPathComponent];
//                BOOL isDir;
//        
//                if([[NSFileManager defaultManager] fileExistsAtPath:originalAlbumFolder isDirectory:&isDir] && isDir) {
//                    NSArray *albumFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:originalAlbumFolder error:nil];
//                    for(NSString *fileName in albumFiles) {
//                        NSString *filePath = [originalAlbumFolder stringByAppendingPathComponent:fileName];
//                        
//                        CFStringRef fileExtension = (CFStringRef) [filePath pathExtension];
//                        CFStringRef fileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExtension, NULL);
//                        
//                        // if the current file is an image
//                        if (UTTypeConformsTo(fileUTI, kUTTypeImage)) {
//                            // if it doesn't contain "back" word
//                            if([fileName rangeOfString:@"back"].location == NSNotFound) {
//                                // copy the artwork
//                                NSString *coverDir = [[SBAppDelegate sharedInstance] coverDirectory];
//                                NSString *artistCoverDir = [coverDir stringByAppendingPathComponent:albumArtistString];
//                                if(![[NSFileManager defaultManager] fileExistsAtPath:artistCoverDir]) {
//                                    [[NSFileManager defaultManager] createDirectoryAtPath:artistCoverDir withIntermediateDirectories:YES attributes:nil error:nil];
//                                }
//                                NSString *finalPath = [artistCoverDir stringByAppendingPathComponent:fileName];
//                                [[NSFileManager defaultManager] copyItemAtPath:filePath toPath:finalPath error:nil];
//                                [newAlbum.cover setImagePath:finalPath];
//                                [newTrack.cover setImagePath:finalPath];
//                            }
//                        }
//                    }
//                }
//            }
                
                // set if items are linked or not
                [newTrack setIsLinked:[NSNumber numberWithBool:!copy]];
                [newAlbum setIsLinked:[NSNumber numberWithBool:!copy]];
                [newArtist setIsLinked:[NSNumber numberWithBool:!copy]];
                
                // set items are local items
                [newTrack setIsLocal:[NSNumber numberWithBool:YES]];
                [newAlbum setIsLocal:[NSNumber numberWithBool:YES]];
                [newArtist setIsLocal:[NSNumber numberWithBool:YES]];
                
                // check remove
                if(remove) {
                    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
                }
                
                // check if this import op comes from a stream
                if(remoteTrackID != nil) {
                    // attach local track and remote track
                    // to enhance caching capacities
                    SBTrack *remoteTrack = (SBTrack *)[[self threadedContext] objectWithID:remoteTrackID];
                    [remoteTrack setLocalTrack:newTrack];
                    [newTrack setRemoteTrack:remoteTrack];
                    
                    if(newAlbum.cover == nil)
                        [newAlbum setCover:[SBCover insertInManagedObjectContext:[self threadedContext]]];
                        
                    [newAlbum.cover setImagePath:remoteTrack.album.cover.imagePath];
                }
                
                // remove temp file
                [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
            }
        }
        @catch (NSException *exception) {
            NSLog(@"EXCEPTION : %@", exception);
        }
        @finally {
            [self saveThreadedContext];
            [self finish];
        }
    
    }
}



/** Highly recursive */
- (NSArray *)audioFilesAtPath:(NSString *)path {
    
    NSMutableArray *result = [NSMutableArray array];
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir;
    
    if([fm fileExistsAtPath:path isDirectory:&isDir] && isDir) {
        
        NSArray *content = [fm contentsOfDirectoryAtPath:path error:nil];
        for(NSString *fileName in content) {
            NSString *newPath = [path stringByAppendingPathComponent:fileName];
            [result addObjectsFromArray:[self audioFilesAtPath:newPath]];
        }
        
    } else if(!isDir) {
        
        CFStringRef fileExtension = (__bridge CFStringRef) [path pathExtension];
        CFStringRef fileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExtension, NULL);
        
        // if the current file is an image, and make an exception for M4A which gets counted as video instead
        if (UTTypeConformsTo(fileUTI, kUTTypeAudio) || [path.pathExtension isEqualToString: @"public.mpeg-4"]) {
            [result addObject:path];
        }
    }
    return result;
}


@end
