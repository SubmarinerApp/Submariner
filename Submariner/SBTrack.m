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


#import "SBTrack.h"
#import "SBArtist.h"
#import "SBServer.h"
#import "SBCover.h"
#import "SBAlbum.h"
#import "NSURL+Parameters.h"
#import "NSString+Time.h"
#import "NSString+Hex.h"


@implementation SBTrack


@synthesize durationString;
@synthesize artistString;
@synthesize albumString;
@synthesize playingImage;
@synthesize coverImage;
@synthesize onlineImage;
@dynamic movieAttributes;



+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
    NSSet *result = nil;
    if([key isEqualToString:@"durationString"]) {
        result = [NSSet setWithObjects:@"duration", nil];
    }
    if([key isEqualToString:@"playingImage"]) {
        result = [NSSet setWithObjects:@"isPlaying", nil];
    }
    if([key isEqualToString:@"onlineImage"]) {
        result = [NSSet setWithObjects:@"isLocal", nil];
    }
    return result;
}

- (void)awakeFromInsert {
    if(self.cover == nil) {
        [self setCover:[SBCover insertInManagedObjectContext:self.managedObjectContext]];
    }
}


- (NSString *)durationString {
    NSString *string = nil;
    
    [self willAccessValueForKey:@"duration"];
    string = [NSString stringWithTime:[self.duration intValue]];
    [self didAccessValueForKey:@"duration"];
    
    return string;
}

- (NSURL *)streamURL {
    
    if([self.isLocal boolValue]) {
        return [NSURL fileURLWithPath:self.path];
        
    } else if(self.localTrack != nil) {
        return [NSURL fileURLWithPath:self.localTrack.path];
        
    }
    
    NSMutableString *params = nil;
    NSURL *finalURL = nil;
    
    // the default URL parameters
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    [self.server getBaseParameters: parameters];
    [parameters setValue:[[NSUserDefaults standardUserDefaults] stringForKey:@"maxBitRate"] forKey:@"maxBitRate"];
    [parameters setValue:self.id forKey:@"id"];
    
    finalURL = [NSURL URLWithString:[self.server.url stringByAppendingPathComponent:@"rest/stream.view"]];
    
    if (parameters != nil)
    {
        params = [[NSMutableString alloc] init];
        for (id key in parameters)
        {
            NSString *encodedKey = [key stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            CFStringRef value = (CFStringRef)CFBridgingRetain([[parameters objectForKey:key] copy]);
            // Escape even the "reserved" characters for URLs 
            // as defined in http://www.ietf.org/rfc/rfc2396.txt
            CFStringRef encodedValue = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, 
                                                                               value,
                                                                               NULL, 
                                                                               (CFStringRef)@";?:/@&=+$,", 
                                                                               kCFStringEncodingUTF8);
            [params appendFormat:@"%@=%@&", encodedKey, value];
            CFRelease(value);
            CFRelease(encodedValue);
        }
        [params deleteCharactersInRange:NSMakeRange([params length] - 1, 1)];
    }
    
    if (parameters != nil) {
        NSString *urlWithParams = [[finalURL absoluteString] stringByAppendingFormat:@"?%@", params];
        finalURL = [NSURL URLWithString:urlWithParams];
    }
    
    // check strange missing slash 
    if(finalURL != nil) {
        if([[finalURL absoluteString] rangeOfString:@"://"].location == NSNotFound)
            finalURL = [NSURL URLWithString:[[finalURL absoluteString] stringByReplacingOccurrencesOfString:@":/" withString:@"://"]];
    }
    
    
    return finalURL;
}


- (NSURL *)downloadURL {
    NSMutableString *params = nil;
    NSURL *finalURL = nil;
    
    // the default URL parameters
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    [self.server getBaseParameters: parameters];
    [parameters setValue:self.id forKey:@"id"];
    
    finalURL = [NSURL URLWithString:[self.server.url stringByAppendingPathComponent:@"rest/download.view"]];
    
    if (parameters != nil)
    {
        params = [[NSMutableString alloc] init];
        for (id key in parameters)
        {
            NSString *encodedKey = [key stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            CFStringRef value = (CFStringRef)CFBridgingRetain([[parameters objectForKey:key] copy]);
            // Escape even the "reserved" characters for URLs 
            // as defined in http://www.ietf.org/rfc/rfc2396.txt
            CFStringRef encodedValue = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, 
                                                                               value,
                                                                               NULL, 
                                                                               (CFStringRef)@";?:/@&=+$,", 
                                                                               kCFStringEncodingUTF8);
            [params appendFormat:@"%@=%@&", encodedKey, value];
            CFRelease(value);
            CFRelease(encodedValue);
        }
        [params deleteCharactersInRange:NSMakeRange([params length] - 1, 1)];
    }
    
    if (parameters != nil) {
        NSString *urlWithParams = [[finalURL absoluteString] stringByAppendingFormat:@"?%@", params];
        finalURL = [NSURL URLWithString:urlWithParams];
    }
    
    // check strange missing slash 
    if(finalURL != nil) {
        if([[finalURL absoluteString] rangeOfString:@"://"].location == NSNotFound)
            finalURL = [NSURL URLWithString:[[finalURL absoluteString] stringByReplacingOccurrencesOfString:@":/" withString:@"://"]];
    }
    
    
    return finalURL;
}


- (NSImage *)playingImage {
    if([self.isPlaying boolValue])
        return [NSImage imageWithSystemSymbolName: @"speaker.fill" accessibilityDescription: @"Playing"];
    
    return nil;
}

- (NSImage *)coverImage {
    return [self.album imageRepresentation];
}

- (NSString *)artistString {
    artistString = [self.album.artist itemName];
    
    if(artistString == nil) {
        artistString = self.artistName;
    }
    
    return artistString;
}

- (NSString *)albumString {
    NSString *ret = nil;
    ret = [self.album itemName];
    
    if(ret == nil) {
        ret = self.albumName;
    }
    
    return ret;
}


- (NSImage *)onlineImage {
    if (self.localTrack != nil || self.isLocalValue == YES) {
        return [NSImage imageWithSystemSymbolName: @"bolt.horizontal.fill" accessibilityDescription: @"Cached"];
    } else {
        return [NSImage imageWithSystemSymbolName: @"bolt.horizontal" accessibilityDescription: @"Online"];
    }
}

- (BOOL)isVideo {
    BOOL ret = NO;
    NSLog(@"self.contentType : %@", self.contentType);
    
    if([self.contentType rangeOfString:@"video"].location != NSNotFound)
        ret = YES;
    
    if([self.contentType rangeOfString:@"octet-stream"].location != NSNotFound)
        ret = YES;
    
    if(self.contentType == nil)
        ret = NO;
    
    return ret;
}

- (NSDictionary *)movieAttributes {
    NSLog(@"URL : %@", [self streamURL]);
    return [NSDictionary dictionary];
/*
    return [NSDictionary dictionaryWithObjectsAndKeys:
            [self streamURL], QTMovieURLAttribute,
            [NSNumber numberWithBool:NO], QTMovieOpenForPlaybackAttribute,
            nil];
*/
}

- (NSString *)macOSCompatibleContentType {
    if ([self.contentType isEqualToString:@"audio/x-flac"]) {
        return @"audio/flac";
    }
    
    return self.contentType;
}

@end
