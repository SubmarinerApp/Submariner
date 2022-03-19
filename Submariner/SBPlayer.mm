//
//  SBPlayer.m
//  Sub
//
//  Created by Rafaël Warnault on 22/05/11.
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

#include <libkern/OSAtomic.h>
#import <SFBAudioEngine/SFBAudioPlayer.h>
#import <SFBAudioEngine/SFBAudioDecoder.h>

#import "SBAppDelegate.h"
#import "SBPlayer.h"
#import "SBTrack.h"
#import "SBServer.h"
#import "SBLibrary.h"
#import "SBImportOperation.h"

#import "NSURL+Parameters.h"
#import "NSManagedObjectContext+Fetch.h"
#import "NSOperationQueue+Shared.h"
#import "NSString+Time.h"


#define LOCAL_PLAYER localPlayer


// notifications
NSString *SBPlayerPlaylistUpdatedNotification = @"SBPlayerPlaylistUpdatedNotification";
NSString *SBPlayerMovieToPlayNotification = @"SBPlayerPlaylistUpdatedNotification";


/*
@interface QTMovie(IdlingAdditions)
-(QTTime)maxTimeLoaded;
- (void)movieDidEnd:(NSNotification *)notification;
@end
*/


@interface SBPlayer (Private)

- (void)playRemoteWithURL:(NSURL *)url;
- (void)playLocalWithURL:(NSURL *)url;
- (void)unplayAllTracks;
- (void)decodingStarted:(const SFBAudioDecoder *)decoder;
- (SBTrack *)getRandomTrackExceptingTrack:(SBTrack *)_track;
- (SBTrack *)nextTrack;
- (SBTrack *)prevTrack;
- (void)showVideoAlert;

@end

@implementation SBPlayer


@synthesize currentTrack;
@synthesize playlist;
@synthesize isShuffle;
@synthesize isPlaying;
@synthesize isPaused;
@synthesize repeatMode;




#pragma mark -
#pragma mark Singleton support 

+ (SBPlayer*)sharedInstance {

    static SBPlayer* sharedInstance = nil;
    if (sharedInstance == nil) {
        sharedInstance = [[SBPlayer alloc] init];
    }
    return sharedInstance;
    
}



- (id)init {
    self = [super init];
    if (self) {
        localPlayer = [[SFBAudioPlayer alloc] init];
        
        playlist = [[NSMutableArray alloc] init];
        isShuffle = NO;
        isCaching = NO;
        
        repeatMode = SBPlayerRepeatNo;
    }
    return self;
}

- (void)dealloc {
    // remove remote player observers
    [self stop];
    
    [LOCAL_PLAYER dealloc];
    localPlayer = NULL;
    
    [remotePlayer release];
    [currentTrack release];
    [playlist release];
    [tmpLocation release];
    [super dealloc];
}





#pragma mark -
#pragma mark Playlist Management

- (void)addTrack:(SBTrack *)track replace:(BOOL)replace {
    
    if(replace) {
        [playlist removeAllObjects];
    }
    
    [playlist addObject:track];
    [[NSNotificationCenter defaultCenter] postNotificationName:SBPlayerPlaylistUpdatedNotification object:self];
}

- (void)addTrackArray:(NSArray *)array replace:(BOOL)replace {
    
    if(replace) {
        [playlist removeAllObjects];
    }
    
    [playlist addObjectsFromArray:array];
    [[NSNotificationCenter defaultCenter] postNotificationName:SBPlayerPlaylistUpdatedNotification object:self];
}


- (void)removeTrack:(SBTrack *)track {
    if([track isEqualTo:self.currentTrack]) {
        [self stop];
    }
    
    [playlist removeObject:track];
    [[NSNotificationCenter defaultCenter] postNotificationName:SBPlayerPlaylistUpdatedNotification object:self];
}

- (void)removeTrackArray:(NSArray *)tracks {
    [playlist removeObjectsInArray:tracks];
    [[NSNotificationCenter defaultCenter] postNotificationName:SBPlayerPlaylistUpdatedNotification object:self];
}






#pragma mark -
#pragma mark Player Control

