//
//  SBServerPodcastController.m
//  Submariner
//
//  Created by Rafaël Warnault on 23/08/11.
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

#import "SBServerPodcastController.h"
#import "SBPlayer.h"

#import "Submariner-Swift.h"

#import "NSManagedObjectContext+Fetch.h"


#pragma mark -
#pragma mark Private Interface

@interface SBServerPodcastController (Private)

@end


@implementation SBServerPodcastController

+ (NSString *)nibName {
    return @"ServerPodcasts";
}


- (NSString*)title {
    return [NSString stringWithFormat: @"Podcasts on %@", self.server.resourceName];
}



@synthesize podcastsSortDescriptors;
@synthesize episodesSortDescriptors;

#pragma mark -
#pragma mark NSView overwritten methods


- (id)initWithManagedObjectContext:(NSManagedObjectContext *)context {
    self = [super initWithManagedObjectContext:context];
    if (self) {
        NSSortDescriptor *descr1 = [NSSortDescriptor sortDescriptorWithKey:@"id" ascending:YES];
        podcastsSortDescriptors = [[NSArray alloc] initWithObjects:descr1, nil];
        
        NSSortDescriptor *descr2 = [NSSortDescriptor sortDescriptorWithKey:@"publishDate" ascending:NO];
        episodesSortDescriptors = [[NSArray alloc] initWithObjects:descr2, nil];
    }
    return self;
}

- (void)loadView {
    [super loadView];
    
    // observe album covers
    [self addObserver:self 
           forKeyPath:@"server" 
              options:(NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld) 
              context:nil];
    
    // tracks double click
    [podcastsTableView setTarget:self];
    [podcastsTableView setDoubleAction:@selector(trackDoubleClick:)];
}

- (void)dealloc {
    [self removeObserver:self forKeyPath:@"server"];
    
}


#pragma mark -
#pragma mark Observers

- (void)observeValueForKeyPath:(NSString *)keyPath 
                      ofObject:(id)object 
                        change:(NSDictionary *)change 
                       context:(void *)context {
    
    if([keyPath isEqualToString:@"server"]) {
        [podcastsController setContent:nil];
        [self.server getServerPodcasts];
    }
}



#pragma mark - 
#pragma mark IBActions

- (IBAction)trackDoubleClick:(id)sender {
    NSInteger selectedRow = [episodesTableView selectedRow];
    if(selectedRow != -1) {
        SBEpisode *clickedTrack = [[episodesController arrangedObjects] objectAtIndex:selectedRow];
        if(clickedTrack) {
            
            if([clickedTrack.episodeStatus isEqualToString:@"completed"]) {
                // add track to player
                if([[NSUserDefaults standardUserDefaults] integerForKey:@"playerBehavior"] == 1) {
                    [[SBPlayer sharedInstance] addTrackArray:[episodesController arrangedObjects] replace:YES];
                    // play track
                    [[SBPlayer sharedInstance] playTrack:clickedTrack];
                } else {
                    [[SBPlayer sharedInstance] addTrackArray:[episodesController arrangedObjects] replace:NO];
                    [[SBPlayer sharedInstance] playTrack:clickedTrack];
                }
            } else {
                NSAlert *alert = [[NSAlert alloc] init];
                [alert setAlertStyle: NSAlertStyleWarning];
                [alert setMessageText: @"Unavailable Episode"];
                NSString *informativeText = [NSString stringWithFormat: @"This podcast episode isn't available. It might still be downloading. (The current status is \"%@\".)", clickedTrack.episodeStatus];
                [alert setInformativeText: informativeText];
                [alert addButtonWithTitle: @"OK"];
                [alert runModal];
            }
        }
    }
}



@end
