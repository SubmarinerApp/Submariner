//
//  SBClient.m
//  Sub
//
//  Created by Rafaël Warnault on 14/05/11.
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

#import "SBClientController.h"
#import "SBSubsonicParsingOperation.h"

#import "NSManagedObjectContext+Fetch.h"

#import "Submariner-Swift.h"


@interface SBClientController (Private)
- (void)unplayAllTracks;
- (void)requestWithURL:(NSURL *)url requestType:(SBSubsonicRequestType)type coverID:(NSString*) coverID searchResult:(SBSearchResult*)searchResult;
- (void)requestWithURL:(NSURL *)url requestType:(SBSubsonicRequestType)type coverID:(NSString*) coverID;
- (void)requestWithURL:(NSURL *)url requestType:(SBSubsonicRequestType)type searchResult:(SBSearchResult*)searchResult;
- (void)requestWithURL:(NSURL *)url requestType:(SBSubsonicRequestType)type;
@end



@implementation SBClientController


@synthesize managedObjectContext;
@synthesize delegate;
@synthesize connected;
@synthesize server;
@synthesize librarySection;
@synthesize remotePlaylistsSection;
@synthesize podcastsSection;
@synthesize radiosSection;
@synthesize searchsSection;
@synthesize home;
@synthesize library;
@synthesize isConnecting;
@synthesize queue;


#pragma mark -
#pragma mark LifeCycle

- (id)initWithManagedObjectContext:(NSManagedObjectContext *)context
{
    self = [super init];
    if (self) {
        parameters = [[NSMutableDictionary alloc] init];
        queue = [[NSOperationQueue alloc] init];
        [queue setMaxConcurrentOperationCount:1];
        managedObjectContext = context;
        connected = NO;
        isConnecting = NO;
        numberOfElements = 0;

    }
    
    return self;
}






#pragma mark -
#pragma mark Private




- (void)requestWithURL:(NSURL *)url requestType:(SBSubsonicRequestType)type coverID:(NSString*) coverID searchResult:(SBSearchResult*)searchResult {
	NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL: url];
	NSString *loginString = [NSString stringWithFormat: @"%@:%@", server.username, server.password];
	NSData *loginData = [loginString dataUsingEncoding: NSUTF8StringEncoding];
	NSString *base64login = [loginData base64EncodedStringWithOptions: 0];
	NSString *authHeader = [NSString stringWithFormat: @"Basic %@", base64login];
	configuration.HTTPAdditionalHeaders = @{@"Authorization": authHeader};
	NSURLSessionDataTask *httpTask = [session dataTaskWithRequest: request completionHandler:
		^(NSData *data, NSURLResponse *response, NSError *error) {
		dispatch_async(dispatch_get_main_queue(), ^{
		NSLog(@"Handling %@", url);
		if (error != nil) {
			NSLog(@"Error in requddestWithURL: %@", error);
			[NSApp presentError: error];
			return;
		}
		if (response == nil) {
			NSLog(@"No response in requestWithURL");
			return;
		}
		NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
		NSInteger statusCode = [httpResponse statusCode];
		NSLog(@"Status code is %ld", (long)statusCode);
		if (statusCode!= 200) {
			NSError *newError = nil;
			NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
			switch (statusCode) {
			case 400: [userInfo setValue:@"Bad request" forKey:NSLocalizedDescriptionKey];
				break;
			case 401: [userInfo setValue:@"Unauthorized" forKey:NSLocalizedDescriptionKey];
				break;
			case 402: [userInfo setValue:@"Payment Required" forKey:NSLocalizedDescriptionKey];
				break;
			case 403: [userInfo setValue:@"Forbidden" forKey:NSLocalizedDescriptionKey];
				break;
			case 404: [userInfo setValue:@"Not Found" forKey:NSLocalizedDescriptionKey];
				break;
			case 500: [userInfo setValue:@"Internal Error" forKey:NSLocalizedDescriptionKey];
				break;
			case 501: [userInfo setValue:@"Not Implemented" forKey:NSLocalizedDescriptionKey];
				break;
			case 502: [userInfo setValue:@"Service temporarily overloaded" forKey:NSLocalizedDescriptionKey];
				break;
			case 503: [userInfo setValue:@"Gateway timeout" forKey:NSLocalizedDescriptionKey];
				break;
			default: [userInfo setValue:@"Bad request" forKey:NSLocalizedDescriptionKey];
				break;
			}
			newError = [NSError errorWithDomain:NSPOSIXErrorDomain code: statusCode userInfo:userInfo];
			[NSApp presentError: newError];
			//[newError release];
			return;
		}

		SBSubsonicParsingOperation *operation = [[SBSubsonicParsingOperation alloc]
			initWithManagedObjectContext:self.managedObjectContext
			client:self
			requestType:type
			server:[self.server objectID]
			xml: data
            mimeType: response.MIMEType];
		if (type == SBSubsonicRequestGetCoverArt) {
			[operation setCurrentCoverID:coverID];
		} else if (type == SBSubsonicRequestSearch) {
			[operation setCurrentSearch:searchResult];
		} else {
			[[NSOperationQueue sharedServerQueue] cancelAllOperations];
		}
		[[NSOperationQueue sharedServerQueue] addOperation:operation];
		});
	}];
	[httpTask resume];
}