- (void)playTrack:(SBTrack *)track {
    
    // stop player
    [self stop];
        
    // clean previous playing track
    if(self.currentTrack != nil) {
        [self.currentTrack setIsPlaying:[NSNumber numberWithBool:NO]];
        self.currentTrack = nil;
    }
    
    // set the new current track
    [self setCurrentTrack:track];    
    
    // check if cache download enable or not : manage the tmp file
    if([[NSUserDefaults standardUserDefaults] boolForKey:@"enableCacheStreaming"] == YES) {
        if(tmpLocation) {
            [tmpLocation release];
            tmpLocation = nil;
        }
        
        // create a cache temp file
        NSURL *tempFileURL = [NSURL temporaryFileURL];
        tmpLocation = [[[tempFileURL absoluteString] stringByAppendingPathExtension:@"mp3"] retain];
        
        if([[NSFileManager defaultManager] createFileAtPath:tmpLocation contents:nil attributes:nil]) {
            isCaching = YES;
        }
    } else {
        isCaching = NO;
    }
    
    
    // play the song remotely (QTMovie from QTKit framework) or locally (AudioPlayer from SFBAudioEngine framework)
    if(self.currentTrack.isVideo) {
        [self showVideoAlert];
        return;
    } else {
        if([self.currentTrack.isLocal boolValue]) { // should add video exception here
            [self playLocalWithURL:[self.currentTrack streamURL]];
            //[self playRemoteWithURL:[self.currentTrack streamURL]];
        } else {
            if(self.currentTrack.localTrack != nil) {
                [self playLocalWithURL:[self.currentTrack.localTrack streamURL]];
                //[self playRemoteWithURL:[self.currentTrack.localTrack streamURL]];
            } else {
                //[self playLocalWithURL:[self.currentTrack streamURL]];
                [self playRemoteWithURL:[self.currentTrack streamURL]];
            }
        }   
    }
    
    // setup player for playing
    [self.currentTrack setIsPlaying:[NSNumber numberWithBool:YES]];
    [[NSNotificationCenter defaultCenter] postNotificationName:SBPlayerPlaylistUpdatedNotification object:self];
    self.isPlaying = YES;
    self.isPaused = NO;
}


- (void)playRemoteWithURL:(NSURL *)url {
    remotePlayer = [[AVPlayer alloc] initWithURL:url];
    
	if (!remotePlayer)
		NSLog(@"Couldn't init player");
    
	else {
        [remotePlayer setVolume:[self volume]];
        [remotePlayer addObserver:self forKeyPath:@"status" options:0 context:nil];
        AVPlayerItem *currentItem = [remotePlayer currentItem];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(itemDidFinishPlaying:) name:AVPlayerItemDidPlayToEndTimeNotification object:currentItem];
    }
}

- (void)playLocalWithURL:(NSURL *)url {
    NSError *decodeError = nil;
    SFBAudioDecoder *decoder = [[SFBAudioDecoder alloc] initWithURL: url /*decoderName:SFBAudioDecoderNameFLAC*/ error: &decodeError];
	if(NULL != decoder) {
        
        [LOCAL_PLAYER setVolume: [self volume] error: nil];
        
        // Register for rendering started/finished notifications so the UI can be updated properly
        [LOCAL_PLAYER setDelegate:self];
        NSError *decoderError = nil;
        [decoder openReturningError: &decoderError];
        if (decoderError) {
            NSLog(@"Decoder open error: %@", decoderError);
            [decoder dealloc];
            return;
        }
        if([LOCAL_PLAYER enqueueDecoder: decoder error: nil]) {
            //[[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:url];
        }else {
            [decoder dealloc];
        }
    } else {
        NSLog(@"Couldn't decode %@: %@", url, decodeError);
    }
}


- (void)playPause {
    if((remotePlayer != nil) && ([remotePlayer rate] != 0)) {
        [remotePlayer pause];
    } else {
        [remotePlayer play];
    }
    if(LOCAL_PLAYER && [LOCAL_PLAYER engineIsRunning]) {
        NSError *error;
        [LOCAL_PLAYER togglePlayPauseReturningError:&error];
    }
}

- (void)next {
    SBTrack *next = [self nextTrack];
    if(next != nil) {
        @synchronized(self) {
            [self playTrack:next];
        }
    } else { 
        [self stop];
    }
}

- (void)previous {
    SBTrack *prev = [self prevTrack];
    if(prev != nil) {
        @synchronized(self) {
            //[self stop];
            [self playTrack:prev];
        }
    }
}


