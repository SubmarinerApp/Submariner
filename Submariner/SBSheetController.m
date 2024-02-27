//
//  BWSheetController.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "SBSheetController.h"

@implementation SBSheetController



@synthesize parentWindow, sheet, delegate, managedObjectContext;



- (void)awakeFromNib
{
	// Hack so the sheet doesn't appear at launch in Cocoa Simulator (or in the actual app if "Visible at Launch" is checked)
	[sheet setAlphaValue:0];
	[sheet performSelector:@selector(orderOut:) withObject:nil afterDelay:0];
	
	// If the sheet has a toolbar or a bottom bar, make sure those elements can't move the window (private API)
	[sheet setMovable:NO];
}

- (id)initWithCoder:(NSCoder *)decoder;
{
    if ((self = [super init]) != nil)
	{
		NSWindowController *tempSheetController = [decoder decodeObjectForKey:@"DXSCSheet"];
		NSWindowController *tempParentWindowController = [decoder decodeObjectForKey:@"DXSCParentWindow"];
		
		sheet = [tempSheetController window];
		parentWindow = [tempParentWindowController window];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder*)coder
{	
	NSWindowController *tempSheetController = [[NSWindowController alloc] initWithWindow:sheet];
	NSWindowController *tempParentWindowController = [[NSWindowController alloc] initWithWindow:parentWindow];
	
	[coder encodeObject:tempSheetController forKey:@"DXSCSheet"];
	[coder encodeObject:tempParentWindowController forKey:@"DXSCParentWindow"];
}

- (IBAction)openSheet:(id)sender
{
	[sheet setAlphaValue:1];
    [parentWindow beginSheet: sheet completionHandler:^(NSModalResponse returnCode) {}];
}

- (IBAction)closeSheet:(id)sender
{
	[sheet orderOut:nil];
	[NSApp endSheet:sheet];
}

- (IBAction)cancelSheet:(id)sender 
{
    [sheet orderOut:nil];
	[NSApp endSheet:sheet];
}


@end
