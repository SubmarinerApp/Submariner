//
//  SBWindowController.m
//  Sub
//
//  Created by Rafaël Warnault on 14/05/11.
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

#import "SBWindowController.h"


@interface SBWindowController ()
- (void)_enableLayer;
- (void)_disableLayer;
- (void)_showVisualCue;
- (void)_hideVisualCue;
@end

@implementation SBWindowController

@synthesize managedObjectContext;


#pragma mark -
#pragma mark Class Methods

+ (NSString *)nibName
{
    return nil;
}



#pragma mark -
#pragma mark Instance Methods

- (id)initWithManagedObjectContext:(NSManagedObjectContext *)context {
    self = [super initWithWindowNibName:[[self class] nibName]];
    if (self) {
        managedObjectContext = context;
    }
    return self;
}


- (void)showVisualCue {
//    [self performSelector:@selector(_enableLayer) withObject:nil afterDelay:0.0f];
//    [self performSelector:@selector(_showVisualCue) withObject:nil afterDelay:0.2f];
}

- (void)hideVisualCue {
//    [self performSelector:@selector(_hideVisualCue) withObject:nil afterDelay:0.0f];
//    [self performSelector:@selector(_disableLayer) withObject:nil afterDelay:0.0f];
}



- (void)_showVisualCue {
    CATransition *animation = [CATransition animation];
	[animation setType:kCATransitionFade];
	[[[[self window] contentView] layer] addAnimation:animation forKey:@"layerAnimation"];
    
	blankingView = [[NSView alloc] initWithFrame:[[[self window] contentView] frame]];
	[[[self window] contentView] addSubview:blankingView];
    
    CIFilter *exposureFilter = [CIFilter filterWithName:@"CIExposureAdjust"];
    [exposureFilter setDefaults];
	[exposureFilter setValue:[NSNumber numberWithDouble:-1.25] forKey:@"inputEV"];
    CIFilter *saturationFilter = [CIFilter filterWithName:@"CIColorControls"];
    [saturationFilter setDefaults];
	[saturationFilter setValue:[NSNumber numberWithDouble:0.35] forKey:@"inputSaturation"];
    CIFilter *gloomFilter = [CIFilter filterWithName:@"CIGloom"];
    [gloomFilter setDefaults];
	[gloomFilter setValue:[NSNumber numberWithDouble:0.1] forKey:@"inputIntensity"];
	
    [[blankingView layer] setBackgroundFilters:[NSArray arrayWithObjects:exposureFilter, saturationFilter, gloomFilter, nil]];    
}

- (void)_hideVisualCue {
    CATransition *animation = [CATransition animation];
	[animation setType:kCATransitionFade];
	[[[[self window] contentView] layer] addAnimation:animation forKey:@"layerAnimation"];
    
	[blankingView removeFromSuperview];
	blankingView = nil;
}

- (void)_enableLayer {
    [[[self window] contentView] setWantsLayer:YES];
}

- (void)_disableLayer {
    [[[self window] contentView] setWantsLayer:NO];
}

@end
