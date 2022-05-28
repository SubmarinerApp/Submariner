//
//  SBRepeatIconTransformer.m
//  Submariner
//
//  Created by Calvin Buckley on 2022-05-15.
//  Copyright © 2022 Calvin Buckley. All rights reserved.
//

#import "SBRepeatIconTransformer.h"

@implementation SBRepeatIconTransformer


+ (Class)transformedValueClass {
    return [NSImage class];
}

+ (BOOL)allowsReverseTransformation {
    return NO;
}

- (id)transformedValue:(id)value {
    SBPlayerRepeatMode repeatMode = (SBPlayerRepeatMode)[value integerValue];
    NSString *name, *desc;
    if (repeatMode == SBPlayerRepeatNo) {
        // XXX: Make it tinted instead
        name = @"repeat.circle";
        desc = @"Not Repeating";
    } else if (repeatMode == SBPlayerRepeatOne) {
        name = @"repeat.1.circle.fill";
        desc = @"Repeat One";
    } else if (repeatMode == SBPlayerRepeatAll) {
        name = @"repeat.circle.fill";
        desc = @"Repeat All";
    }
    return [NSImage imageWithSystemSymbolName: name accessibilityDescription: desc];
}

@end
