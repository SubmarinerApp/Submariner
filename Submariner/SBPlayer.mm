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
#import <LRResty/LRResty.h>
#import <SFBAudioEngine/AudioPlayer.h>
#import <SFBAudioEngine/AudioDecoder.h>

#import "SBAppDelegate.h"
#import "SBMovieWindowController.h"
#import "SBPlayer.h"
#import "SBTrack.h"
#import "SBServer.h"
#import "SBLibrary.h"
#import "SBImportOperation.h"

#import "NSURL+Parameters.h"
#import "NSManagedObjectContext+Fetch.h"
#import "NSOperationQueue+Shared.h"
#import "NSString+Time.h"


#define LOCAL_PLAYER (static_cast<AudioPlayer *>(localPlayer))


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
- (void)decodingStarted:(const AudioDecoder *)decoder;
- (SBTrack *)getRandomTrackExceptingTrack:(SBTrack *)_track;
- (SBTrack *)nextTrack;
- (SBTrack *)prevTrack;
- (void)showVideoAlert;

@end



// local player C++ callbacks
static SBPlayer *staticSelf = nil;

static void decodingStarted(void *context, const AudioDecoder *decoder)
{
	[(SBPlayer *)context decodingStarted:decoder];
}

// This is called from the realtime rendering thread and as such MUST NOT BLOCK!!
static void renderingFinished(void *context, const AudioDecoder *decoder)
{
    if(staticSelf) {
        //[staticSelf stop];
        [staticSelf next];
    }
}


@implementation SBPlayer


@synthesize currentTrack;
@synthesize playlist;
@synthesize isShuffle;
@synthesize isPlaying;
@synthesize isPaused;
@synthesize repeatMode;




#pragma mark -
#pragma mark Singleton support 

+ (id)sharedInstance {

    static SBPlayer* sharedInstance = nil;
    if (sharedInstance == nil) {
        sharedInstance = [[SBPlayer alloc] init];
    }
    return sharedInstance;
    
}



- (id)init {
    self = [super init];
    if (self) {
        localPlayer = new AudioPlayer();
        
        playlist = [[NSMutableArray alloc] init];
        isShuffle = NO;
        isCaching = NO;
        
        repeatMode = SBPlayerRepeatNo;
        
        staticSelf = [self retain];
    }
    return self;
}