- (void)setVolume:(float)volume {
    
    [[NSUserDefaults standardUserDefaults] setFloat:volume forKey:@"playerVolume"];
    
    if(remotePlayer)
        [remotePlayer setVolume:volume];
    
    NSError *error = nil;
    [LOCAL_PLAYER setVolume:volume error:&error];
}


- (void)seek:(double)time {
    if(remotePlayer != nil) {
        AVPlayerItem *currentItem = [remotePlayer currentItem];
        CMTime durationCM = [currentItem duration];
        CMTime newTime = CMTimeMultiplyByFloat64(durationCM, (time / 100.0));
        [remotePlayer seekToTime:newTime];
    }
    
    if(LOCAL_PLAYER && [LOCAL_PLAYER isPlaying]) {
        SInt64 totalFrames;
        if([LOCAL_PLAYER supportsSeeking]) {
/*
// XXX: Think about this one later
            if(LOCAL_PLAYER->GetTotalFrames(totalFrames)) {
                //NSLog(@"seek");
                SInt64 desiredFrame = static_cast<SInt64>((time / 100.0) * totalFrames);
                LOCAL_PLAYER->SeekToFrame(desiredFrame);
            }
*/
        } else {
            NSLog(@"WARNING : no seek support for this file");
        }
    }
    
    if(isCaching) {
        isCaching = NO;
    }
}


- (void)stop {

    @synchronized(self) {
        // stop players
        if(remotePlayer) {
            [remotePlayer replaceCurrentItemWithPlayerItem:nil];
            [remotePlayer release];
            remotePlayer = nil;
        }
        
        if([LOCAL_PLAYER isPlaying]) {
            [LOCAL_PLAYER stop];
            [LOCAL_PLAYER clearQueue];
        }
        
        // unplay current track
        [self.currentTrack setIsPlaying:[NSNumber numberWithBool:NO]];
        self.currentTrack  = nil;
        
        // unplay all
        [self unplayAllTracks];
        
        // stop player !
        self.isPlaying = NO;
        self.isPaused = YES; // for sure
	}
}


- (void)clear {
    //[self stop];
    [self.playlist removeAllObjects];
    [self setCurrentTrack:nil];
}


#pragma mark -
#pragma mark Accessors (Player Properties)


- (NSString *)currentTimeString {
    
    if(remotePlayer != nil)
    {
        CMTime currentTimeCM = [remotePlayer currentTime];
        NSTimeInterval currentTime = CMTimeGetSeconds(currentTimeCM);
        return [NSString stringWithTime:currentTime];
    }
    
    if([LOCAL_PLAYER isPlaying])
    {
// XXX: getPlaybackPosition
/*
        SInt64 currentFrame, totalFrames;
        CFTimeInterval currentTime, totalTime;
        
        if(LOCAL_PLAYER->GetPlaybackPositionAndTime(currentFrame, totalFrames, currentTime, totalTime)) {
            return [NSString stringWithTime:currentTime];
        }
*/
return nil;
    }
    
    return nil;
}

- (NSString *)remainingTimeString {
    if(remotePlayer != nil)
    {
        AVPlayerItem *currentItem = [remotePlayer currentItem];
        CMTime durationCM = [currentItem duration];
        CMTime currentTimeCM = [currentItem currentTime];
        NSTimeInterval duration = CMTimeGetSeconds(durationCM);
        NSTimeInterval currentTime = CMTimeGetSeconds(currentTimeCM);
        NSTimeInterval remainingTime = duration-currentTime;
        return [NSString stringWithTime:-remainingTime];
    }
    
    if([LOCAL_PLAYER isPlaying])
    {
        SInt64 currentFrame, totalFrames;
        CFTimeInterval currentTime, totalTime;
        
/*
// XXX: getPlaybackPosition
        if(LOCAL_PLAYER->GetPlaybackPositionAndTime(currentFrame, totalFrames, currentTime, totalTime)) {
            return [NSString stringWithTime:(-1 * (totalTime - currentTime))];
        }
*/
    }
    
    return nil;
}

