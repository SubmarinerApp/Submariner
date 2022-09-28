//
//  NSString+File.h
//  Submariner
//
//  Created by Calvin Buckley on 2022-09-27.
//  Copyright © 2022 Calvin Buckley. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (File)

- (BOOL) isValidFileName;
- (NSString*)extensionForMIMEType;

@end

NS_ASSUME_NONNULL_END
