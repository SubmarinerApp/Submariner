//
//  SBRepeatModeTransformer.h
//  Submariner
//
//  Created by Calvin Buckley on 2022-05-23.
//  Copyright © 2022 Calvin Buckley. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SBPlayer.h"

NS_ASSUME_NONNULL_BEGIN

@interface SBRepeatModeTransformer : NSValueTransformer
- (id)initWithMode:(SBPlayerRepeatMode)newMode;
@end

NS_ASSUME_NONNULL_END
