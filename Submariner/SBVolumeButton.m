//
//  SBVolumeButton.m
//  Submariner
//
//  Created by Calvin Buckley on 2022-06-12.
//  Copyright © 2022 Calvin Buckley. All rights reserved.
//

#import "SBVolumeButton.h"
#import "SBPlayer.h"

@implementation SBVolumeButton

- (void)scrollWheel:(NSEvent *)event {
    // The trackpad gives us a (-)8 or so and slowly returns to zero.
    // Haven't tested wheel.
    float delta = event.deltaY * 0.01;
    if (delta == 0.0) {
        return;
    }
    float newVolume = [[SBPlayer sharedInstance] volume] + delta;
    newVolume = MIN(1.0f, newVolume);
    newVolume = MAX(0.0f, newVolume);
    [[SBPlayer sharedInstance] setVolume: newVolume];
    // XXX: Display volume in popover/tooltip.
}

@end
