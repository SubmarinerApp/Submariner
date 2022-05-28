// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to SBNowPlaying.h instead.

#import <CoreData/CoreData.h>


@class SBTrack;
@class SBServer;




@interface SBNowPlayingID : NSManagedObjectID {}
@end

@interface _SBNowPlaying : NSManagedObject {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (SBNowPlayingID*)objectID;



@property (nonatomic, strong) NSString *username;

//- (BOOL)validateUsername:(id*)value_ error:(NSError**)error_;



@property (nonatomic, strong) NSNumber *minutesAgo;

@property int minutesAgoValue;
- (int)minutesAgoValue;
- (void)setMinutesAgoValue:(int)value_;

//- (BOOL)validateMinutesAgo:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) SBTrack* track;
//- (BOOL)validateTrack:(id*)value_ error:(NSError**)error_;



@property (nonatomic, strong) SBServer* server;
//- (BOOL)validateServer:(id*)value_ error:(NSError**)error_;




@end

@interface _SBNowPlaying (CoreDataGeneratedAccessors)

@end

@interface _SBNowPlaying (CoreDataGeneratedPrimitiveAccessors)


- (NSString*)primitiveUsername;
- (void)setPrimitiveUsername:(NSString*)value;




- (NSNumber*)primitiveMinutesAgo;
- (void)setPrimitiveMinutesAgo:(NSNumber*)value;

- (int)primitiveMinutesAgoValue;
- (void)setPrimitiveMinutesAgoValue:(int)value_;





- (SBTrack*)primitiveTrack;
- (void)setPrimitiveTrack:(SBTrack*)value;



- (SBServer*)primitiveServer;
- (void)setPrimitiveServer:(SBServer*)value;


@end
