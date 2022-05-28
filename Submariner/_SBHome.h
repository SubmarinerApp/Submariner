// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to SBHome.h instead.

#import <CoreData/CoreData.h>


@class SBAlbum;
@class SBServer;


@interface SBHomeID : NSManagedObjectID {}
@end

@interface _SBHome : NSManagedObject {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (SBHomeID*)objectID;




@property (nonatomic, strong) NSSet* albums;
- (NSMutableSet*)albumsSet;



@property (nonatomic, strong) SBServer* server;
//- (BOOL)validateServer:(id*)value_ error:(NSError**)error_;




@end

@interface _SBHome (CoreDataGeneratedAccessors)

- (void)addAlbums:(NSSet*)value_;
- (void)removeAlbums:(NSSet*)value_;
- (void)addAlbumsObject:(SBAlbum*)value_;
- (void)removeAlbumsObject:(SBAlbum*)value_;

@end

@interface _SBHome (CoreDataGeneratedPrimitiveAccessors)



- (NSMutableSet*)primitiveAlbums;
- (void)setPrimitiveAlbums:(NSMutableSet*)value;



- (SBServer*)primitiveServer;
- (void)setPrimitiveServer:(SBServer*)value;


@end
