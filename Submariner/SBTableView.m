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

@implementation SBTableView


- (void)awakeFromNib {
    [super awakeFromNib];
    // don't override an existing menu
    if (self.autosaveName != nil && self.headerView.menu == nil) {
        [self createViewHeaderMenu];
    }
}


- (void)replaceSelectionForRightClick {
    // Try to select the clicked row for a right-click; default AppKit behaviour is weird.
    // Otherwise, it'll still use what was highlighted.
    // XXX: Perhaps we shouldn't tie a lot of things to selected, but instead clicked.
    NSIndexSet *selectedCurrently = [self selectedRowIndexes];
    NSUInteger clickedRow = [self clickedRow];
    if (![selectedCurrently containsIndex: clickedRow]) {
        NSIndexSet *selectedNew = [NSIndexSet indexSetWithIndex: clickedRow];
        [self selectRowIndexes: selectedNew byExtendingSelection: NO];
    }
}


- (void)willOpenMenu:(NSMenu *)menu withEvent:(NSEvent *)event {
    [self replaceSelectionForRightClick];
    [super willOpenMenu: menu withEvent: event];
}

#pragma mark -
#pragma mark Header Menu Toggles

// synthesis of various answers in https://stackoverflow.com/questions/13553935/nstableview-to-allow-user-to-choose-which-columns-to-display

- (NSString*)columnsAutosaveKeyName {
    return [NSString stringWithFormat: @"SBTableView %@ Columns", self.autosaveName];
}

- (void)toggleColumn:(NSMenuItem *)menu {
    NSTableColumn *col = menu.representedObject;

    BOOL shouldHide = !col.isHidden;
    [col setHidden:shouldHide];

    menu.state = (col.isHidden ? NSControlStateValueOff: NSControlStateValueOn);

    NSMutableDictionary *cols = @{}.mutableCopy;
    for (NSTableColumn *column in self.tableColumns) {
        cols[column.identifier] = @(!column.isHidden);
    }

    NSString *keyName = [self columnsAutosaveKeyName];
    [[NSUserDefaults standardUserDefaults] setObject:cols forKey: keyName];
    if (shouldHide) {
        [self sizeLastColumnToFit];
    } else {
        [self sizeToFit];
    }
}

- (void)createViewHeaderMenu {
    NSString *keyName = [self columnsAutosaveKeyName];
    headerMenu = [[NSMenu alloc] initWithTitle: keyName];
    headerMenu.delegate = self;
    self.headerView.menu = headerMenu;
    
    NSDictionary *savedCols = [[NSUserDefaults standardUserDefaults] dictionaryForKey: keyName];
    
    for (NSTableColumn *col in self.tableColumns) {
        //NSLog(@"Adding column ID %@ with name %@ tooltip %@", col.identifier, col.headerCell.stringValue, col.headerToolTip);

        NSString *miName = [col.headerCell stringValue]; // does not return nil
        if ([miName isEqual: @""] && col.headerToolTip != nil && ![col.headerToolTip isEqual: @""]) {
            miName = col.headerToolTip;
        } else if ([miName isEqual: @""] && ![col.identifier hasPrefix: @"AutomaticTableColumnIdentifier."]) {
            // if identifier is nil we're screwed anyways
            miName = col.identifier;
        }
        NSMenuItem *mi = [[NSMenuItem alloc] initWithTitle:miName
                                                    action:@selector(toggleColumn:)
                                             keyEquivalent:@""];
        mi.target = self;

        if (savedCols) {
            BOOL isVisible = [savedCols[col.identifier] boolValue];
            [col setHidden:!isVisible];
        }

        mi.state = (col.isHidden ? NSControlStateValueOff: NSControlStateValueOn);
        mi.representedObject = col;
        [headerMenu addItem:mi];
    }
}

-(void)menuNeedsUpdate:(NSMenu *)menu {
    for (NSMenuItem *mi in menu.itemArray) {
        NSTableColumn *col = [mi representedObject];
        [mi setState:col.isHidden ? NSControlStateValueOff : NSControlStateValueOn];
    }
}

@end
