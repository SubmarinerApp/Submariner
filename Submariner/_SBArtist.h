// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to SBArtist.h instead.

#import <CoreData/CoreData.h>
#import "SBIndex.h"

@class SBLibrary;
@class SBAlbum;


@interface SBArtistID : NSManagedObjectID {}
@end

@interface _SBArtist : SBIndex {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (SBArtistID*)objectID;




@property (nonatomic, strong) SBLibrary* library;
//- (BOOL)validateLibrary:(id*)value_ error:(NSError**)error_;



@property (nonatomic, strong) NSSet* albums;
- (NSMutableSet*)albumsSet;




@end

@interface _SBArtist (CoreDataGeneratedAccessors)

- (void)addAlbums:(NSSet*)value_;
- (void)removeAlbums:(NSSet*)value_;
- (void)addAlbumsObject:(SBAlbum*)value_;
- (void)removeAlbumsObject:(SBAlbum*)value_;

@end

@interface _SBArtist (CoreDataGeneratedPrimitiveAccessors)



- (SBLibrary*)primitiveLibrary;
- (void)setPrimitiveLibrary:(SBLibrary*)value;



- (NSMutableSet*)primitiveAlbums;
- (void)setPrimitiveAlbums:(NSMutableSet*)value;


@end
