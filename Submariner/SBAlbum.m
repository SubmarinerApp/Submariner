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


- (void)awakeFromInsert {
//    if(self.cover == nil) {
//        [self setCover:[SBCover insertInManagedObjectContext:self.managedObjectContext]];
//    }
}


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
    return IKImageBrowserNSImageRepresentationType;
}

- (id) imageRepresentation {
    NSImage *image = [NSImage imageNamed:@"NoArtwork"];
    
    if(self.cover && self.cover.imagePath) {
        image = [[NSImage alloc] initByReferencingFile:self.cover.imagePath];
    } 
    return image;
}

- (void)setImageRepresentation:(id)image {
    // do nothing
    [self willChangeValueForKey:@"imageRepresentation"];
    
    [self didChangeValueForKey:@"imageRepresentation"];
}

- (NSUInteger) imageVersion {
    NSImage *image = [NSImage imageNamed:@"NoArtwork"];
    NSInteger length = 0;
    
    if(self.cover && self.cover.imagePath) {
        image = [[NSImage alloc] initByReferencingFile:self.cover.imagePath];
    } 
    
    length = [[image TIFFRepresentation] length];
    
    return length;
}


@end
