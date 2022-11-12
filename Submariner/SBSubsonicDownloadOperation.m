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
#import "NSString+File.h"




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
        
        // XXX: Stream URL?
        NSURL *url = [NSURL URLWithString:track.server.url command:@"rest/download.view" parameters:parameters];
        // No more issues calling this outside of main, I bet
        [self startDownloadingURL: url];
    
    }
}



- (void)startDownloadingURL:(NSURL *)url
{    
    // Create the request.
    NSURLRequest *theRequest = [NSURLRequest requestWithURL:url
                                                cachePolicy:NSURLRequestUseProtocolCachePolicy
                                            timeoutInterval:30.0];
    
    // Create the connection with the request and start loading the data.
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate: self delegateQueue: nil];
    NSURLSessionDownloadTask *task = [session downloadTaskWithRequest: theRequest];

    // This was on the delegate for the old NSURLDownload begin
    [self.activity setIndeterminated:NO];
    [self.activity setOperationInfo:@"Downloading Track..."];

    [task resume];
}




#pragma mark -
#pragma mark NSURLSession delegate (Authentification)

// we don't need to implement the one without task:
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler {
    // XXX: Check the authentication type if it's NSURLAuthenticationMethodHTTPBasic or NSURLAuthenticationMethodServerTrust
    if ([challenge previousFailureCount] == 0) {
        
        SBTrack *track = (SBTrack *)[[self threadedContext] objectWithID:trackID];
        
        NSURLCredential *newCredential;
        newCredential = [NSURLCredential credentialWithUser:track.server.username
                                                   password:track.server.password
                                                persistence:NSURLCredentialPersistenceNone];
        
        //[[challenge sender] useCredential:newCredential
        //       forAuthenticationChallenge:challenge];
        completionHandler(NSURLSessionAuthChallengeUseCredential, newCredential);
        
    } else {
        // XXX: Better handling here?
        //[[challenge sender] cancelAuthenticationChallenge:challenge];
        completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
    }
}


#pragma mark -
#pragma mark NSURLSession delegate (State)

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    // we handle success in the didFinishDownloadingToURL callback
    if (error != nil) {
        NSLog(@"Error in NSURLSession: %@", error);
        [NSApp performSelectorOnMainThread:@selector(presentError:) withObject:error waitUntilDone:NO];
        [self finish];
        [session invalidateAndCancel];
    }
}

- (void)URLSession:(nonnull NSURLSession *)session downloadTask:(nonnull NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(nonnull NSURL *)location {
    // Do something with the data.
    [self.activity setOperationInfo:@"Importing Track..."];
    
    // We need to give it an audio extension.
    NSString *mimeType = downloadTask.response.MIMEType;
    NSString *extension = [mimeType extensionForMIMEType] ?: @"mp3"; // fallback
    NSURL *tempURL = [[NSURL temporaryFileURL] URLByAppendingPathExtension: extension];
    NSString *newTempPath = [tempURL path];
    NSError *moveError = nil;
    [[NSFileManager defaultManager] moveItemAtPath:location.path toPath: newTempPath error:&moveError];
    if (moveError) {
        NSLog(@"Error moving %@ to %@: %@", location.path, newTempPath, moveError);
    }
        
    // 3. import to library on write endx
    SBImportOperation *op = [[SBImportOperation alloc] initWithManagedObjectContext:[self mainContext]];
    [op setFilePaths:[NSArray arrayWithObject: newTempPath]];
    [op setLibraryID:libraryID];
    [op setRemoteTrackID:trackID];
    [op setCopyFile:YES];
    [op setRemove:YES];
    
    [[NSOperationQueue sharedDownloadQueue] addOperation:op];
    
    [self finish];
    [session invalidateAndCancel];
}


#pragma mark -
#pragma mark NSURLSession delegate (Progress)

- (void)URLSession:(nonnull NSURLSession *)session downloadTask:(nonnull NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    
    [self.activity setOperationCurrent:[NSNumber numberWithLongLong:totalBytesWritten]];
    [self.activity setOperationTotal:[NSNumber numberWithLongLong:totalBytesExpectedToWrite]];
    
    if (totalBytesExpectedToWrite != NSURLSessionTransferSizeUnknown) {
        
        NSString *sizeProgress = [NSString stringWithFormat:@"%.2f/%.2f MB", (float)totalBytesWritten/1024/1024, (float)totalBytesExpectedToWrite/1024/1024];
        [self.activity setOperationInfo:sizeProgress];
        // If the expected content length is
        // available, display percent complete.
        float percentComplete = (totalBytesExpectedToWrite/(float)totalBytesExpectedToWrite)*100.0;
        [self.activity setOperationPercent:[NSNumber numberWithFloat:percentComplete]];

    } else {
        // If the expected content length is
        // unknown, just log the progress.
        NSString *sizeProgress = [NSString stringWithFormat:@"%.2f MB", (float)totalBytesWritten/1024/1024];
        [self.activity setOperationInfo:sizeProgress];
        //NSLog(@"Bytes received - %ld", bytesReceived);
    }
}


@end
