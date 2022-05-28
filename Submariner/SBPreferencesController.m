//
//  UPreferences.m
//  Submariner
//
//  Created by Rafaël Warnault on 20/03/11.
//  Copyright 2011 Read-Write.fr. All rights reserved.
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

#import "SBPreferencesController.h"
#import "SBAppDelegate.h"



@implementation SBPreferencesController


#pragma mark -
#pragma mark Class Methods

+ (NSString *)nibName
{
    return @"Preferences";
}



#pragma mark -
#pragma mark Instance Methods

-(void)awakeFromNib{
	[self.window setContentSize:[playerPreferenceView frame].size];
	[[self.window contentView] addSubview:playerPreferenceView];
	[bar setSelectedItemIdentifier:@"Player"];
	[self.window center];
    
    NSInteger selectedBehavior = [[NSUserDefaults standardUserDefaults] integerForKey:@"playerBehavior"];
    [playerBehaviorMatrix selectCellAtRow:selectedBehavior column:0];
    
    [[NSUserDefaults standardUserDefaults] addObserver:self
                                            forKeyPath:@"maxBitRate" 
                                               options:NSKeyValueObservingOptionNew 
                                               context:nil];
}

- (void)dealloc {
    [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:@"maxBitRate"];
    [super dealloc];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if(object == [NSUserDefaults standardUserDefaults] && [keyPath isEqualToString:@"maxBitRate"]) {
        NSInteger newTag = [[change valueForKey:NSKeyValueChangeNewKey] integerValue];
        if(newTag < 320 && newTag > 0) {
            NSAlert *alert = [NSAlert alertWithMessageText:@"Submariner limitation"
                                             defaultButton:@"OK"
                                           alternateButton:nil
                                               otherButton:nil
                                 informativeTextWithFormat:@"Submariner is not able to caculate the progression time below 320 kbit/s bitrate efficiently depending of the transcoded source bitrate. You could not seek into the timeline and time information will be unreliable. However, Subamriner will stream, play and cache download your track properly with the desired bitrate."];
            
            [alert setAlertStyle:NSAlertStyleInformational];
            [alert runModal];
        }
    }
}


-(NSView *)viewForTag:(NSInteger)tag {
    NSView *view = nil;
	switch(tag) {
		case 0: default:    view = playerPreferenceView; break;
		case 1:             view = serversPreferenceView; break;
		case 2:             view = playerPreferenceView; break;
		case 3:             view = appearancePreferenceView; break;
        case 4:             view = updatesPreferenceView; break;
        case 5:             view = subsonicPreferenceView; break;
	}
    return view;
}


-(NSRect)newFrameForNewContentView:(NSView *)view {
	
    NSRect newFrameRect = [self.window frameRectForContentRect:[view frame]];
    NSRect oldFrameRect = [self.window frame];
    NSSize newSize = newFrameRect.size;
    NSSize oldSize = oldFrameRect.size;    
    NSRect frame = [self.window frame];
    
    frame.size = newSize;
    frame.origin.y -= (newSize.height - oldSize.height);
    
    return frame;
}



-(NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar {
	return [[toolbar items] valueForKey:@"itemIdentifier"];
}


-(IBAction)switchView:(id)sender {
	
	NSInteger tag = [sender tag];
	
	NSView *view = [self viewForTag:tag];
	NSView *previousView = [self viewForTag: currentViewTag];
	currentViewTag = tag;
	NSRect newFrame = [self newFrameForNewContentView:view];
	
	[NSAnimationContext beginGrouping];
	[[NSAnimationContext currentContext] setDuration:0.1];
	
	if ([[NSApp currentEvent] modifierFlags] & NSShiftKeyMask)
	    [[NSAnimationContext currentContext] setDuration:1.0];
	
	[[[self.window contentView] animator] replaceSubview:previousView with:view];
	[[self.window animator] setFrame:newFrame display:YES];
	
	[NSAnimationContext endGrouping];
	
}


- (IBAction)setPlayerBehavior:(id)sender {
    NSInteger selectedBehavior = [sender selectedRow];
    [[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithInteger:selectedBehavior] 
                                             forKey:@"playerBehavior"];
}


- (IBAction)chooseDownloadLocation:(id)sender {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    NSString *downloadLocation = [[[NSUserDefaults standardUserDefaults] valueForKey:@"downloadLocation"] stringByResolvingSymlinksInPath];
    
    [openPanel setCanChooseFiles:NO];
    [openPanel setCanChooseDirectories:YES];
    [openPanel setCanCreateDirectories:YES];
    
    [openPanel beginSheetForDirectory:downloadLocation
                                file:nil
                                types:nil
                       modalForWindow:[self window]
                        modalDelegate:self
                       didEndSelector:@selector(downloadPanelDidEnd:returnCode:contextInfo:)
                          contextInfo:nil];
}


- (void)downloadPanelDidEnd: (NSOpenPanel *)panel returnCode: (NSInteger)returnCode contextInfo: (void *)contextInfo {
    
    if(returnCode == NSAlertDefaultReturn) {
        NSString *newLocation = [panel directory];
        [[NSUserDefaults standardUserDefaults] setObject:newLocation forKey:@"downloadLocation"];
        
        [downloadLocationPopUp removeItemAtIndex:0];
        
        NSString *downloadLocation = [[[NSUserDefaults standardUserDefaults] valueForKey:@"downloadLocation"] stringByResolvingSymlinksInPath];
        NSImage *fileIcon = [[NSWorkspace sharedWorkspace] iconForFile:downloadLocation];
        NSString *downloadLocationName = [downloadLocation lastPathComponent];
        
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:downloadLocationName action:nil keyEquivalent:@""];
        [item setOnStateImage:fileIcon];
        
        [downloadLocationPopUp insertItemWithTitle:downloadLocationName atIndex:0];
        [downloadLocationPopUp selectItemAtIndex:0];
    }
}


@end
