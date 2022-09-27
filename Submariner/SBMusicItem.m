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


#import "SBMusicItem.h"
#import "SBArtist.h"
#import "SBAppDelegate.h"

@implementation SBMusicItem
 
// Cover overrides imagePath, but this applies to Track/Episode/Artist/Album,
// which exist when they're a local item. Make relative, but unlike Cover, don't
// move, since we might not be the owners of it. (It does make the "user moved
// the path" case more annoying though, but local items can always be destroyed
// and recreated easily.
- (NSString *)path {
    [self willAccessValueForKey:@"path"];
    NSString *string = [self primitivePath];
    if (string && [string isAbsolutePath]) {
        // If absolute path is in music dir, correct it.
        NSString *libraryDir = [[SBAppDelegate sharedInstance] musicDirectory];
        if ([string hasPrefix: libraryDir]) {
            NSUInteger offset = [libraryDir length] + ([libraryDir hasSuffix: @"/"] ? 0 : 1);
            NSString *trimmedPrefix = [string substringFromIndex: offset];
            [self setPrimitivePath: trimmedPrefix];
        }
    } else if (string) {
        // Relative, but return the full directory.
        NSString *libraryDir = [[SBAppDelegate sharedInstance] musicDirectory];
        string = [libraryDir stringByAppendingPathComponent: string];
    }
    [self didAccessValueForKey:@"path"];
    return string;
}

@end
