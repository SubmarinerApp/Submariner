// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to SBAlbum.h instead.

#import <CoreData/CoreData.h>
#import "SBMusicItem.h"

@class SBTrack;
@class SBHome;
@class SBCover;
@class SBArtist;


@interface SBAlbumID : NSManagedObjectID {}
@end

@interface _SBAlbum : SBMusicItem {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (SBAlbumID*)objectID;




@property (nonatomic, strong) NSSet* tracks;
- (NSMutableSet*)tracksSet;



@property (nonatomic, strong) SBHome* home;
//- (BOOL)validateHome:(id*)value_ error:(NSError**)error_;



@property (nonatomic, strong) SBCover* cover;
//- (BOOL)validateCover:(id*)value_ error:(NSError**)error_;



@property (nonatomic, strong) SBArtist* artist;
//- (BOOL)validateArtist:(id*)value_ error:(NSError**)error_;




@end

@interface _SBAlbum (CoreDataGeneratedAccessors)

- (void)addTracks:(NSSet*)value_;
- (void)removeTracks:(NSSet*)value_;
- (void)addTracksObject:(SBTrack*)value_;
- (void)removeTracksObject:(SBTrack*)value_;

@end

@interface _SBAlbum (CoreDataGeneratedPrimitiveAccessors)



- (NSMutableSet*)primitiveTracks;
- (void)setPrimitiveTracks:(NSMutableSet*)value;



- (SBHome*)primitiveHome;
- (void)setPrimitiveHome:(SBHome*)value;



- (SBCover*)primitiveCover;
- (void)setPrimitiveCover:(SBCover*)value;



- (SBArtist*)primitiveArtist;
- (void)setPrimitiveArtist:(SBArtist*)value;


@end
