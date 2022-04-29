//
//  PXSourceListDataSource.h
//  PXViewKit
//
//  Created by Alex Rozanski on 17/10/2009.
//  Copyright 2009-10 Alex Rozanski http://perspx.com
//

#import <Cocoa/Cocoa.h>

@class SBSourceList;

@protocol SBSourceListDataSource <NSOutlineViewDataSource>

@required
- (NSUInteger)sourceList:(SBSourceList*)sourceList numberOfChildrenOfItem:(id)item;
- (id)sourceList:(SBSourceList*)aSourceList child:(NSUInteger)index ofItem:(id)item;
- (id)sourceList:(SBSourceList*)aSourceList objectValueForItem:(id)item;
- (BOOL)sourceList:(SBSourceList*)aSourceList isItemExpandable:(id)item;

@optional
- (void)sourceList:(SBSourceList*)aSourceList setObjectValue:(id)object forItem:(id)item;

- (BOOL)sourceList:(SBSourceList*)aSourceList itemHasBadge:(id)item;
- (NSInteger)sourceList:(SBSourceList*)aSourceList badgeValueForItem:(id)item;
- (NSColor*)sourceList:(SBSourceList*)aSourceList badgeTextColorForItem:(id)item;
- (NSColor*)sourceList:(SBSourceList*)aSourceList badgeBackgroundColorForItem:(id)item;

- (BOOL)sourceList:(SBSourceList*)aSourceList itemHasIcon:(id)item;
- (NSImage*)sourceList:(SBSourceList*)aSourceList iconForItem:(id)item;

//The rest of these methods are basically "wrappers" for the NSOutlineViewDataSource methods
- (id)sourceList:(SBSourceList*)aSourceList itemForPersistentObject:(id)object;
- (id)sourceList:(SBSourceList*)aSourceList persistentObjectForItem:(id)item;

- (BOOL)sourceList:(SBSourceList*)aSourceList writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pboard;
- (NSDragOperation)sourceList:(SBSourceList*)sourceList validateDrop:(id < NSDraggingInfo >)info proposedItem:(id)item proposedChildIndex:(NSInteger)index;
- (BOOL)sourceList:(SBSourceList*)aSourceList acceptDrop:(id < NSDraggingInfo >)info item:(id)item childIndex:(NSInteger)index;
- (NSArray *)sourceList:(SBSourceList*)aSourceList namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropDestination forDraggedItems:(NSArray *)items;

@end
