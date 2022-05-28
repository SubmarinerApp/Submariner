// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to SBLibrary.h instead.

#import <CoreData/CoreData.h>
#import "SBResource.h"

@class SBArtist;


@interface SBLibraryID : NSManagedObjectID {}
@end

@interface _SBLibrary : SBResource {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (SBLibraryID*)objectID;




@property (nonatomic, strong) NSSet* artists;
- (NSMutableSet*)artistsSet;




@end

@interface _SBLibrary (CoreDataGeneratedAccessors)

- (void)addArtists:(NSSet*)value_;
- (void)removeArtists:(NSSet*)value_;
- (void)addArtistsObject:(SBArtist*)value_;
- (void)removeArtistsObject:(SBArtist*)value_;

@end

@interface _SBLibrary (CoreDataGeneratedPrimitiveAccessors)



- (NSMutableSet*)primitiveArtists;
- (void)setPrimitiveArtists:(NSMutableSet*)value;


@end