- (void)requestWithURL:(NSURL *)url requestType:(SBSubsonicRequestType)type coverID:(NSString*) coverID {
    NSParameterAssert(coverID != nil);
    [self requestWithURL:url requestType:type coverID:coverID searchResult:nil];
}

- (void)requestWithURL:(NSURL *)url requestType:(SBSubsonicRequestType)type searchResult:(SBSearchResult*)searchResult {
    NSParameterAssert(searchResult != nil);
    [self requestWithURL:url requestType:type coverID:nil searchResult:searchResult];
}

- (void)requestWithURL:(NSURL *)url requestType:(SBSubsonicRequestType)type {
    [self requestWithURL:url requestType:type coverID:nil searchResult:nil];
}

#pragma mark -
#pragma mark Request Messages

- (void)connectToServer:(SBServer *)aServer {
    [server getBaseParameters: parameters];
    NSURL *url = [NSURL URLWithString:server.url command:@"rest/ping.view" parameters:parameters];
    [self requestWithURL:url requestType:SBSubsonicRequestPing];
}

- (void)getLicense {
    NSURL *url = [NSURL URLWithString:server.url command:@"rest/getLicense.view" parameters:parameters];
    [self requestWithURL:url requestType:SBSubsonicRequestGetLicense];
}


- (void)getIndexes {
    NSURL *url = [NSURL URLWithString:server.url command:@"rest/getIndexes.view" parameters:parameters];
    [self requestWithURL:url requestType:SBSubsonicRequestGetIndexes];
}

- (void)getIndexesSince:(NSDate *)date {
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:parameters];
    [params setValue:[NSString stringWithFormat:@"%00.f", [date timeIntervalSince1970]] forKey:@"ifModifiedSince"];
    
    NSURL *url = [NSURL URLWithString:server.url command:@"rest/getIndexes.view" parameters:params];
    [self requestWithURL:url requestType:SBSubsonicRequestGetIndexes];
}


- (void)getAlbumsForArtist:(SBArtist *)artist {
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:parameters];
    [params setValue:artist.id forKey:@"id"];
    
    NSURL *url = [NSURL URLWithString:server.url command:@"rest/getMusicDirectory.view" parameters:params];
    [self requestWithURL:url requestType:SBSubsonicRequestGetAlbumDirectory];
}


- (void)getAlbumsForArtistWithID:(SBArtistID *)artistID {
    
}


- (void)getCoverWithID:(NSString *)coverID {
    
    if(![NSThread isMainThread]) {
        [self performSelectorOnMainThread:@selector(getCoverWithID:) withObject:coverID waitUntilDone:YES];
        return;
    }

    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:parameters];
    [params setValue:coverID forKey:@"id"];
     [params setValue:[[NSUserDefaults standardUserDefaults] stringForKey:@"MaxCoverSize"] forKey:@"size"];
    
    NSURL *url = [NSURL URLWithString:server.url command:@"rest/getCoverArt.view" parameters:params];
    [self requestWithURL: url requestType: SBSubsonicRequestGetCoverArt coverID:coverID];
}


- (void)getTracksForAlbumID:(NSString *)albumID {
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:parameters];
    [params setValue:albumID forKey:@"id"];
    
    NSURL *url = [NSURL URLWithString:server.url command:@"rest/getMusicDirectory.view" parameters:params];
    [self requestWithURL:url requestType:SBSubsonicRequestGetTrackDirectory];
}


- (void)getPlaylists {
    NSURL *url = [NSURL URLWithString:server.url command:@"rest/getPlaylists.view" parameters:parameters];
    [self requestWithURL:url requestType:SBSubsonicRequestGetPlaylists];
}

- (void)getPlaylist:(SBPlaylist *)playlist {
    // XXX: Why is this function different from the others?
    [server getBaseParameters: parameters];
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:parameters];
    [params setValue:playlist.id forKey:@"id"];
    
    NSURL *url = [NSURL URLWithString:server.url command:@"rest/getPlaylist.view" parameters:params];
    [self requestWithURL:url requestType:SBSubsonicRequestGetPlaylist];
}


- (void)getPodcasts {
    NSURL *url = [NSURL URLWithString:server.url command:@"rest/getPodcasts.view" parameters:parameters];
    [self requestWithURL:url requestType:SBSubsonicRequestGetPodcasts];
}


