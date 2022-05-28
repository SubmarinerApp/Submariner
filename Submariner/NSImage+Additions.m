//
//  NSImage+Additions.m
//  Submariner
//
//  Created by Rafaël Warnault on 11/12/11.
//
//  Copyright (c) 2011-2014, Rafaël Warnault
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  * Redistributions of source code must retain the above copyright notice, this
//  list of conditions and the following disclaimer.
//
//  * Redistributions in binary form must reproduce the above copyright notice,
//  this list of conditions and the following disclaimer in the documentation
//  and/or other materials provided with the distribution.
//
//  * Neither the name of the Read-Write.fr nor the names of its
//  contributors may be used to endorse or promote products derived from
//  this software without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
//  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
//  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
//  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//  OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
//  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "NSImage+Additions.h"
#import <Quartz/Quartz.h>


@implementation NSImage (Additions)

- (NSImage *)imageTintedWithColor:(NSColor *)tint 
{
    NSSize size = [self size];
    NSRect imageBounds = NSMakeRect(0, 0, size.width, size.height);
    
    NSImage *copiedImage = [self copy];
    
    [copiedImage lockFocus];
    
    [tint set];
    NSRectFillUsingOperation(imageBounds, NSCompositingOperationSourceAtop);
    
    [copiedImage unlockFocus];
    
    return copiedImage;
    
//    if (tint != nil) {
//        NSSize size = [self size];
//        NSRect bounds = { NSZeroPoint, size };
//        NSImage *tintedImage = [[NSImage alloc] initWithSize:size];
//        
//        [tintedImage lockFocus];
//        
//        CIFilter *colorGenerator = [CIFilter filterWithName:@"CIConstantColorGenerator"];
//        CIColor *color = [[[CIColor alloc] initWithColor:tint] autorelease];
//        
//        [colorGenerator setValue:color forKey:@"inputColor"];
//        
//        CIFilter *monochromeFilter = [CIFilter filterWithName:@"CIColorMonochrome"];
//        CIImage *baseImage = [CIImage imageWithData:[self TIFFRepresentation]];
//        
//        [monochromeFilter setValue:baseImage forKey:@"inputImage"];             
//        [monochromeFilter setValue:[CIColor colorWithRed:0.75 green:0.75 blue:0.75] forKey:@"inputColor"];
//        [monochromeFilter setValue:[NSNumber numberWithFloat:1.0] forKey:@"inputIntensity"];
//        
//        CIFilter *compositingFilter = [CIFilter filterWithName:@"CIMultiplyCompositing"];
//        
//        [compositingFilter setValue:[colorGenerator valueForKey:@"outputImage"] forKey:@"inputImage"];
//        [compositingFilter setValue:[monochromeFilter valueForKey:@"outputImage"] forKey:@"inputBackgroundImage"];
//        
//        CIImage *outputImage = [compositingFilter valueForKey:@"outputImage"];
//        
//        [outputImage drawAtPoint:NSZeroPoint
//						fromRect:bounds
//					   operation:NSCompositeCopy
//						fraction:1.0];
//        
//        [tintedImage unlockFocus];  
//        
//        return [tintedImage autorelease];
//    }
//    else {
//        return [[self copy] autorelease];
//    }
}

- (NSImage*)imageCroppedToRect:(NSRect)rect
{
    NSPoint point = { -rect.origin.x, -rect.origin.y };
    NSImage *croppedImage = [[NSImage alloc] initWithSize:rect.size];
    
    [croppedImage lockFocus];
    {
        [self compositeToPoint:point operation:NSCompositingOperationCopy];
    }
    [croppedImage unlockFocus];
    
    return croppedImage;
}

@end
