//
//  NSString+File.m
//  Submariner
//
//  Created by Calvin Buckley on 2022-09-27.
//  Copyright © 2022 Calvin Buckley. All rights reserved.
//

#import "NSString+File.h"

@implementation NSString (File)

- (BOOL) isValidFileName {
    if ([self isEqualToString: @""]) {
        return NO;
    }
    static NSCharacterSet* illegalFileNameCharacters = nil;
    if (illegalFileNameCharacters == nil) {
        illegalFileNameCharacters = [NSCharacterSet characterSetWithCharactersInString:@"/\\?%*|\"<>"];
    }
    NSRange range = [self rangeOfCharacterFromSet: illegalFileNameCharacters];
    return range.location == NSNotFound;
}

- (NSString*)extensionForMIMEType {
    CFStringRef fileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)self, NULL);
    CFStringRef extension = UTTypeCopyPreferredTagWithClass(fileUTI, kUTTagClassFilenameExtension);
    CFRelease(fileUTI);
    if (extension != nil) {
        return (__bridge NSString*)extension;
    }
    return nil;
}

@end
