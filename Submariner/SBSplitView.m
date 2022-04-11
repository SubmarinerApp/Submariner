//
//  DXSplitView.m
//  Sub
//
//  Created by Rafaël Warnault on 14/05/11.
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

#import "SBSplitView.h"



@interface SBSplitView (Private) 
- (void)collapseViewAtIndex:(NSInteger)index;
- (void)uncollapseViewAtIndex:(NSInteger)index;
@end


@implementation SBSplitView





#pragma mark -
#pragma mark Action

- (void)toggleViewAtIndex:(NSInteger)index {
	BOOL rightViewCollapsed = [self isSubviewCollapsed:[[self subviews] objectAtIndex:index]];
	if (rightViewCollapsed) {
		[self uncollapseViewAtIndex:index];
	} else {
		[self collapseViewAtIndex:index];
	}
}






#pragma mark -
#pragma mark Private

- (void)collapseViewAtIndex:(NSInteger)index {
	NSView *right = [[self subviews] objectAtIndex:index];
	NSView *left  = [[self subviews] objectAtIndex:index-1];
    NSRect leftFrame = [left frame];
    NSRect rightFrame = [right frame];
        
    [right setHidden:YES];
    [left setFrameSize:NSMakeSize(leftFrame.size.width+[self dividerThickness]+rightFrame.size.width, 
                                  leftFrame.size.height)];
	[self display];
}


-(void)uncollapseViewAtIndex:(NSInteger)index {

    [self setPosition:[self frame].size.width-220 ofDividerAtIndex:index-1];
	[self display];
}





#pragma mark -
#pragma mark NSSplitView Overwrite

//- (CGFloat)dividerThickness {
//    return 1.0f;
//}


- (BOOL)mouseDownCanMoveWindow {
    return YES;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent {
    return YES;
}



- (void)drawDividerInRect:(NSRect)aRect {
    [super drawDividerInRect:aRect];
    
//    if([self isVertical]) {
//        NSRect lightRect = NSMakeRect(aRect.origin.x+1, aRect.origin.y-1, 0.5, aRect.size.height+1);
//        [[NSColor colorWithDeviceWhite:0.8 alpha:1.0] setFill];
//        NSFrameRect(lightRect);
//    } else {
//        NSRect lightRect = NSMakeRect(aRect.origin.x, aRect.origin.y+1, aRect.size.width, 0.5);
//        [[NSColor colorWithDeviceWhite:0.8 alpha:1.0] setFill];
//        NSFrameRect(lightRect);
//    }
}


- (void)mouseUp:(NSEvent *)theEvent {
    if ([NSCursor currentCursor]==[NSCursor resizeLeftCursor] 
        || [NSCursor currentCursor]==[NSCursor resizeRightCursor]
        || [NSCursor currentCursor]==[NSCursor resizeLeftRightCursor]) {
        [super mouseUp:theEvent];
    } 
    
    if ([NSCursor currentCursor]==[NSCursor resizeUpCursor] 
        || [NSCursor currentCursor]==[NSCursor resizeDownCursor]
        || [NSCursor currentCursor]==[NSCursor resizeUpDownCursor])
    {
        [super mouseUp:theEvent];
    }
}


@end
