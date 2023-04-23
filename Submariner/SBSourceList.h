//
//  PXSourceList.h
//  PXSourceList
//
//  Created by Alex Rozanski on 05/09/2009.
//  Copyright 2009-10 Alex Rozanski http://perspx.com
//

#import <Cocoa/Cocoa.h>

#import "SBSourceListDelegate.h"
#import "SBSourceListDataSource.h"

#ifndef MAC_OS_X_VERSION_10_6
@protocol NSOutlineViewDelegate <NSObject> @end
@protocol NSOutlineViewDataSource <NSObject> @end
#endif

@interface SBSourceList: NSOutlineView <NSOutlineViewDelegate, NSOutlineViewDataSource, NSUserInterfaceValidations>
{
	id <SBSourceListDelegate> _secondaryDelegate;		//Used to store the publicly visible delegate
	id <SBSourceListDataSource> _secondaryDataSource;	//Used to store the publicly visible data source
	
	NSSize _iconSize;									//The size of icons in the Source List. Defaults to 16x16
}
	
@property NSSize iconSize;
	
@property (unsafe_unretained) id<SBSourceListDataSource> dataSource;
@property (unsafe_unretained) id<SBSourceListDelegate> delegate;

- (NSUInteger)numberOfGroups;							//Returns the number of groups in the Source List
- (BOOL)isGroupItem:(id)item;							//Returns whether `item` is a group
- (BOOL)isGroupAlwaysExpanded:(id)group;				//Returns whether `group` is displayed as always expanded

- (BOOL)itemHasBadge:(id)item;							//Returns whether `item` has a badge
- (NSInteger)badgeValueForItem:(id)item;				//Returns the badge value for `item`

- (BOOL)validateUserInterfaceItem: (id<NSValidatedUserInterfaceItem>) item;
@end

