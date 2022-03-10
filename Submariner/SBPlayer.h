//
//  SBPlayer.h
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

#import <Foundation/Foundation.h>

#if __cplusplus
#include <SFBAudioEngine/SFBAudioPlayer.h>
#endif

// notifications
extern NSString *SBPlayerPlaylistUpdatedNotification;
extern NSString *SBPlayerMovieToPlayNotification;



// repeat modes
enum SBPlayerRepeatMode {
    SBPlayerRepeatNo    = 0, // no repeat
    SBPlayerRepeatOne   = 1, // repeat the current track 
    SBPlayerRepeatAll   = 2  // repeat the current playlist
} typedef SBPlayerRepeatMode;




@class SBTrack;


@interface SBPlayer : NSObject <NSSoundDelegate> {
@private
/*
   AVAsset       *remotePlayerAsset;
   AVPlayerItem  *remotePlayerItem;
   AVPlayer      *remotePlayer;
*/
   void          *localPlayer;
    
    NSMutableArray *playlist;
    SBTrack *currentTrack;
    NSString *tmpLocation;
    
    SBPlayerRepeatMode repeatMode; // the player repeat mode
    BOOL isShuffle;
    BOOL isPlaying;
    BOOL isPaused;
    
    BOOL isCaching;
}

@property (readwrite, retain) NSMutableArray *playlist;
@property (readwrite, retain) SBTrack *currentTrack;
@property (readwrite) BOOL isShuffle;
@property (readwrite) BOOL isPlaying;
@property (readwrite) BOOL isPaused;
@property (readwrite) SBPlayerRepeatMode repeatMode;

+ (SBPlayer*)sharedInstance;

// manage player tracklist
- (void)addTrack:(SBTrack *)track replace:(BOOL)replace;
- (void)addTrackArray:(NSArray *)array replace:(BOOL)replace;
- (void)removeTrack:(SBTrack *)track;
- (void)removeTrackArray:(NSArray *)tracks;
- (void)clear;

// player controls
- (void)playTrack:(SBTrack *)track;
- (void)playPause;
- (void)next;
- (void)previous;
- (void)seek:(double)time;
- (void)setVolume:(float)volume; // 0.0 - 1.0
- (void)stop; // unplay all tracks

// player data
- (NSString *)currentTimeString;
- (NSString *)remainingTimeString;
- (double)progress;
- (double)percentLoaded;
- (float)volume; // 0.0 - 1.0

@end
