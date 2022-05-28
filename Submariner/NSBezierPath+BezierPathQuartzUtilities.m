//
//  NSBezierPath+BezierPathQuartzUtilities.m
//  AnimateMe
//
//  Created by Nick Paulson on 4/11/11.
//  Copyright 2011 Linebreak. All rights reserved.
//

#import "NSBezierPath+BezierPathQuartzUtilities.h"


@implementation NSBezierPath (BezierPathQuartzUtilities)
// This method works only in Mac OS X v10.2 and later.
- (CGPathRef)quartzPath
{
    NSInteger i, numElements;
    
    // Need to begin a path here.
    CGPathRef           immutablePath = NULL;
    
    // Then draw the path elements.
    numElements = [self elementCount];
    if (numElements > 0)
    {
        CGMutablePathRef    path = CGPathCreateMutable();
        NSPoint             points[3];
        BOOL                didClosePath = YES;
        
        for (i = 0; i < numElements; i++)
        {
            switch ([self elementAtIndex:i associatedPoints:points])
            {
                case NSBezierPathElementMoveTo:
                    CGPathMoveToPoint(path, NULL, points[0].x, points[0].y);
                    break;
                    
                case NSBezierPathElementLineTo:
                    CGPathAddLineToPoint(path, NULL, points[0].x, points[0].y);
                    didClosePath = NO;
                    break;
                    
                case NSBezierPathElementCurveTo:
                    CGPathAddCurveToPoint(path, NULL, points[0].x, points[0].y,
                                          points[1].x, points[1].y,
                                          points[2].x, points[2].y);
                    didClosePath = NO;
                    break;
                    
                case NSBezierPathElementClosePath:
                    CGPathCloseSubpath(path);
                    didClosePath = YES;
                    break;
            }
        }
        
        // Be sure the path is closed or Quartz may not do valid hit detection.
        if (!didClosePath)
            CGPathCloseSubpath(path);
        
        immutablePath = CGPathCreateCopy(path);
        CGPathRelease(path);
    }
    
    return immutablePath;
}

@end
