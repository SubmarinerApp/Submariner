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



@property (nonatomic, strong) NSDate *lastIndexesDate;

//- (BOOL)validateLastIndexesDate:(id*)value_ error:(NSError**)error_;



@property (nonatomic, strong) NSString *url;

//- (BOOL)validateUrl:(id*)value_ error:(NSError**)error_;



@property (nonatomic, strong) NSNumber *isValidLicense;

@property BOOL isValidLicenseValue;
- (BOOL)isValidLicenseValue;
- (void)setIsValidLicenseValue:(BOOL)value_;

//- (BOOL)validateIsValidLicense:(id*)value_ error:(NSError**)error_;



@property (nonatomic, strong) NSNumber *useTokenAuth;

@property BOOL useTokenAuthValue;
- (BOOL)useTokenAuthValue;
- (void)setUseTokenAuthValue:(BOOL)value_;

//- (BOOL)validateIsValidLicense:(id*)value_ error:(NSError**)error_;



@property (nonatomic, strong) NSDate *licenseDate;

//- (BOOL)validateLicenseDate:(id*)value_ error:(NSError**)error_;



@property (nonatomic, strong) NSString *password;

//- (BOOL)validatePassword:(id*)value_ error:(NSError**)error_;



@property (nonatomic, strong) NSString *apiVersion;

//- (BOOL)validateApiVersion:(id*)value_ error:(NSError**)error_;



@property (nonatomic, strong) NSString *licenseEmail;

//- (BOOL)validateLicenseEmail:(id*)value_ error:(NSError**)error_;



@property (nonatomic, strong) NSString *username;

//- (BOOL)validateUsername:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSSet* indexes;
- (NSMutableSet*)indexesSet;



@property (nonatomic, strong) NSSet* messages;
- (NSMutableSet*)messagesSet;



@property (nonatomic, strong) NSSet* podcasts;
- (NSMutableSet*)podcastsSet;



@property (nonatomic, strong) NSSet* playlists;
- (NSMutableSet*)playlistsSet;



@property (nonatomic, strong) NSSet* nowPlayings;
- (NSMutableSet*)nowPlayingsSet;



@property (nonatomic, strong) NSSet* tracks;
- (NSMutableSet*)tracksSet;



@property (nonatomic, strong) SBHome* home;
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




- (NSNumber*)primitiveUseTokenAuth;
- (void)setPrimitiveUseTokenAuth:(NSNumber*)value;

- (BOOL)primitiveUseTokenAuthValue;
- (void)setPrimitiveUseTokenAuthValue:(BOOL)value_;




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
