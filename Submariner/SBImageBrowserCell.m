/*
 
 File:		ImageBrowserCell.m
 
 Abstract:	IKImageBrowserView is a view that can display and browse a 
 large amount of images and movies. This sample code demonstrates 
 how to use the view in a Cocoa Application.
 
 Version:	1.0
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the
 following terms, and your use, installation, modification or
 redistribution of this Apple software constitutes acceptance of these
 terms.  If you do not agree with these terms, please do not use,
 install, modify or redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software. 
 Neither the name, trademarks, service marks or logos of Apple Inc.
 may be used to endorse or promote products derived from the Apple
 Software without specific prior written permission from Apple.  Except
 as expressly stated in this notice, no other rights or licenses, express
 or implied, are granted by Apple herein, including but not limited to
 any patent rights that may be infringed by your derivative works or by
 other works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright © 2009 Apple Inc. All Rights Reserved
 
 */


#import "SBImageBrowserCell.h"



@implementation SBImageBrowserCell

//---------------------------------------------------------------------------------
// layerForType:
//
// provides the layers for the given types
//---------------------------------------------------------------------------------
- (CALayer *) layerForType:(NSString*) type
{
	CGColorRef color;
	
	//retrieve some usefull rects
	NSRect frame = [self frame];

	/* place holder layer */
	if(type == IKImageBrowserCellPlaceHolderLayer){
	}
	
	/* foreground layer */
	if(type == IKImageBrowserCellForegroundLayer){
	}

	/* selection layer */
	if(type == IKImageBrowserCellSelectionLayer){

		//create a selection layer
		CALayer *selectionLayer = [CALayer layer];
		selectionLayer.frame = CGRectMake(0, 0, frame.size.width, frame.size.height);
		
		//set a background color
        color = [[NSColor selectedContentBackgroundColor] CGColor];
		[selectionLayer setBackgroundColor:color];
		
		//set a border color
		[selectionLayer setBorderColor:color];

		[selectionLayer setBorderWidth:1.0];
		[selectionLayer setCornerRadius:5];
		
		return selectionLayer;
	}
	
	/* background layer */
	if(type == IKImageBrowserCellBackgroundLayer){
	}
	
	return nil;
}

//---------------------------------------------------------------------------------
// imageFrame
//
// define where the image should be drawn
//---------------------------------------------------------------------------------
- (NSRect) imageFrame
{
	//get default imageFrame and aspect ratio
	NSRect imageFrame = [super imageFrame];
	
	if(imageFrame.size.height == 0 || imageFrame.size.width == 0) return NSZeroRect;
	
	float aspectRatio =  imageFrame.size.width / imageFrame.size.height;
	
	// compute the rectangle included in container with a margin of at least 10 pixel at the bottom, 5 pixel at the top and keep a correct  aspect ratio
	NSRect container = [self imageContainerFrame];
	container = NSInsetRect(container, 8, 8);
	
	if(container.size.height <= 0) return NSZeroRect;
	
	float containerAspectRatio = container.size.width / container.size.height;
	
	if(containerAspectRatio > aspectRatio){
		imageFrame.size.height = container.size.height;
		imageFrame.origin.y = container.origin.y;
		imageFrame.size.width = imageFrame.size.height * aspectRatio;
		imageFrame.origin.x = container.origin.x + (container.size.width - imageFrame.size.width)*0.5;
	}
	else{
		imageFrame.size.width = container.size.width;
		imageFrame.origin.x = container.origin.x;		
		imageFrame.size.height = imageFrame.size.width / aspectRatio;
		imageFrame.origin.y = container.origin.y + container.size.height - imageFrame.size.height;
	}
	
	//round it
	imageFrame.origin.x = floorf(imageFrame.origin.x);
	imageFrame.origin.y = floorf(imageFrame.origin.y);
	imageFrame.size.width = ceilf(imageFrame.size.width);
	imageFrame.size.height = ceilf(imageFrame.size.height);
	
	return imageFrame;
}

//---------------------------------------------------------------------------------
// imageContainerFrame
//
// override the default image container frame
//---------------------------------------------------------------------------------
- (NSRect) imageContainerFrame
{
	NSRect container = [super frame];
	
	//make the image container 15 pixels up
	container.origin.y += 15;
	container.size.height -= 15;
	
	return container;
}

//---------------------------------------------------------------------------------
// titleFrame
//
// override the default frame for the title
//---------------------------------------------------------------------------------
- (NSRect) titleFrame
{
	//get the default frame for the title
	NSRect titleFrame = [super titleFrame];
	
	//move the title inside the 'photo' background image
	NSRect container = [self frame];
	titleFrame.origin.y = container.origin.y + 3;
	
	//make sure the title has a 7px margin with the left/right borders
	float margin = titleFrame.origin.x - (container.origin.x + 7);
	if(margin < 0)
		titleFrame = NSInsetRect(titleFrame, -margin, 0);
	
	return titleFrame;
}

//---------------------------------------------------------------------------------
// selectionFrame
//
// make the selection frame a little bit larger than the default one
//---------------------------------------------------------------------------------
- (NSRect) selectionFrame
{
	return NSInsetRect([self frame], -5, -5);
}

@end
