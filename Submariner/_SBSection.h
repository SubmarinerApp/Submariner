// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to SBSection.h instead.

#import <CoreData/CoreData.h>
#import "SBResource.h"

@class SBResource;


@interface SBSectionID : NSManagedObjectID {}
@end

@interface _SBSection : SBResource {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (SBSectionID*)objectID;




@property (nonatomic, strong) NSSet* resources;
- (NSMutableSet*)resourcesSet;




@end

@interface _SBSection (CoreDataGeneratedAccessors)

- (void)addResources:(NSSet*)value_;
- (void)removeResources:(NSSet*)value_;
- (void)addResourcesObject:(SBResource*)value_;
- (void)removeResourcesObject:(SBResource*)value_;

@end

@interface _SBSection (CoreDataGeneratedPrimitiveAccessors)



- (NSMutableSet*)primitiveResources;
- (void)setPrimitiveResources:(NSMutableSet*)value;


@end
