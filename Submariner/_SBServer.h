// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to SBServer.h instead.

#import <CoreData/CoreData.h>
#import "SBResource.h"

@class SBIndex;
@class SBPodcast;
@class SBPlaylist;
@class SBNowPlaying;
@class SBTrack;
@class SBHome;










@interface SBServerID : NSManagedObjectID {}
@end

@interface _SBServer : SBResource {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (SBServerID*)objectID;



@property (nonatomic, retain) NSDate *lastIndexesDate;

//- (BOOL)validateLastIndexesDate:(id*)value_ error:(NSError**)error_;



@property (nonatomic, retain) NSString *url;

//- (BOOL)validateUrl:(id*)value_ error:(NSError**)error_;



@property (nonatomic, retain) NSNumber *isValidLicense;

@property BOOL isValidLicenseValue;
- (BOOL)isValidLicenseValue;
- (void)setIsValidLicenseValue:(BOOL)value_;

//- (BOOL)validateIsValidLicense:(id*)value_ error:(NSError**)error_;



@property (nonatomic, retain) NSDate *licenseDate;

//- (BOOL)validateLicenseDate:(id*)value_ error:(NSError**)error_;



@property (nonatomic, retain) NSString *password;

//- (BOOL)validatePassword:(id*)value_ error:(NSError**)error_;



@property (nonatomic, retain) NSString *apiVersion;

//- (BOOL)validateApiVersion:(id*)value_ error:(NSError**)error_;



@property (nonatomic, retain) NSString *licenseEmail;

//- (BOOL)validateLicenseEmail:(id*)value_ error:(NSError**)error_;



@property (nonatomic, retain) NSString *username;

//- (BOOL)validateUsername:(id*)value_ error:(NSError**)error_;




@property (nonatomic, retain) NSSet* indexes;
- (NSMutableSet*)indexesSet;



@property (nonatomic, retain) NSSet* messages;
- (NSMutableSet*)messagesSet;



@property (nonatomic, retain) NSSet* podcasts;
- (NSMutableSet*)podcastsSet;



@property (nonatomic, retain) NSSet* playlists;
- (NSMutableSet*)playlistsSet;



@property (nonatomic, retain) NSSet* nowPlayings;
- (NSMutableSet*)nowPlayingsSet;



@property (nonatomic, retain) NSSet* tracks;
- (NSMutableSet*)tracksSet;



@property (nonatomic, retain) SBHome* home;
//- (BOOL)validateHome:(id*)value_ error:(NSError**)error_;




@end

@interface _SBServer (CoreDataGeneratedAccessors)

- (void)addIndexes:(NSSet*)value_;
- (void)removeIndexes:(NSSet*)value_;
- (void)addIndexesObject:(SBIndex*)value_;
- (void)removeIndexesObject:(SBIndex*)value_;

- (void)addPodcasts:(NSSet*)value_;
- (void)removePodcasts:(NSSet*)value_;
- (void)addPodcastsObject:(SBPodcast*)value_;
- (void)removePodcastsObject:(SBPodcast*)value_;

- (void)addPlaylists:(NSSet*)value_;
- (void)removePlaylists:(NSSet*)value_;
- (void)addPlaylistsObject:(SBPlaylist*)value_;
- (void)removePlaylistsObject:(SBPlaylist*)value_;

- (void)addNowPlayings:(NSSet*)value_;
- (void)removeNowPlayings:(NSSet*)value_;
- (void)addNowPlayingsObject:(SBNowPlaying*)value_;
- (void)removeNowPlayingsObject:(SBNowPlaying*)value_;

- (void)addTracks:(NSSet*)value_;
- (void)removeTracks:(NSSet*)value_;
- (void)addTracksObject:(SBTrack*)value_;
- (void)removeTracksObject:(SBTrack*)value_;

@end

@interface _SBServer (CoreDataGeneratedPrimitiveAccessors)


- (NSDate*)primitiveLastIndexesDate;
- (void)setPrimitiveLastIndexesDate:(NSDate*)value;




- (NSString*)primitiveUrl;
- (void)setPrimitiveUrl:(NSString*)value;




- (NSNumber*)primitiveIsValidLicense;
- (void)setPrimitiveIsValidLicense:(NSNumber*)value;

- (BOOL)primitiveIsValidLicenseValue;
- (void)setPrimitiveIsValidLicenseValue:(BOOL)value_;




- (NSDate*)primitiveLicenseDate;
- (void)setPrimitiveLicenseDate:(NSDate*)value;




- (NSString*)primitivePassword;
- (void)setPrimitivePassword:(NSString*)value;




- (NSString*)primitiveApiVersion;
- (void)setPrimitiveApiVersion:(NSString*)value;




- (NSString*)primitiveLicenseEmail;
- (void)setPrimitiveLicenseEmail:(NSString*)value;




- (NSString*)primitiveUsername;
- (void)setPrimitiveUsername:(NSString*)value;





- (NSMutableSet*)primitiveIndexes;
- (void)setPrimitiveIndexes:(NSMutableSet*)value;



- (NSMutableSet*)primitiveMessages;
- (void)setPrimitiveMessages:(NSMutableSet*)value;



- (NSMutableSet*)primitivePodcasts;
- (void)setPrimitivePodcasts:(NSMutableSet*)value;



- (NSMutableSet*)primitivePlaylists;
- (void)setPrimitivePlaylists:(NSMutableSet*)value;



- (NSMutableSet*)primitiveNowPlayings;
- (void)setPrimitiveNowPlayings:(NSMutableSet*)value;



- (NSMutableSet*)primitiveTracks;
- (void)setPrimitiveTracks:(NSMutableSet*)value;



- (SBHome*)primitiveHome;
- (void)setPrimitiveHome:(SBHome*)value;


@end
