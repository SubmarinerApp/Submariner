//
//  SBMusicSearchController.m
//  Submariner
//
//  Created by Rafaël Warnault on 22/08/11.
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

#import "SBMusicSearchController.h"

#import "Submariner-Swift.h"


@implementation SBMusicSearchController


+ (NSString *)nibName {
    return @"MusicSearch";
}


- (NSString*)title {
    return @"Search Results";
}


- (id)initWithManagedObjectContext:(NSManagedObjectContext *)context {
    self = [super initWithManagedObjectContext:context];
    if (self) {

    }
    return self;
}


- (void)loadView {
    [super loadView];
    
    [tracksController addObserver:self
                      forKeyPath:@"selectedObjects"
                      options:NSKeyValueObservingOptionNew
                      context:nil];
}


- (void)dealloc {
    [tracksController removeObserver:self forKeyPath:@"selectedObjects"];
}


- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if (object == tracksController && [keyPath isEqualToString:@"selectedObjects"] && self.view.window != nil) {
        [[NSNotificationCenter defaultCenter] postNotificationName: @"SBTrackSelectionChanged"
                                                            object: tracksController.selectedObjects];
    }
}


- (void)viewDidAppear {
    [super viewDidAppear];
    [[NSNotificationCenter defaultCenter] postNotificationName: @"SBTrackSelectionChanged"
                                                        object: tracksController.selectedObjects];
}


- (void)searchString:(NSString *)query {    
    NSMutableString *searchText = [NSMutableString stringWithString:query];
    
    // Remove extraenous whitespace
    while ([searchText rangeOfString:@"Â  "].location != NSNotFound) {
        [searchText replaceOccurrencesOfString:@"Â  " withString:@" " options:0 range:NSMakeRange(0, [searchText length])];
    }
    
    //Remove leading space
    if ([searchText length] != 0) [searchText replaceOccurrencesOfString:@" " withString:@"" options:0 range:NSMakeRange(0,1)];
    
    //Remove trailing space
    if ([searchText length] != 0) [searchText replaceOccurrencesOfString:@" " withString:@"" options:0 range:NSMakeRange([searchText length]-1, 1)];
    
    if ([searchText length] == 0) {
        [tracksController setFilterPredicate:[NSPredicate predicateWithFormat:@"(isLocal == YES)"]];
        return;
    }
    
    NSArray *searchTerms = [searchText componentsSeparatedByString:@" "];
    
    if ([searchTerms count] == 1) {
        NSPredicate *p = [NSPredicate predicateWithFormat:@"(isLocal == YES) AND ((itemName contains[cd] %@) OR (albumString contains[cd] %@) OR (artistString contains[cd] %@) OR (genre contains[cd] %@))", searchText, searchText, searchText, searchText];
        [tracksController setFilterPredicate:p];
    } else {
        NSMutableArray *subPredicates = [[NSMutableArray alloc] init];
        for (NSString *term in searchTerms) {
            NSPredicate *p = [NSPredicate predicateWithFormat:@"(isLocal == YES) AND ((itemName contains[cd] %@) OR (albumString contains[cd] %@) OR (artistString contains[cd] %@) OR (genre contains[cd] %@))", term, term, term, term];
            [subPredicates addObject:p];
        }
        NSPredicate *cp = [NSCompoundPredicate andPredicateWithSubpredicates:subPredicates];
        
        [tracksController setFilterPredicate:cp];
    }
}


#pragma mark - Properties

- (NSArray<SBTrack*>*) tracks {
    return [tracksController arrangedObjects];
}


- (NSInteger) selectedTrackRow {
    return tracksTableView.selectedRow;
}


- (NSArray<SBTrack*>*) selectedTracks {
    return [tracksController selectedObjects];
}


#pragma mark - IBActions


#pragma mark -
#pragma mark NSTableView (Drag & Drop)

- (id<NSPasteboardWriting>)tableView:(NSTableView *)tableView pasteboardWriterForRow:(NSInteger)row {
    if (tableView == tracksTableView) {
        SBTrack *track = tracksController.arrangedObjects[row];
        return [[SBLibraryItemPasteboardWriter alloc] initWithItem: track index: row];
    }
    return nil;
}

@end