- (double)progress {
    if(remotePlayer != nil)
    {
        // typedef struct { long long timeValue; long timeScale; long flags; } QTTime
        AVPlayerItem *currentItem = [remotePlayer currentItem];
        CMTime durationCM = [currentItem duration];
        CMTime currentTimeCM = [currentItem currentTime];
        NSTimeInterval duration = CMTimeGetSeconds(durationCM);
        NSTimeInterval currentTime = CMTimeGetSeconds(currentTimeCM);
        
        if(duration > 0) {
            double progress = ((double)currentTime) / ((double)duration) * 100; // make percent
            //double bitrate = [[[remotePlayer movieAttributes] valueForKey:QTMovieDataSizeAttribute] doubleValue]/duration * 10;
            //NSLog(@"bitrate : %f", bitrate);
            
            if(progress == 100) { // movie is at end
                [self next];
            }
            
            return progress;
            
        } else {
            return 0;
        }
    }
    
    if([LOCAL_PLAYER isPlaying])
    {
        SInt64 currentFrame, totalFrames;
        CFTimeInterval currentTime, totalTime;
        
/*
// XXX: getPlaybackPosition
        if(LOCAL_PLAYER->GetPlaybackPositionAndTime(currentFrame, totalFrames, currentTime, totalTime)) {
            double fractionComplete = static_cast<double>(currentFrame) / static_cast<double>(totalFrames) * 100;
            
//            NSLog(@"fractionComplete : %f", fractionComplete);
//            if(fractionComplete > 99.9) { // movie is at end
//                [self playPause];
//                [self next];
//            }
            
            return fractionComplete;
        } else {
            return 0;
        }
*/
return 0;
    }
    
    return 0;
}


- (float)volume {
    return [[NSUserDefaults standardUserDefaults] floatForKey:@"playerVolume"];
}

- (double)percentLoaded {
    double percentLoaded = 0;

    if(remotePlayer != nil) {
        AVPlayerItem *currentItem = [remotePlayer currentItem];
        CMTime durationCM = [currentItem duration];
        NSTimeInterval tMaxLoaded;
        NSArray *ranges = [currentItem loadedTimeRanges];
        if ([ranges count] > 0) {
            CMTimeRange range = [[ranges firstObject] CMTimeRangeValue];
            tMaxLoaded = CMTimeGetSeconds(range.duration) - CMTimeGetSeconds(range.start);
        } else {
            tMaxLoaded = 0;
        }
        NSTimeInterval tDuration = CMTimeGetSeconds(durationCM);
        
        percentLoaded = (double) tMaxLoaded/tDuration;
    }
    
    if([LOCAL_PLAYER isPlaying]) {
        percentLoaded = 1;
    }
    
    return percentLoaded;
}




#pragma mark -
#pragma mark Remote Player Notification 

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == remotePlayer && [keyPath isEqualToString:@"status"]) {
        if ([remotePlayer status] == AVPlayerStatusFailed) {
            NSLog(@"AVPlayer Failed: %@", [remotePlayer error]);
            [self stop];
        } else if ([remotePlayer status] == AVPlayerStatusReadyToPlay) {
            NSLog(@"AVPlayerStatusReadyToPlay");
            [remotePlayer play];
        } else if ([remotePlayer status] == AVPlayerItemStatusUnknown) {
            NSLog(@"AVPlayer Unknown");
            [self stop];
        }
    }
    /*
        NSError *error = nil;
        if([[NSUserDefaults standardUserDefaults] boolForKey:@"enableCacheStreaming"] == YES)
        {
            NSDictionary* attr2 = [NSDictionary dictionaryWithObjectsAndKeys:
                                   [NSNumber numberWithBool:YES], QTMovieFlatten,
                                   //[NSNumber numberWithBool:YES], QTMovieExport,
                                   //[NSNumber numberWithLong:kQTFileType], QTMovieExportType,
                                   [NSNumber numberWithLong:kAppleManufacturer], QTMovieExportManufacturer,
                                   nil];
            
            [remotePlayer writeToFile:tmpLocation withAttributes:attr2 error:&error];
            
            NSManagedObjectContext *moc = self.currentTrack.managedObjectContext;
            SBLibrary *library = [moc fetchEntityNammed:@"Library" withPredicate:nil error:nil];
            
            // import audio file
            SBImportOperation *op = [[SBImportOperation alloc] initWithManagedObjectContext:moc];
            [op setFilePaths:[NSArray arrayWithObject:tmpLocation]];
            [op setLibraryID:[library objectID]];
            [op setRemoteTrackID:[self.currentTrack objectID]];
            [op setCopy:YES];
            [op setRemove:YES];
            
            [[NSOperationQueue sharedDownloadQueue] addOperation:op];
        }
    */
}

