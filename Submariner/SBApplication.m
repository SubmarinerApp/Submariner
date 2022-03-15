//
//  SBApplication.m
//  Submariner
//
//  Created by Rafaël Warnault on 15/06/11.
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

#import "SBApplication.h"
#import "SBAppDelegate.h"
#import <IOKit/hidsystem/ev_keymap.h>



@interface SBApplication ()
- (void)mediaKeyEvent:(int)key state:(BOOL)state;
@end



@implementation SBApplication


// init NSUserDefaults defaults settings (first launch)
+ (void)initialize {
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	NSMutableDictionary *defaults = [[[NSMutableDictionary alloc] init] autorelease];
	
	[defaults setObject:@"submariner" forKey:@"clientIdentifier"];
    [defaults setObject:@"1.5.0" forKey:@"apiVersion"];
    
    [defaults setObject:[NSNumber numberWithInt:1]              forKey:@"playerBehavior"];
	[defaults setObject:[NSNumber numberWithFloat:0.5f]         forKey:@"playerVolume"];
    [defaults setObject:[NSNumber numberWithInt:30]             forKey:@"requestTimeout"];
    [defaults setObject:[NSNumber numberWithInt:YES]            forKey:@"jumpInDock"];
    [defaults setObject:[NSNumber numberWithInt:YES]            forKey:@"dockBadges"];
    [defaults setObject:[NSNumber numberWithInt:YES]            forKey:@"enableCacheStreaming"];
    [defaults setObject:[NSNumber numberWithInt:NO]             forKey:@"autoRefreshNowPlaying"];
    [defaults setObject:[NSNumber numberWithFloat:0.75]         forKey:@"coverSize"];
    [defaults setObject:[NSNumber numberWithInteger:0]          forKey:@"maxBitRate"];
    [defaults setObject:[NSNumber numberWithInteger:300]        forKey:@"MaxCoverSize"];
    [defaults setObject:[NSNumber numberWithInteger:67]         forKey:@"PlayerKeyCode"];
    [defaults setObject:[NSNumber numberWithInteger:1572864]    forKey:@"PlayerKeyFlags"];
	[userDefaults registerDefaults:defaults];
}


- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}


/**
 * Listen media key event from Apple Keyboard
 */
- (void)sendEvent:(NSEvent *)event {
    // Catch media key events
    if ([event type] == NSSystemDefined && [event subtype] == 8) {
        
        int keyCode = (([event data1] & 0xFFFF0000) >> 16);
        int keyFlags = ([event data1] & 0x0000FFFF);
        int keyState = (((keyFlags & 0xFF00) >> 8)) == 0xA;
                
        [self mediaKeyEvent:keyCode state:keyState];
        return;
    }
    
    // Continue on to super
    [super sendEvent:event];
}


/**
 * Treat the media key event
 */
- (void)mediaKeyEvent:(int)key state:(BOOL)state {
    switch (key) {
        // Play pressed
        case NX_KEYTYPE_PLAY:
            
            if (state == NO)
                [(SBAppDelegate *)[self delegate] playPause:self];
            
            break;
            
        // Rewind
        case NX_KEYTYPE_FAST:
            if (state == YES)
                [(SBAppDelegate *)[self delegate] nextTrack:self];
            
            break;
            
        // Previous
        case NX_KEYTYPE_REWIND:
            if (state == YES)
                [(SBAppDelegate *)[self delegate] previousTrack:self];
            
            break;
            
    }
    
}

@end
