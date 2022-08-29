// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to SBTrack.m instead.

#import "_SBTrack.h"

@implementation SBTrackID
@end

@implementation _SBTrack

+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription insertNewObjectForEntityForName:@"Track" inManagedObjectContext:moc_];
}

+ (NSString*)entityName {
	return @"Track";
}

+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription entityForName:@"Track" inManagedObjectContext:moc_];
}

- (SBTrackID*)objectID {
	return (SBTrackID*)[super objectID];
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
	
	if ([key isEqualToString:@"isPlayingValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"isPlaying"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
	}
	if ([key isEqualToString:@"sizeValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"size"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
	}
	if ([key isEqualToString:@"yearValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"year"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
	}
	if ([key isEqualToString:@"bitRateValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"bitRate"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
	}
	if ([key isEqualToString:@"playlistIndexValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"playlistIndex"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
	}
	if ([key isEqualToString:@"ratingValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"rating"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
	}
	if ([key isEqualToString:@"trackNumberValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"trackNumber"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
	}
    if ([key isEqualToString:@"discNumber"]) {
        NSSet *affectingKey = [NSSet setWithObject:@"discNumber"];
        keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
    }
	if ([key isEqualToString:@"durationValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"duration"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
	}

	return keyPaths;
}




@dynamic albumName;






@dynamic isPlaying;



- (BOOL)isPlayingValue {
	NSNumber *result = [self isPlaying];
	return [result boolValue];
}

- (void)setIsPlayingValue:(BOOL)value_ {
	[self setIsPlaying:[NSNumber numberWithBool:value_]];
}

- (BOOL)primitiveIsPlayingValue {
	NSNumber *result = [self primitiveIsPlaying];
	return [result boolValue];
}

- (void)setPrimitiveIsPlayingValue:(BOOL)value_ {
	[self setPrimitiveIsPlaying:[NSNumber numberWithBool:value_]];
}





@dynamic size;



- (int)sizeValue {
	NSNumber *result = [self size];
	return [result intValue];
}

- (void)setSizeValue:(int)value_ {
	[self setSize:[NSNumber numberWithInt:value_]];
}

- (int)primitiveSizeValue {
	NSNumber *result = [self primitiveSize];
	return [result intValue];
}

- (void)setPrimitiveSizeValue:(int)value_ {
	[self setPrimitiveSize:[NSNumber numberWithInt:value_]];
}





@dynamic contentSuffix;






@dynamic year;



- (int)yearValue {
	NSNumber *result = [self year];
	return [result intValue];
}

- (void)setYearValue:(int)value_ {
	[self setYear:[NSNumber numberWithInt:value_]];
}

- (int)primitiveYearValue {
	NSNumber *result = [self primitiveYear];
	return [result intValue];
}

- (void)setPrimitiveYearValue:(int)value_ {
	[self setPrimitiveYear:[NSNumber numberWithInt:value_]];
}





@dynamic contentType;






@dynamic bitRate;



- (int)bitRateValue {
	NSNumber *result = [self bitRate];
	return [result intValue];
}

- (void)setBitRateValue:(int)value_ {
	[self setBitRate:[NSNumber numberWithInt:value_]];
}

- (int)primitiveBitRateValue {
	NSNumber *result = [self primitiveBitRate];
	return [result intValue];
}

- (void)setPrimitiveBitRateValue:(int)value_ {
	[self setPrimitiveBitRate:[NSNumber numberWithInt:value_]];
}





@dynamic coverID;






@dynamic playlistIndex;



- (int)playlistIndexValue {
	NSNumber *result = [self playlistIndex];
	return [result intValue];
}

- (void)setPlaylistIndexValue:(int)value_ {
	[self setPlaylistIndex:[NSNumber numberWithInt:value_]];
}

- (int)primitivePlaylistIndexValue {
	NSNumber *result = [self primitivePlaylistIndex];
	return [result intValue];
}

- (void)setPrimitivePlaylistIndexValue:(int)value_ {
	[self setPrimitivePlaylistIndex:[NSNumber numberWithInt:value_]];
}





@dynamic rating;



- (int)ratingValue {
	NSNumber *result = [self rating];
	return [result intValue];
}

- (void)setRatingValue:(int)value_ {
	[self setRating:[NSNumber numberWithInt:value_]];
}

- (int)primitiveRatingValue {
	NSNumber *result = [self primitiveRating];
	return [result intValue];
}

- (void)setPrimitiveRatingValue:(int)value_ {
	[self setPrimitiveRating:[NSNumber numberWithInt:value_]];
}





@dynamic transcodedType;






@dynamic transcodeSuffix;






@dynamic artistName;






@dynamic trackNumber;



- (int)trackNumberValue {
	NSNumber *result = [self trackNumber];
	return [result intValue];
}

- (void)setTrackNumberValue:(int)value_ {
	[self setTrackNumber:[NSNumber numberWithInt:value_]];
}

- (int)primitiveTrackNumberValue {
	NSNumber *result = [self primitiveTrackNumber];
	return [result intValue];
}

- (void)setPrimitiveTrackNumberValue:(int)value_ {
	[self setPrimitiveTrackNumber:[NSNumber numberWithInt:value_]];
}






@dynamic discNumber;



- (int)discNumberValue {
    NSNumber *result = [self discNumber];
    return [result intValue];
}

- (void)setDiscNumberValue:(int)value_ {
    [self setDiscNumber:[NSNumber numberWithInt:value_]];
}

- (int)primitiveDiscNumberValue {
    NSNumber *result = [self primitiveDiscNumber];
    return [result intValue];
}

- (void)setPrimitiveDiscNumberValue:(int)value_ {
    [self setPrimitiveDiscNumber:[NSNumber numberWithInt:value_]];
}





@dynamic duration;



- (int)durationValue {
	NSNumber *result = [self duration];
	return [result intValue];
}

- (void)setDurationValue:(int)value_ {
	[self setDuration:[NSNumber numberWithInt:value_]];
}

- (int)primitiveDurationValue {
	NSNumber *result = [self primitiveDuration];
	return [result intValue];
}

- (void)setPrimitiveDurationValue:(int)value_ {
	[self setPrimitiveDuration:[NSNumber numberWithInt:value_]];
}





@dynamic genre;






@dynamic nowPlaying;

	

@dynamic album;

	

@dynamic cover;

	

@dynamic episode;

	

@dynamic server;

	

@dynamic playlist;

	

@dynamic remoteTrack;

	

@dynamic localTrack;

	





@end
