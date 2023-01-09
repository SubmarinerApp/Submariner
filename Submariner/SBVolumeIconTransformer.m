//
//  SBVolumeIconTransformer.m
//  Submariner
//
//  Created by Calvin Buckley on 2022-05-14.
//  Copyright © 2022 Calvin Buckley. All rights reserved.
//

#import "SBVolumeIconTransformer.h"

@implementation SBVolumeIconTransformer


+ (Class)transformedValueClass {
    return [NSImage class];
}

+ (BOOL)allowsReverseTransformation {
    return NO;
}

- (id)transformedValue:(id)value {
    float f = [value floatValue];
    if (f <= 0.0) {
        return [NSImage imageWithSystemSymbolName: @"speaker.slash" accessibilityDescription: @"Muted"];
    }
    NSString *name = @"speaker.badge.exclamationmark", *desc;
    desc = f == 0.0 ? @"Muted" : [NSString stringWithFormat: @"%f",f];
    if (@available(macOS 13.0.0, *)) {
        return [NSImage imageWithSystemSymbolName: @"speaker.wave.3" variableValue: f accessibilityDescription: desc];
    } else {
        if (f >= 0.66) {
            name = @"speaker.wave.3";
        } else if (f >= 0.33) {
            name = @"speaker.wave.2";
        } else if (f > 0.0) {
            name = @"speaker.wave.1";
        }
        // XXX: Percentage format?
        return [NSImage imageWithSystemSymbolName: name accessibilityDescription: desc];
    }
}


@end
