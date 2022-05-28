// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to SBEpisode.h instead.

#import <CoreData/CoreData.h>
#import "SBTrack.h"

@class SBTrack;
@class SBPodcast;






@interface SBEpisodeID : NSManagedObjectID {}
@end

@interface _SBEpisode : SBTrack {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (SBEpisodeID*)objectID;



@property (nonatomic, strong) NSDate *publishDate;

//- (BOOL)validatePublishDate:(id*)value_ error:(NSError**)error_;



@property (nonatomic, strong) NSString *episodeDescription;

//- (BOOL)validateEpisodeDescription:(id*)value_ error:(NSError**)error_;



@property (nonatomic, strong) NSString *streamID;

//- (BOOL)validateStreamID:(id*)value_ error:(NSError**)error_;



@property (nonatomic, strong) NSString *episodeStatus;

//- (BOOL)validateEpisodeStatus:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) SBTrack* track;
//- (BOOL)validateTrack:(id*)value_ error:(NSError**)error_;



@property (nonatomic, strong) SBPodcast* podcast;
//- (BOOL)validatePodcast:(id*)value_ error:(NSError**)error_;




@end

@interface _SBEpisode (CoreDataGeneratedAccessors)

@end

@interface _SBEpisode (CoreDataGeneratedPrimitiveAccessors)


- (NSDate*)primitivePublishDate;
- (void)setPrimitivePublishDate:(NSDate*)value;




- (NSString*)primitiveEpisodeDescription;
- (void)setPrimitiveEpisodeDescription:(NSString*)value;




- (NSString*)primitiveStreamID;
- (void)setPrimitiveStreamID:(NSString*)value;




- (NSString*)primitiveEpisodeStatus;
- (void)setPrimitiveEpisodeStatus:(NSString*)value;





- (SBTrack*)primitiveTrack;
- (void)setPrimitiveTrack:(SBTrack*)value;



- (SBPodcast*)primitivePodcast;
- (void)setPrimitivePodcast:(SBPodcast*)value;


@end
