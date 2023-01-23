// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to SBServer.m instead.

#import "_SBServer.h"

@implementation SBServerID
@end

@implementation _SBServer

+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription insertNewObjectForEntityForName:@"Server" inManagedObjectContext:moc_];
}

+ (NSString*)entityName {
	return @"Server";
}

+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription entityForName:@"Server" inManagedObjectContext:moc_];
}

- (SBServerID*)objectID {
	return (SBServerID*)[super objectID];
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
	
	if ([key isEqualToString:@"isValidLicenseValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"isValidLicense"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
	}

	return keyPaths;
}




@dynamic lastIndexesDate;






@dynamic url;






@dynamic isValidLicense;



- (BOOL)isValidLicenseValue {
	NSNumber *result = [self isValidLicense];
	return [result boolValue];
}

- (void)setIsValidLicenseValue:(BOOL)value_ {
	[self setIsValidLicense:[NSNumber numberWithBool:value_]];
}

- (BOOL)primitiveIsValidLicenseValue {
	NSNumber *result = [self primitiveIsValidLicense];
	return [result boolValue];
}

- (void)setPrimitiveIsValidLicenseValue:(BOOL)value_ {
	[self setPrimitiveIsValidLicense:[NSNumber numberWithBool:value_]];
}






@dynamic useTokenAuth;



- (BOOL)useTokenAuthValue {
    NSNumber *result = [self useTokenAuth];
    return [result boolValue];
}

- (void)setUseTokenAuthValue:(BOOL)value_ {
    [self setUseTokenAuth:[NSNumber numberWithBool:value_]];
}

- (BOOL)primitiveUseTokenAuthValue {
    NSNumber *result = [self primitiveUseTokenAuth];
    return [result boolValue];
}

- (void)setPrimitiveUseTokenAuthValue:(BOOL)value_ {
    [self setPrimitiveUseTokenAuth:[NSNumber numberWithBool:value_]];
}





@dynamic licenseDate;






@dynamic password;






@dynamic apiVersion;






@dynamic licenseEmail;






@dynamic username;






@dynamic indexes;

	
- (NSMutableSet*)indexesSet {
	[self willAccessValueForKey:@"indexes"];
	NSMutableSet *result = [self mutableSetValueForKey:@"indexes"];
	[self didAccessValueForKey:@"indexes"];
	return result;
}
	

@dynamic messages;

	
- (NSMutableSet*)messagesSet {
	[self willAccessValueForKey:@"messages"];
	NSMutableSet *result = [self mutableSetValueForKey:@"messages"];
	[self didAccessValueForKey:@"messages"];
	return result;
}
	

@dynamic podcasts;

	
- (NSMutableSet*)podcastsSet {
	[self willAccessValueForKey:@"podcasts"];
	NSMutableSet *result = [self mutableSetValueForKey:@"podcasts"];
	[self didAccessValueForKey:@"podcasts"];
	return result;
}
	

@dynamic playlists;

	
- (NSMutableSet*)playlistsSet {
	[self willAccessValueForKey:@"playlists"];
	NSMutableSet *result = [self mutableSetValueForKey:@"playlists"];
	[self didAccessValueForKey:@"playlists"];
	return result;
}
	

@dynamic nowPlayings;

	
- (NSMutableSet*)nowPlayingsSet {
	[self willAccessValueForKey:@"nowPlayings"];
	NSMutableSet *result = [self mutableSetValueForKey:@"nowPlayings"];
	[self didAccessValueForKey:@"nowPlayings"];
	return result;
}
	

@dynamic tracks;

	
- (NSMutableSet*)tracksSet {
	[self willAccessValueForKey:@"tracks"];
	NSMutableSet *result = [self mutableSetValueForKey:@"tracks"];
	[self didAccessValueForKey:@"tracks"];
	return result;
}
	

@dynamic home;

	





@end
