//
//  BWSheetController.h
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import <Cocoa/Cocoa.h>

@interface SBSheetController : NSObject
{
    NSManagedObjectContext *managedObjectContext;
	NSWindow *sheet;
	NSWindow *parentWindow;
	id delegate;
}

@property (readwrite, strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, strong) IBOutlet NSWindow *sheet, *parentWindow;
@property (nonatomic, strong) IBOutlet id delegate;

- (IBAction)openSheet:(id)sender;
- (IBAction)closeSheet:(id)sender;
- (IBAction)cancelSheet:(id)sender;

@end
