// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to SBCover.h instead.

#import <CoreData/CoreData.h>
#import "SBMusicItem.h"

@class SBTrack;
@class SBAlbum;



@interface SBCoverID : NSManagedObjectID {}
@end

@interface _SBCover : SBMusicItem {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (SBCoverID*)objectID;



@property (nonatomic, strong) NSString *imagePath;

//- (BOOL)validateImagePath:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) SBTrack* track;
//- (BOOL)validateTrack:(id*)value_ error:(NSError**)error_;



@property (nonatomic, strong) SBAlbum* album;
//- (BOOL)validateAlbum:(id*)value_ error:(NSError**)error_;




@end

@interface _SBCover (CoreDataGeneratedAccessors)

@end

@interface _SBCover (CoreDataGeneratedPrimitiveAccessors)


- (NSString*)primitiveImagePath;
- (void)setPrimitiveImagePath:(NSString*)value;





- (SBTrack*)primitiveTrack;
- (void)setPrimitiveTrack:(SBTrack*)value;



- (SBAlbum*)primitiveAlbum;
- (void)setPrimitiveAlbum:(SBAlbum*)value;


@end