- (void)dealloc {
    // remove remote player observers
    [self stop];
    
    delete LOCAL_PLAYER, localPlayer = NULL;
    
/*
    [remotePlayer release];
    [remotePlayerItem release];
    [remotePlayerAsset release];
*/
    [currentTrack release];
    [playlist release];
    [tmpLocation release];
    [staticSelf release];
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
        
//        if(self.currentTrack.localTrack != nil) {
//            [self playRemoteWithURL:[self.currentTrack.localTrack streamURL]];
//        } else {
//            [self playRemoteWithURL:[self.currentTrack streamURL]];
//        }
    } else {
        if([self.currentTrack.isLocal boolValue]) { // should add video exception here
            [self playLocalWithURL:[self.currentTrack streamURL]];
            //[self playRemoteWithURL:[self.currentTrack streamURL]];
        } else {
            if(self.currentTrack.localTrack != nil) {
                [self playLocalWithURL:[self.currentTrack.localTrack streamURL]];
                //[self playRemoteWithURL:[self.currentTrack.localTrack streamURL]];
            } else {
                [self playLocalWithURL:[self.currentTrack streamURL]];
                //[self playRemoteWithURL:[self.currentTrack streamURL]];
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
/*
    NSError *error = nil;
    //remotePlayer = [[QTMovie alloc] initWithURL:url error:&error];

    remotePlayerAsset = [AVAsset assetWithURL:URL];
    
	if (!remotePlayer || error)
		NSLog(@"Couldn't init player : %@", error);
    
	else {

        remotePlayerItem = [AVPlayerItem playerItemWithAsset: remotePlayerAsset]
        remotePlayer = [AVPlayer playerWithPlayerItem:playerItem];
        
        [remotePlayer setDelegate:self];
        [remotePlayer setVolume:[self volume]];
        [remotePlayer autoplay];
        
        if([url.scheme isEqualToString:@"http"] || [url.scheme isEqualToString:@"https"]) {
            
            [[NSNotificationCenter defaultCenter] addObserver:self 
                                                     selector:@selector(loadStateDidChange:) 
                                                         name:QTMovieLoadStateDidChangeNotification 
                                                       object:remotePlayer];
        }
        
//        else {
//            [remotePlayer performSelector:@selector(play) withObject:nil afterDelay:0.2f]; 
//        }
        
        if(self.currentTrack.isVideo) {
            [[NSNotificationCenter defaultCenter] postNotificationName:SBPlayerMovieToPlayNotification 
                                                                object:remotePlayer];
            
        }
    }
*/
}

- (void)playLocalWithURL:(NSURL *)url {
    
    AudioDecoder *decoder = AudioDecoder::CreateDecoderForURL(reinterpret_cast<CFURLRef>(url));
	if(NULL != decoder) {
        
        LOCAL_PLAYER->SetVolume([self volume]);
        
        // Register for rendering started/finished notifications so the UI can be updated properly
        decoder->SetDecodingStartedCallback(decodingStarted, self);
        decoder->SetRenderingFinishedCallback(renderingFinished, self);
        
        if(decoder->Open() && LOCAL_PLAYER->Enqueue(decoder)) {
            //[[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:url];
        }else {
            delete decoder;
        }
    } else {
        NSLog(@"Couldn't decode file");
    }
}


- (void)playPause {
    /*
    if((remotePlayer != nil) && ([remotePlayer rate] != 0)) {
        [remotePlayer stop];
    } else {
        [remotePlayer play];
    }
    */
    if(LOCAL_PLAYER && LOCAL_PLAYER->GetPlayingURL() != NULL) {
        LOCAL_PLAYER->PlayPause();
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
    
/*
    if(remotePlayer)
        [remotePlayer setVolume:volume];
*/
    
    LOCAL_PLAYER->SetVolume(volume);
}


- (void)seek:(double)time {
    /*
    if(remotePlayer != nil) {
        NSTimeInterval duration;
        QTGetTimeInterval([remotePlayer duration], &duration);    
        double newSeekTime = (time / 100.0) * duration;     
        QTTime qtTime = QTMakeTimeWithTimeInterval(newSeekTime);
        
        [remotePlayer setCurrentTime:qtTime];
    }
    */
    
    if(LOCAL_PLAYER && LOCAL_PLAYER->IsPlaying()) {
        SInt64 totalFrames;
        if(LOCAL_PLAYER->SupportsSeeking()) {
            if(LOCAL_PLAYER->GetTotalFrames(totalFrames)) {
                //NSLog(@"seek");
                SInt64 desiredFrame = static_cast<SInt64>((time / 100.0) * totalFrames);
                LOCAL_PLAYER->SeekToFrame(desiredFrame);
            }   
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
/*
        if(remotePlayer) {
            [remotePlayer stop];
            [remotePlayer release];
            remotePlayer = nil;
        }
*/
        
        if(LOCAL_PLAYER->IsPlaying()) {
            LOCAL_PLAYER->Stop();
            LOCAL_PLAYER->ClearQueuedDecoders();
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
    
/*
    if(remotePlayer != nil)
    {
        NSTimeInterval currentTime; 
        QTGetTimeInterval([remotePlayer currentTime], &currentTime);
        
        return [NSString stringWithTime:currentTime];
    }
*/
    
    if(LOCAL_PLAYER->IsPlaying())
    {
        SInt64 currentFrame, totalFrames;
        CFTimeInterval currentTime, totalTime;
        
        if(LOCAL_PLAYER->GetPlaybackPositionAndTime(currentFrame, totalFrames, currentTime, totalTime)) {
            return [NSString stringWithTime:currentTime];
        }
    }
    
    return nil;
}

- (NSString *)remainingTimeString {
    
/*
    if(remotePlayer != nil)
    {
        NSTimeInterval currentTime; 
        NSTimeInterval duration;
        
        QTGetTimeInterval([remotePlayer duration], &duration);
        QTGetTimeInterval([remotePlayer currentTime], &currentTime);
        
        NSTimeInterval remainingTime = duration-currentTime;
        return [NSString stringWithTime:-remainingTime];
    }
*/
    
    if(LOCAL_PLAYER->IsPlaying())
    {
        SInt64 currentFrame, totalFrames;
        CFTimeInterval currentTime, totalTime;
        
        if(LOCAL_PLAYER->GetPlaybackPositionAndTime(currentFrame, totalFrames, currentTime, totalTime)) {
            return [NSString stringWithTime:(-1 * (totalTime - currentTime))];
        }
    }
    
    return nil;
}

- (double)progress {
    
/*
    if(remotePlayer != nil)
    {
        // typedef struct { long long timeValue; long timeScale; long flags; } QTTime
        QTTime qtCurrentTime = [remotePlayer currentTime];
        QTTime qtDuration    = [remotePlayer duration];

        long long currentTime = qtCurrentTime.timeValue;
        long long duration = qtDuration.timeValue;
        
        
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
*/
    
    if(LOCAL_PLAYER->IsPlaying())
    {
        SInt64 currentFrame, totalFrames;
        CFTimeInterval currentTime, totalTime;
        
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
    }
    
    return 0;
}


- (float)volume {
    return [[NSUserDefaults standardUserDefaults] floatForKey:@"playerVolume"];
}

- (double)percentLoaded {
    double percentLoaded = 0;
    
/*
    if(remotePlayer != nil) {
        NSTimeInterval tMaxLoaded;
        NSTimeInterval tDuration;
        
        QTGetTimeInterval([remotePlayer duration], &tDuration);
        QTGetTimeInterval([remotePlayer maxTimeLoaded], &tMaxLoaded);
        
        percentLoaded = (double) tMaxLoaded/tDuration;
    }
*/
    
    if(LOCAL_PLAYER->IsPlaying()) {
        percentLoaded = 1;
    }
    
    return percentLoaded;
}




#pragma mark -
#pragma mark Remote Player Notification 

- (void)loadStateDidChange:(NSNotification *)notification {
    NSError *error = nil;
    
/*
    // First make sure that this notification is for our movie.
    if([notification object] == remotePlayer)
    {
        QTMovieLoadState state = [[remotePlayer attributeForKey:QTMovieLoadStateAttribute] integerValue];
        
        
        if (state >= QTMovieLoadStateComplete) { // 100000L
            
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
            
        } else if (state >= QTMovieLoadStatePlayable) { // 10000L
            //[remotePlayer play];
            
        } else if (state >= QTMovieLoadStateLoaded) { // 2000L
            
        } else if (state >= QTMovieLoadStateLoading) { // 1000L
            
        } else if (state == -1) { // -1L
            [self stop];
            
            NSError *error = [remotePlayer attributeForKey:QTMovieLoadStateErrorAttribute];
            if(error) [NSApp presentError:error];
            
        }
    }
*/
}

- (void)movieDidEnd:(NSNotification *)notification {
  
/*  
    if([notification object] == remotePlayer) //if the player is our player
    {
        if([remotePlayer rate] > 0) // really playing
        {   
            
        }
    }
*/
}

- (void) decodingStarted:(const AudioDecoder *)decoder
{
    #pragma unused(decoder)
	LOCAL_PLAYER->Play();
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