- (void)deletePlaylistWithID:(NSString *)playlistID {
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:parameters];
    [params setValue:playlistID forKey:@"id"];
    
    NSURL *url = [NSURL URLWithString:server.url command:@"rest/deletePlaylist.view" parameters:params];
    [self requestWithURL:url requestType:SBSubsonicRequestDeletePlaylist];
    
}

- (void)createPlaylistWithName:(NSString *)playlistName tracks:(NSArray *)tracks {
    // required parameters
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:parameters];
    [params setValue:playlistName forKey:@"name"];
    
    // compute params string (because obviously, dictionary doesn't support set of multiple same key)
    NSMutableString *paramString = [NSMutableString string];
    for (NSString *trackID in tracks) {
        [paramString appendFormat:@"&songId=%@", trackID];
    }
    
    NSURL *url = [NSURL URLWithString:server.url command:@"rest/createPlaylist.view" parameters:params andParameterString:paramString];
    //NSLog(@"url : %@", url);
    [self requestWithURL:url requestType:SBSubsonicRequestCreatePlaylist];
}


- (void)updatePlaylistWithID:(NSString *)playlistID tracks:(NSArray *)tracks {
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:parameters];
    [params setValue:playlistID forKey:@"playlistId"];
    
    // compute params string (because obviously, dictionary doesn't support set of multiple same key)
    NSMutableString *paramString = [NSMutableString string];
    for (NSString *trackID in tracks) {
        [paramString appendFormat:@"&songId=%@", trackID];
    }
    
    NSURL *url = [NSURL URLWithString:server.url command:@"rest/createPlaylist.view" parameters:params andParameterString:paramString];
    [self requestWithURL:url requestType:SBSubsonicRequestCreatePlaylist];
}


- (void)getAlbumListForType:(SBSubsonicRequestType)type {
    
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:parameters];
    if(type == SBSubsonicRequestGetAlbumListRandom) {
        [params setValue:@"random" forKey:@"type"];
        
    } else if(type == SBSubsonicRequestGetAlbumListNewest) {
        [params setValue:@"newest" forKey:@"type"];
        
    } else if(type == SBSubsonicRequestGetAlbumListFrequent) {
        [params setValue:@"frequent" forKey:@"type"];
        
    } else if(type == SBSubsonicRequestGetAlbumListHighest) {
        [params setValue:@"highest" forKey:@"type"];
        
    } else if(type == SBSubsonicRequestGetAlbumListRecent) {
        [params setValue:@"recent" forKey:@"type"];
    }
    
    NSURL *url = [NSURL URLWithString:server.url command:@"rest/getAlbumList.view" parameters:params];
    [self requestWithURL:url requestType:type];
}

- (void)getNowPlaying {
    NSURL *url = [NSURL URLWithString:server.url command:@"rest/getNowPlaying.view" parameters:parameters];
    [self requestWithURL:url requestType:SBSubsonicRequestGetNowPlaying];   
}


- (void)getUserWithName:(NSString *)username {
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:parameters];
    [params setValue:username forKey:@"username"];
    
    NSURL *url = [NSURL URLWithString:server.url command:@"rest/getUser.view" parameters:params];
    [self requestWithURL:url requestType:SBSubsonicRequestGetUser];  
}


- (void)search:(NSString *)query {
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:parameters];
    [params setValue:query forKey:@"query"];
    [params setValue:@"100" forKey:@"songCount"];
    
    NSURL *url = [NSURL URLWithString:server.url command:@"rest/search2.view" parameters:params];
    SBSearchResult *searchResult = [[SBSearchResult alloc] initWithQuery:query];
    [self requestWithURL:url requestType: SBSubsonicRequestSearch searchResult:searchResult];
}


- (void)setRating:(NSInteger)rating forID:(NSString *)anID {
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:parameters];
    [params setValue:[NSString stringWithFormat:@"%ld", rating] forKey:@"rating"];
    [params setValue:anID forKey:@"id"];
    
    NSURL *url = [NSURL URLWithString:server.url command:@"rest/setRating.view " parameters:params];
    [self requestWithURL:url requestType:SBSubsonicRequestSetRating];  
}


- (void)scrobble:(NSString *)anID {
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:parameters];
    [params setValue:anID forKey:@"id"];
    unsigned long long currentTimeMS = (unsigned long long)([[NSDate date] timeIntervalSince1970] * 1000);
    [params setValue: [NSString stringWithFormat:@"%lld", currentTimeMS] forKey:@"time"];
    // XXX: Set submissions?
    
    NSURL *url = [NSURL URLWithString:server.url command:@"rest/scrobble.view" parameters:params];
    [self requestWithURL:url requestType:SBSubsonicRequestScrobble];
}



@end
