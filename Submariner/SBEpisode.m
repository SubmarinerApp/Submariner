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


#import "SBEpisode.h"
#import "NSString+Time.h"
#import "NSString+Hex.h"
#import "SBServer.h"
#import "SBPodcast.h"


@implementation SBEpisode

@synthesize statusImage;

- (NSImage *)statusImage {
    NSImage *result = [NSImage imageNamed:@"pending"];
    
    if([self.episodeStatus isEqualToString:@"new"] || [self.episodeStatus isEqualToString:@"completed"])
        result = [NSImage imageNamed:@"on"];
    
    if([self.episodeStatus isEqualToString:@"downloading"] || [self.episodeStatus isEqualToString:@"skipped"])
        result = [NSImage imageNamed:@"pending"];
    
    if([self.episodeStatus isEqualToString:@"error"] || [self.episodeStatus isEqualToString:@"deleted"])
        result = [NSImage imageNamed:@"off"];
    
    return result;
}


- (NSURL *)streamURL {
    NSMutableString *params = nil;
    NSURL *finalURL = nil;
    
    // the default URL parameters
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    [self.server getBaseParameters: parameters];
    [parameters setValue:self.streamID forKey:@"id"];
    
    finalURL = [NSURL URLWithString:[self.server.url stringByAppendingPathComponent:@"rest/stream.view"]];
    
    if (parameters != nil)
    {
        params = [[NSMutableString alloc] init];
        for (id key in parameters)
        {
            NSString *encodedKey = [key stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            CFStringRef value = (CFStringRef)[[parameters objectForKey:key] copy];
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
    [parameters setValue:self.streamID forKey:@"id"];
    
    finalURL = [NSURL URLWithString:[self.server.url stringByAppendingPathComponent:@"rest/download.view"]];
    
    if (parameters != nil)
    {
        params = [[NSMutableString alloc] init];
        for (id key in parameters)
        {
            NSString *encodedKey = [key stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            CFStringRef value = (CFStringRef)[[parameters objectForKey:key] copy];
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


- (NSString *)artistString {
    return self.podcast.itemName;
}

- (NSString *)albumString {
    return self.episodeDescription;
}

@end
