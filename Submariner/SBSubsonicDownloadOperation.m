//
//  SBSubsonicDownloadOperation.m
//  Submariner
//
//  Created by Rafaël Warnault on 16/06/11.
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

#import "SBSubsonicDownloadOperation.h"
#import "SBImportOperation.h"

#import "SBLibrary.h"
#import "SBTrack.h"
#import "SBServer.h"
#import "SBOperationActivity.h"

#import "NSURL+Parameters.h"
#import "NSOperationQueue+Shared.h"
#import "NSManagedObjectContext+Fetch.h"
#import "NSString+Hex.h"





NSString *SBSubsonicDownloadStarted     = @"SBSubsonicDownloadStarted";
NSString *SBSubsonicDownloadFinished    = @"SBSubsonicDownloadFinished";





@interface SBSubsonicDownloadOperation (Private)
- (void)startDownloadingURL:(NSURL *)url;
@end





@implementation SBSubsonicDownloadOperation


@synthesize trackID;
@synthesize activity;


- (id)initWithManagedObjectContext:(NSManagedObjectContext *)mainContext
{
    self = [super initWithManagedObjectContext:mainContext];
    if (self) {
        // Initialization code here.
        SBLibrary *library = (SBLibrary *)[[self mainContext] fetchEntityNammed:@"Library" withPredicate:nil error:nil];
        libraryID = [library objectID];
        
        activity = [[SBOperationActivity alloc] init];
        [self.activity setIndeterminated:YES];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:SBSubsonicDownloadStarted
                                                            object:self.activity];
    }
    
    return self;
}




- (void)finish {
    [[NSNotificationCenter defaultCenter] postNotificationName:SBSubsonicDownloadFinished
                                                        object:self.activity];
    
    [super finish];
}


- (void)main {
    @autoreleasepool {
    
        SBTrack *track = (SBTrack *)[[self threadedContext] objectWithID:trackID];
        
        // prepare activity stack
        [self.activity setOperationName:[NSString stringWithFormat:@"Download « %@ »", track.itemName]];
        [self.activity setOperationInfo:@"Pending Request..."];
        
        // prepare download URL
        NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
        [track.server getBaseParameters: parameters];
        [parameters setValue:track.id forKey:@"id"];
        
        NSURL *url = [NSURL URLWithString:track.server.url command:@"rest/download.view" parameters:parameters];
   
        // Hey !!! NSURLDownload seems to not working in a separated thread !?
        // Ok, so call it on the main thread, weird...
        [self performSelectorOnMainThread:@selector(startDownloadingURL:) withObject:url waitUntilDone:YES];
    
    }
}



- (void)startDownloadingURL:(NSURL *)url
{    
    // Create the request.
    NSURLRequest *theRequest = [NSURLRequest requestWithURL:url
                                                cachePolicy:NSURLRequestUseProtocolCachePolicy
                                            timeoutInterval:30.0];
    
    // Create the connection with the request and start loading the data.
    NSURLDownload  *theDownload = [[NSURLDownload alloc] initWithRequest:theRequest delegate:self];

    if (!theDownload) {
        // inform the user that the download failed.
        NSLog(@"ERROR : Download failed.");
    }
}



#pragma mark -
#pragma mark NSURLDownload delegate (Destination)

- (void)download:(NSURLDownload *)download decideDestinationWithSuggestedFilename:(NSString *)filename
{    
    // get a temporaty path
    NSURL *tempURL = [NSURL temporaryFileURL];
    tmpDestinationPath = [[tempURL absoluteString] stringByAppendingPathExtension:@"mp3"];
        
    [download setDestination:tmpDestinationPath allowOverwrite:NO];
}




#pragma mark -
#pragma mark NSURLDownload delegate (Authentification)

- (BOOL)download:(NSURLDownload *)download canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace {
    return YES;
}

-(void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    if ([challenge previousFailureCount] == 0) {
        
        SBTrack *track = (SBTrack *)[[self threadedContext] objectWithID:trackID];
        
        NSURLCredential *newCredential;
        newCredential = [NSURLCredential credentialWithUser:track.server.username
                                                   password:track.server.password
                                                persistence:NSURLCredentialPersistenceNone];
        
        [[challenge sender] useCredential:newCredential
               forAuthenticationChallenge:challenge];
        
    } else {
        [[challenge sender] cancelAuthenticationChallenge:challenge];
    }
}




#pragma mark -
#pragma mark NSURLDownload delegate (State)

- (void)downloadDidBegin:(NSURLDownload *)download {
    
    [self.activity setIndeterminated:NO];
    [self.activity setOperationInfo:@"Downloading Track..."];
}


- (void)download:(NSURLDownload *)download didFailWithError:(NSError *)error
{    
    // Release the connection.
    
    // Inform the user.
    [NSApp performSelectorOnMainThread:@selector(presentError:) withObject:error waitUntilDone:NO];
    [self finish];
}

- (void)downloadDidFinish:(NSURLDownload *)download
{    
    // Release the connection.

    // Do something with the data.
    [self.activity setOperationInfo:@"Importing Track..."];
        
    // 3. import to library on write endx
    SBImportOperation *op = [[SBImportOperation alloc] initWithManagedObjectContext:[self mainContext]];
    [op setFilePaths:[NSArray arrayWithObject:tmpDestinationPath]];
    [op setLibraryID:libraryID];
    [op setRemoteTrackID:trackID];
    [op setCopy:YES];
    [op setRemove:YES];
    
    [[NSOperationQueue sharedDownloadQueue] addOperation:op];
    
    [self finish];
}



#pragma mark -
#pragma mark NSURLDownload delegate (Progress)

- (void)setDownloadResponse:(NSURLResponse *)aDownloadResponse
{
    
    long long expectedLength = [downloadResponse expectedContentLength];
    [self.activity setOperationTotal:[NSNumber numberWithLongLong:expectedLength]];
    
    // downloadResponse is an instance variable defined elsewhere.
    downloadResponse = aDownloadResponse;
}

- (void)download:(NSURLDownload *)download didReceiveResponse:(NSURLResponse *)response
{
    // Reset the progress, this might be called multiple times.
    // bytesReceived is an instance variable defined elsewhere.
    bytesReceived = 0;
    
    // Retain the response to use later.
    [self setDownloadResponse:response];
}

- (void)download:(NSURLDownload *)download didReceiveDataOfLength:(unsigned)length
{
    long long expectedLength = [downloadResponse expectedContentLength];    
    bytesReceived = bytesReceived + length;
    
    [self.activity setOperationCurrent:[NSNumber numberWithLongLong:bytesReceived]];
    
    NSString *sizeProgress = [NSString stringWithFormat:@"%.2f/%.2f MB", (float)bytesReceived/1024/1024, (float)expectedLength/1024/1024];
    [self.activity setOperationInfo:sizeProgress];
    
    if (expectedLength != NSURLResponseUnknownLength) {
        // If the expected content length is
        // available, display percent complete.
        float percentComplete = (bytesReceived/(float)expectedLength)*100.0;
        [self.activity setOperationPercent:[NSNumber numberWithFloat:percentComplete]];

    } else {
        // If the expected content length is
        // unknown, just log the progress.
        //NSLog(@"Bytes received - %ld", bytesReceived);
    }
}


@end
