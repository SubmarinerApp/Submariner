//
//  SBTableView.m
//  Sub
//
//  Created by Rafaël Warnault on 25/05/11.
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

#import "SBTableView.h"
#import "RWTableHeaderCell.h"


NSString *SBEnterKeyPressedOnRowsNotification = @"SBEnterKeyPressedOnRowsNotification";



@interface SBTableView (Notifications)

- (void)enterKeyPressedOnRowsNotification:(NSNotification *)notification;

@end





@implementation SBTableView

- (void)_setupHeaderCell
{
	for (NSTableColumn* column in [self tableColumns]) {
		NSTableHeaderCell* cell = [column headerCell];
		RWTableHeaderCell* newCell = [[RWTableHeaderCell alloc] initWithCell:cell];
		[column setHeaderCell:newCell];
	}
	
}


- (id)initWithCoder:(NSCoder *)aDecoder
{	
	self = [super initWithCoder:aDecoder];
	
	if (self) {
		[self _setupHeaderCell];
	}
	return self;
}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:SBEnterKeyPressedOnRowsNotification object:nil];
    
}

- (void)awakeFromNib {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(enterKeyPressedOnRowsNotification:) 
                                                 name:SBEnterKeyPressedOnRowsNotification 
                                               object:nil];
}


- (void)keyDown:(NSEvent *)theEvent
{
	NSIndexSet *selectedIndexes = [self selectedRowIndexes];
	
	NSString *keyCharacters = [theEvent characters];
	
	//Make sure we have a selection
	if([selectedIndexes count]>0) {
		if([keyCharacters length]>0) {
			unichar firstKey = [keyCharacters characterAtIndex:0];
            if(firstKey==NSEnterCharacter || firstKey == NSCarriageReturnCharacter || firstKey == NSNewlineCharacter) {	
				//Post the notification
				[[NSNotificationCenter defaultCenter] postNotificationName:SBEnterKeyPressedOnRowsNotification
																	object:self
																  userInfo:[NSDictionary dictionaryWithObject:selectedIndexes forKey:@"rows"]];
				
				return;
			}
		}
	}
	//We don't care about it
	[super keyDown:theEvent];
}


- (void)enterKeyPressedOnRowsNotification:(NSNotification *)notification {
    if([notification object] == self) {
        if([self delegate] && [[self delegate] respondsToSelector:@selector(tableViewDeleteKeyPressedNotification:)]) {
            [[self delegate] tableViewEnterKeyPressedNotification:notification];
        } 
    }
}

@end
