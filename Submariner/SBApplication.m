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
#import "SBPlayer.h"
#import "SBImageBrowserView.h"


@interface SBApplication ()
@end



@implementation SBApplication


// init NSUserDefaults defaults settings (first launch)
+ (void)initialize {
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	NSMutableDictionary *defaults = [[NSMutableDictionary alloc] init];
	
	[defaults setObject:@"submariner" forKey:@"clientIdentifier"];
    [defaults setObject:@"1.5.0" forKey:@"apiVersion"];
    
    [defaults setObject:[NSNumber numberWithInt:1]              forKey:@"playerBehavior"];
	[defaults setObject:[NSNumber numberWithFloat:0.5f]         forKey:@"playerVolume"];
	[defaults setObject:[NSNumber numberWithInt:SBPlayerRepeatNo]         forKey:@"repeatMode"];
	[defaults setObject:[NSNumber numberWithInt:NO]         forKey:@"shuffle"];
    [defaults setObject:[NSNumber numberWithInt:YES]            forKey:@"enableCacheStreaming"];
    [defaults setObject:[NSNumber numberWithInt:NO]             forKey:@"autoRefreshNowPlaying"];
    [defaults setObject:[NSNumber numberWithFloat:0.75]         forKey:@"coverSize"];
    [defaults setObject:[NSNumber numberWithInteger:0]          forKey:@"maxBitRate"];
    [defaults setObject:[NSNumber numberWithInteger:300]        forKey:@"MaxCoverSize"];
    [defaults setObject:[NSNumber numberWithBool:YES]           forKey:@"scrobbleToServer"];
    [defaults setObject:[NSNumber numberWithBool:NO]            forKey:@"deleteAfterPlay"];
    [defaults setObject:[NSNumber numberWithFloat:5.0]          forKey:@"SkipIncrement"];
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


// https://stackoverflow.com/a/32246600
- (void)sendEvent:(NSEvent *)anEvent
{
    [super sendEvent:anEvent];
    switch ([anEvent type]) {
        case NSEventTypeKeyDown:
        if (([anEvent keyCode] == 49) && (![anEvent isARepeat])) {
            // only trigger if we're not in something editing shaped,
            // where space does something the user expects
            NSResponder *firstResponder = anEvent.window.firstResponder;
            // oddly IKImageBrowserViews trigger here too
            if ([firstResponder isKindOfClass: NSText.class] || [firstResponder isKindOfClass: SBImageBrowserView.class]) {
                break;
            }
            NSPoint pt; pt.x = pt.y = 0;
            NSEvent *fakeEvent = [NSEvent keyEventWithType:NSEventTypeKeyDown
                                                  location:pt
                                             modifierFlags:0
                                                 timestamp:[[NSProcessInfo processInfo] systemUptime]
                                              windowNumber: 0 // self.windowNumber
                                                   context:[NSGraphicsContext currentContext]
                                                characters:@" "
                               charactersIgnoringModifiers:@" "
                                                 isARepeat:NO
                                                   keyCode:49];
            [[NSApp mainMenu] performKeyEquivalent:fakeEvent];
        }
        break;

    default:
        break;
    }
}

@end
