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


#import "SBAlbum.h"
#import "SBCover.h"


@implementation SBAlbum

#pragma mark -
#pragma mark IKImageBrowserItem

- (NSString *) imageTitle {
    NSString *result = nil;
    
    [self willAccessValueForKey:@"albumName"];
    result = self.itemName;
    [self didAccessValueForKey:@"albumName"];
    
    return result;
}

- (NSString *) imageUID {
    NSString *result = nil;
    
    [self willAccessValueForKey:@"albumName"];
    result = self.itemName;
    [self didAccessValueForKey:@"albumName"];
    
    return result;
}

- (NSString *) imageRepresentationType {
    // XXX: Can't use IKImageBrowserPathRepresentationType because [SBTrack coverImage] calls imageRepresentation.
    return IKImageBrowserNSImageRepresentationType;
}

- (id) imageRepresentation {
    // XXX: Cache.
    if (self.cover && self.cover.imagePath) {
        return [[NSImage alloc] initByReferencingFile:self.cover.imagePath];
    }
    // For the no artwork case, avoid having to constantly spawn it in.
    static NSImage *nullImage = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        nullImage = [NSImage imageNamed:@"NoArtwork"];
    });
    return nullImage;
}

- (void)setImageRepresentation:(id)image {
    // do nothing
    [self willChangeValueForKey:@"imageRepresentation"];
    
    [self didChangeValueForKey:@"imageRepresentation"];
}

- (NSUInteger) imageVersion {
    // Avoid constructing an image. I think this is only really used to check if it's loaded,
    // since the album artwork shouldn't change normally (and if it does, rare it'll be the same size).
    // XXX: Better method.
    NSString *path = self.cover.imagePath;
    NSDictionary<NSFileAttributeKey, id>* attribs = [[NSFileManager defaultManager] attributesOfItemAtPath: path error: nil];
    if (attribs == nil) {
        return 0;
    }
    return [attribs fileSize];
}


@end
