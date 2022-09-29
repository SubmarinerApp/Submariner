//
//  NSData+Type.m
//  Submariner
//
//  Created by Calvin Buckley on 2022-09-29.
//  Copyright © 2022 Calvin Buckley. All rights reserved.
//

#import "NSData+Type.h"

@implementation NSData (Type)

// Not ideal, but it's a way to guess without having to encode a bunch of magic numbers ourselves,
// since we only care about images, and SFBAudioEngine won't give us the type.
- (NSString*)guessImageUTI {
    CGImageSourceRef imgSrc = CGImageSourceCreateWithData((CFDataRef)self, NULL);
    if (imgSrc == NULL) {
        return nil;
    }
    NSString *str = (__bridge_transfer NSString*)CGImageSourceGetType(imgSrc);
    CFRelease(imgSrc);
    return str;
}
@end
