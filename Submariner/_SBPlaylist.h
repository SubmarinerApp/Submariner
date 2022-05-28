// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to SBPlaylist.h instead.

#import <CoreData/CoreData.h>
#import "SBResource.h"

@class SBServer;
@class SBTrack;



@interface SBPlaylistID : NSManagedObjectID {}
@end

@interface _SBPlaylist : SBResource {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (SBPlaylistID*)objectID;



@property (nonatomic, strong) NSString *id;

//- (BOOL)validateId:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) SBServer* server;
//- (BOOL)validateServer:(id*)value_ error:(NSError**)error_;



@property (nonatomic, strong) NSSet* tracks;
- (NSMutableSet*)tracksSet;




@end

@interface _SBPlaylist (CoreDataGeneratedAccessors)

- (void)addTracks:(NSSet*)value_;
- (void)removeTracks:(NSSet*)value_;
- (void)addTracksObject:(SBTrack*)value_;
- (void)removeTracksObject:(SBTrack*)value_;

@end

@interface _SBPlaylist (CoreDataGeneratedPrimitiveAccessors)


- (NSString*)primitiveId;
- (void)setPrimitiveId:(NSString*)value;





- (SBServer*)primitiveServer;
- (void)setPrimitiveServer:(SBServer*)value;



- (NSMutableSet*)primitiveTracks;
- (void)setPrimitiveTracks:(NSMutableSet*)value;


@end
