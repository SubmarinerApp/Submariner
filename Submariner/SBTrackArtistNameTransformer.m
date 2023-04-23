//
//  SBTrackArtistNameTransformer.m
//  Submariner
//
//  Created by Calvin Buckley on 2022-09-13.
//  Copyright © 2022 Calvin Buckley. All rights reserved.
//

#import "SBTrackArtistNameTransformer.h"

#import "Submariner-Swift.h"

@implementation SBTrackArtistNameTransformer


+ (Class)transformedValueClass {
    return [NSString class];
}

+ (BOOL)allowsReverseTransformation {
    return NO;
}

- (id)transformedValue:(id)value {
    SBTrack *track = (SBTrack*)value;
    // return album artist if we don't have an artist
    if (track.artistName == nil || [track.artistName isEqualToString: @""]) {
        return track.album.artist.itemName;
    }
    return track.artistName;
}

@end
