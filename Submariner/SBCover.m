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


#import "SBArtist.h"
#import "SBAlbum.h"
#import "SBCover.h"
#import "SBTrack.h"
#import "SBServer.h"

#import "SBAppDelegate.h"

@implementation SBCover

// We don't have a relationship directly with SBServer, but we can ask our relatives
- (SBServer*) server {
    if (self.album != nil && self.album.artist != nil) {
        return self.album.artist.server;
    } else if (self.track != nil) {
        return self.track.server;
    }
    return nil;
}

- (NSString*) coversDir: (NSString*)coverDir {
    SBServer *server = self.server;
    NSString *append = nil;
    if (server != nil) {
        append = server.resourceName;
    } else if (self.isLocalValue == YES
               || (self.track && self.track.isLocalValue == YES && self.track.server)
               || (self.album && self.album.isLocalValue == YES && self.album.artist && self.album.artist.server)) {
        // For imported media.
        // XXX: local import doesn't set local attrib on covers yet,
        // but not super important if track or album have it
        append = @"Local Library";
    } else {
        return nil;
    }
    return [coverDir stringByAppendingPathComponent: append];
}

// This is overriden so that consumers don't need to handle the difference
// between absolute and relative paths themselves. Ideally, the relative path
// is stored (for portability), and the absolute path provides for any consumers
// needing to load the file. By overriding the getter, we reduce refactoring.
//
// XXX: Migrate absolute resources to relative ones on-demand here
// XXX: Why is there a difference between MusicItem.path and Cover.imagePath?
- (NSString*)imagePath {
    [self willAccessValueForKey: @"imagePath"];
    NSString *baseCoverDir = [[SBAppDelegate sharedInstance] coverDirectory];
    NSString *currentPath = self.primitiveImagePath;
    if (currentPath == nil) {
        [self didAccessValueForKey: @"imagePath"];
        return currentPath;
    } else if ([currentPath isAbsolutePath]) {
        NSString *coversDir = [self coversDir: baseCoverDir];
        if (coversDir == nil) {
            [self didAccessValueForKey: @"imagePath"];
            return currentPath;
        }
        // If the path matches the prefix, do it, otherwise move the file
        if ([currentPath hasPrefix: coversDir]) {
            // Prefix matches, just update the DB entry
            NSString *fileName = [currentPath lastPathComponent];
            [self setImagePath: fileName];
            [self didAccessValueForKey: @"imagePath"];
            return currentPath;
        } else if ([currentPath hasPrefix: baseCoverDir]) {
            // in case it gets horribly lost (XXX: still need after real fix?)
            [self didAccessValueForKey: @"imagePath"];
            return currentPath;
        } else {
            // Prefix doesn't match, move instead
            NSString *fileName = [currentPath lastPathComponent];
            NSString *newPath = [coversDir stringByAppendingPathComponent: fileName];
            NSError *error = nil;
            // XXX: Synchronization? Only success will update tho
            if ([[NSFileManager defaultManager] moveItemAtPath: currentPath toPath: newPath error: &error]) {
                [self setImagePath: fileName];
                [self didAccessValueForKey: @"imagePath"];
                return newPath;
            } else {
                NSLog(@"Error when moving file out of dir into dir: %@", error);
                [self didAccessValueForKey: @"imagePath"];
                return currentPath;
            }
        }
    } else {
        NSString *coversDir = [self coversDir: baseCoverDir];
        [self didAccessValueForKey: @"imagePath"];
        if (coversDir == nil) {
            return currentPath;
        }
        return [coversDir stringByAppendingPathComponent: currentPath];
    }
}

@end
