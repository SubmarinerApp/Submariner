//
//  SBUserViewController.m
//  Submariner
//
//  Created by Rafaël Warnault on 13/06/11.
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

#import "SBServerUserViewController.h"
#import "SBPrioritySplitViewDelegate.h"
#import "SBSubsonicParsingOperation.h"
#import "SBServer.h"




#define LEFT_VIEW_INDEX 0
#define LEFT_VIEW_PRIORITY 0
#define LEFT_VIEW_MINIMUM_WIDTH 100.0

#define MAIN_VIEW_INDEX 1
#define MAIN_VIEW_PRIORITY 1
#define MAIN_VIEW_MINIMUM_WIDTH 250.0




@interface SBServerUserViewController (Private)
- (void)subsonicNowPlayingUpdated:(NSNotification *)notification;
- (void)subsonicCoversUpdatedNotification:(NSNotification *)notification;
- (void)startRefreshNowPlayingTimer;
- (void)refreshAll;
@end



@implementation SBServerUserViewController

@synthesize nowPlayingSortDescriptors;



+ (NSString *)nibName {
    return @"ServerUsers";
}


- (NSString*)title {
    return [NSString stringWithFormat: @"Now Playing on %@", self.server.resourceName];
}


- (id)initWithManagedObjectContext:(NSManagedObjectContext *)context {
    self = [super initWithManagedObjectContext:context];
    if (self) {
        NSSortDescriptor *descr = [NSSortDescriptor sortDescriptorWithKey:@"minutesAgo" ascending:YES];
        nowPlayingSortDescriptors = [NSArray arrayWithObject:descr];
        
        
        // timers
        if([[NSUserDefaults standardUserDefaults] boolForKey:@"autoRefreshNowPlaying"])
            [self startRefreshNowPlayingTimer];
    }
    return self;
}


- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                    name:SBSubsonicNowPlayingUpdatedNotification 
                                                  object:nil];
    
}


- (void)loadView {
    [super loadView];
    
    
    // add add subsonic observers
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(subsonicNowPlayingUpdated:)
                                                 name:SBSubsonicNowPlayingUpdatedNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(subsonicCoversUpdatedNotification:) 
                                                 name:SBSubsonicCoversUpdatedNotification
                                               object:nil];
    
    [[NSUserDefaults standardUserDefaults] addObserver:self
                                            forKeyPath:@"autoRefreshNowPlaying"
                                               options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld)
                                               context:nil];

}


- (void)viewDidLoad {
    [self refreshAll];
}





#pragma mark -
#pragma mark IBActions

- (IBAction)refreshNowPlaying:(id)sender {
    
    
    // clean existing now playing objects
    NSFetchRequest * allCars = [[NSFetchRequest alloc] init];
    [allCars setEntity:[NSEntityDescription entityForName:@"NowPlaying" inManagedObjectContext:self.managedObjectContext]];
    [allCars setIncludesPropertyValues:NO]; //only fetch the managedObjectID
    
    NSError * error = nil;
    NSArray * cars = [self.managedObjectContext executeFetchRequest:allCars error:&error];
    //error handling goes here
    for (NSManagedObject * car in cars) {
        [self.managedObjectContext deleteObject:car];
        //[nowPlayingController removeObject:car];
    }
    
    // process changes inside CD graph
    [self.managedObjectContext processPendingChanges];
    
    // request new now playing objects
    [server getNowPlaying];
}


- (void)refreshAll {
    [self refreshNowPlaying:nil];
}



#pragma mark -
#pragma mark Observers

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if([keyPath isEqualToString:@"autoRefreshNowPlaying"]) {
        [self startRefreshNowPlayingTimer];
    }  
}





#pragma mark -
#pragma mark Subsonic Notifications

- (void)subsonicNowPlayingUpdated:(NSNotification *)notification {
    
}

- (void)subsonicCoversUpdatedNotification:(NSNotification *)notification {
    // has to be done on UI thread, of course
    dispatch_async(dispatch_get_main_queue(), ^{
        [self->nowPlayingController rearrangeObjects];
        [self->nowPlayingCollectionView setNeedsDisplay:YES];
    });
}



#pragma mark -
#pragma mark Private

- (void)startRefreshNowPlayingTimer {
    if([[NSUserDefaults standardUserDefaults] boolForKey:@"autoRefreshNowPlaying"]) {
        
        refreshNowPlayingTimer = [NSTimer scheduledTimerWithTimeInterval:30.0f
                                                            target:self
                                                          selector:@selector(refreshNowPlaying:)
                                                          userInfo:nil
                                                           repeats:YES];
    } else {
        if(refreshNowPlayingTimer) {
            
            [refreshNowPlayingTimer invalidate];
        }
    }
}


@end
