//
//  PXSourceListDelegate.h
//  PXViewKit
//
//  Created by Alex Rozanski on 17/10/2009.
//  Copyright 2009-10 Alex Rozanski http://perspx.com
//

#import <Cocoa/Cocoa.h>

@class SBSourceList;

@protocol SBSourceListDelegate <NSOutlineViewDelegate>

@optional
//Extra methods
- (BOOL)sourceList:(SBSourceList*)aSourceList isGroupAlwaysExpanded:(id)group;
- (NSMenu*)sourceList:(SBSourceList*)aSourceList menuForEvent:(NSEvent*)theEvent item:(id)item;

//Basically NSOutlineViewDelegate wrapper methods
- (BOOL)sourceList:(SBSourceList*)aSourceList shouldSelectItem:(id)item;
- (NSIndexSet*)sourceList:(SBSourceList*)aSourceList selectionIndexesForProposedSelection:(NSIndexSet *)proposedSelectionIndexes;

- (BOOL)sourceList:(SBSourceList*)aSourceList shouldEditItem:(id)item;

- (BOOL)sourceList:(SBSourceList*)aSourceList shouldTrackCell:(NSCell *)cell forItem:(id)item;

- (BOOL)sourceList:(SBSourceList*)aSourceList shouldExpandItem:(id)item;
- (BOOL)sourceList:(SBSourceList*)aSourceList shouldCollapseItem:(id)item;

- (CGFloat)sourceList:(SBSourceList*)aSourceList heightOfRowByItem:(id)item;

- (NSCell*)sourceList:(SBSourceList*)aSourceList willDisplayCell:(id)cell forItem:(id)item;
- (NSCell*)sourceList:(SBSourceList*)aSourceList dataCellForItem:(id)item;

@end

@interface NSObject (PXSourceListNotifications)

//Selection
- (void)sourceListSelectionIsChanging:(NSNotification *)notification;
- (void)sourceListSelectionDidChange:(NSNotification *)notification;

//Item expanding/collapsing
- (void)sourceListItemWillExpand:(NSNotification *)notification;
- (void)sourceListItemDidExpand:(NSNotification *)notification;
- (void)sourceListItemWillCollapse:(NSNotification *)notification;
- (void)sourceListItemDidCollapse:(NSNotification *)notification;

- (void)sourceListDeleteKeyPressedOnRows:(NSNotification *)notification;


@end

//PXSourceList delegate notifications
extern NSString * const PXSLSelectionIsChangingNotification;
extern NSString * const PXSLSelectionDidChangeNotification;
extern NSString * const PXSLItemWillExpandNotification;
extern NSString * const PXSLItemDidExpandNotification;
extern NSString * const PXSLItemWillCollapseNotification;
extern NSString * const PXSLItemDidCollapseNotification;
extern NSString * const PXSLDeleteKeyPressedOnRowsNotification;

