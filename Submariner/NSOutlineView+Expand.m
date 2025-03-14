//
//  NSOutlineView+Expand.m
//  Submariner
//
//  Created by Rafaël Warnault on 06/06/11.
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

#import "NSOutlineView+Expand.h"




@interface NSOutlineView (PrivateHelper)
- (void)_expandAllItems;
- (void)_expandURIs:(NSArray *)someURIs;
- (void)_reloadURIs:(NSArray *)someURIs;
@end





@implementation NSOutlineView (Expand)

- (void)expandAllItems {
    [self performSelector:@selector(_expandAllItems) withObject:nil afterDelay:0.0f];
}

- (void)expandURIs:(NSArray *)someURIs {
    [self performSelector:@selector(_expandURIs:) withObject:someURIs afterDelay:0.0f];
}

- (void)reloadURIs:(NSArray *)someURIs {
    [self _reloadURIs:someURIs];
}

@end





@implementation NSOutlineView (PrivateHelper)

- (void)_expandAllItems {
    [self expandItem:nil expandChildren:YES];
}


- (void)_expandURIs:(NSArray *)someURIs {
    
    //Get items from the preferences
    NSMutableArray *notFoundNested = [NSMutableArray array];
    BOOL foundAtLeastOne = NO;
    NSEnumerator *collectionsToExpandEnum = [someURIs objectEnumerator];
    NSString *nextCollectionURI;
    
    while (nextCollectionURI = [collectionsToExpandEnum nextObject]) {
        NSInteger i, numberOfRows = [self numberOfRows];
        BOOL found = NO;

        for (i = 0; i < numberOfRows; i++ ) {
            if ([[[self dataSource] outlineView:self persistentObjectForItem:[self itemAtRow:i]] isEqualToString:nextCollectionURI]) {
                
                [self expandItem:[self itemAtRow:i]];
                foundAtLeastOne = YES;
                found = YES;
                break;
            }
        }
        
        if (found == NO) {
            [notFoundNested addObject:nextCollectionURI];
        }
    }
    
    if (foundAtLeastOne && [notFoundNested count])
        [self expandURIs:notFoundNested];
}


- (void)_reloadURIs:(NSArray *)someURIs {
    
    //Get items from the preferences
    NSMutableArray *notFoundNested = [NSMutableArray array];
    BOOL foundAtLeastOne = NO;
    NSEnumerator *collectionsToExpandEnum = [someURIs objectEnumerator];
    NSString *nextCollectionURI;
    
    while (nextCollectionURI = [collectionsToExpandEnum nextObject]) {
        NSInteger i, numberOfRows = [self numberOfRows];
        BOOL found = NO;
        
        for (i = 0; i < numberOfRows; i++ ) {
            
            if ([[[self dataSource] outlineView:self
                      persistentObjectForItem:[self itemAtRow:i]] isEqualToString:nextCollectionURI]) {
                
                [self reloadItem:[self itemAtRow:i] reloadChildren:YES];
                foundAtLeastOne = YES;
                found = YES;
                break;
            }
        }
        
        if (found == NO) {
            [notFoundNested addObject:nextCollectionURI];
        }
    }
    
    if (foundAtLeastOne && [notFoundNested count])
        [self reloadURIs:notFoundNested];
}



@end