-(void)itemDidFinishPlaying:(NSNotification *) notification {
    [self next];
}

#pragma mark -
#pragma mark Local Player Delegate

- (void) audioPlayer:(SFBAudioPlayer *)audioPlayer decodingStarted:(id<SFBPCMDecoding>)decoder
{
    #pragma unused(decoder)
    NSError *error = nil;
    [LOCAL_PLAYER playReturningError:&error];
}

// This is called from the realtime rendering thread and as such MUST NOT BLOCK!!
- (void) audioPlayer:(SFBAudioPlayer *)audioPlayer decodingComplete:(id<SFBPCMDecoding>)decoder
{
    [self next];
}

#pragma mark -
#pragma mark Private


- (SBTrack *)getRandomTrackExceptingTrack:(SBTrack *)_track {
	
	SBTrack *randomTrack = _track;
	NSArray *sortedTracks = [self playlist];
	
	if([sortedTracks count] > 1) {
		while ([randomTrack isEqualTo:_track]) {
			NSInteger numberOfTracks = [sortedTracks count];
			NSInteger randomIndex = random() % numberOfTracks;
			randomTrack = [sortedTracks objectAtIndex:randomIndex];
		}
	} else {
		randomTrack = nil;
	}
	
	return randomTrack;
}


- (SBTrack *)nextTrack {
    
    if(self.playlist) {
        if(!isShuffle) {
            NSInteger index = [self.playlist indexOfObject:self.currentTrack];
            
            if(repeatMode == SBPlayerRepeatNo) {
                
                // no repeat, play next
                if(index > -1 && [self.playlist count]-1 >= index+1) {
                    return [self.playlist objectAtIndex:index+1];
                }
            }
                
            // if repeat one, esay to relaunch the track
            if(repeatMode == SBPlayerRepeatOne)
                return self.currentTrack;
            
            // if repeat all, broken...
             if(repeatMode == SBPlayerRepeatAll)
                 if([self.currentTrack isEqualTo:[self.playlist lastObject]] && index > 0)
                     return [self.playlist objectAtIndex:0];
				else
					if(index > -1 && [self.playlist count]-1 >= index+1) {
						return [self.playlist objectAtIndex:index+1];
					}
            
        } else {
            // if repeat one, get the piority
            if(repeatMode == SBPlayerRepeatOne)
                return self.currentTrack;
            
            // else play random
            return [self getRandomTrackExceptingTrack:self.currentTrack];
        }
    }
    return nil;
}


- (SBTrack *)prevTrack {
    if(self.playlist) {
        if(!isShuffle) {
            NSInteger index = [self.playlist indexOfObject:self.currentTrack];   
            
            if(repeatMode == SBPlayerRepeatOne)
                return self.currentTrack;
            
            if(index == 0)
                if(repeatMode == SBPlayerRepeatAll)
                    return [self.playlist lastObject];
                        if(index != -1)
                return [self.playlist objectAtIndex:index-1];
        } else {
            // if repeat one, get the piority
            if(repeatMode == SBPlayerRepeatOne)

                return self.currentTrack;
            
            return [self getRandomTrackExceptingTrack:self.currentTrack];
        }
    }
    return nil;
}

- (void)unplayAllTracks {

    NSError *error = nil;
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(isPlaying == YES)"];
    NSArray *tracks = [[self.currentTrack managedObjectContext] fetchEntitiesNammed:@"Track" withPredicate:predicate error:&error];
    
    for(SBTrack *track in tracks) {
        [track setIsPlaying:[NSNumber numberWithBool:NO]];
    }
}


- (void)showVideoAlert {
    NSAlert *alert = [NSAlert alertWithMessageText:@"Video streaming" 
                                     defaultButton:@"OK" 
                                   alternateButton:nil
                                       otherButton:nil
                         informativeTextWithFormat:@"This file appears to be a video file. Submariner is not able to streaming movie yet."];
    
    [alert runModal];
}



@end
